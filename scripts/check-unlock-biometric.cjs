// Runs the pure session and credential guards from ArkTS without a device SDK.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const repo = path.resolve(__dirname, '..');
function body(file, name) {
  const source = fs.readFileSync(path.join(repo, file), 'utf8');
  const match = source.match(new RegExp('^  (?:(?:private|static|async) )*' + name + '\\(', 'm'));
  assert.ok(match, name + ' exists');
  const open = source.indexOf('{', match.index);
  return block(source, open);
}
function block(source, open) {
  let depth = 1;
  let end = open + 1;
  while (depth && end < source.length) {
    if (source[end] === '{') depth++;
    if (source[end] === '}') depth--;
    end++;
  }
  return source.slice(open + 1, end - 1);
}
const vaultFile = 'entry/src/main/ets/viewmodel/VaultViewModel.ets';
const Session = Function('AutoLockUtil', `return class VaultViewModel {
  static sessionActive = false;
  static autoBiometricPromptAttempted = false;
  static syncGeneration = 0;
  static syncBlocked = false;
  static consumeAutoBiometricPrompt() { ${body(vaultFile, 'consumeAutoBiometricPrompt')} }
  static beginSession() { ${body(vaultFile, 'beginSession')} }
  static lockSession() { ${body(vaultFile, 'lockSession')} }
};`)({ recordActivity() {} });
assert.equal(Session.consumeAutoBiometricPrompt(), true, 'cold locked start prompts once');
assert.equal(Session.consumeAutoBiometricPrompt(), false, 'cancel or failure does not prompt again');
Session.lockSession();
assert.equal(Session.consumeAutoBiometricPrompt(), false, 'foreground/page recreation retain consumption');
Session.beginSession();
assert.equal(Session.consumeAutoBiometricPrompt(), false, 'unlocked session cannot prompt');
Session.lockSession();
assert.equal(Session.consumeAutoBiometricPrompt(), true, 'later lock can prompt again');
assert.equal(Session.consumeAutoBiometricPrompt(), false, 'later lock also prompts only once');
const keys = ['EMAIL_KEY', 'MASTER_KEY', 'USER_KEY', 'KDF_PARAM_KEY'];
let credentials = { EMAIL_KEY: 'person@example.com', MASTER_KEY: 'saved-master-key', USER_KEY: 'saved-user-key', KDF_PARAM_KEY: '{"kdf":0}' };
let loginStatus = 1;
const hasCredentials = Function('DataPreferences', 'queryAssetSync', 'LOGIN_STATUS_KEY', ...keys,
  body('entry/src/main/ets/pages/UnlockPage.ets', 'hasUnlockCredentials')
    .replace('getSync<number>', 'getSync').replace('parameters: PreloginResponse', 'parameters'));
const check = () => hasCredentials({ getInstance: () => ({ getSync: () => loginStatus }) },
  key => credentials[key] || '', 'LOGIN_STATUS_KEY', ...keys);
assert.equal(check(), true, 'saved supported credentials allow prompt');
for (const key of keys) {
  const saved = credentials[key];
  delete credentials[key];
  assert.equal(check(), false, 'missing ' + key + ' blocks prompt');
  credentials[key] = saved;
}
for (const invalid of ['malformed', '{"kdf":99}', 'null']) {
  credentials.KDF_PARAM_KEY = invalid;
  assert.equal(check(), false, 'invalid KDF blocks prompt');
}
credentials.KDF_PARAM_KEY = '{"kdf":1}';
assert.equal(check(), true, 'Argon2 credentials allow prompt');
loginStatus = 0;
assert.equal(check(), false, 'logged out state blocks prompt');

const unlockFile = 'entry/src/main/ets/pages/UnlockPage.ets';
const unlockSource = fs.readFileSync(path.join(repo, unlockFile), 'utf8');
const hidden = unlockSource.indexOf('.onHidden(() => {');
assert.ok(hidden >= 0, 'hidden lifecycle exists');
const hiddenBody = block(unlockSource, unlockSource.indexOf('{', hidden));
const passwordBody = body(unlockFile, 'startPasswordAuth')
  .replace('kdfParamStr: string', 'kdfParamStr')
  .replace('kdfParams: PreloginResponse', 'kdfParams')
  .replace('derivedMasterKey: string', 'derivedMasterKey');
const PasswordUnlock = Function('CryptoUtil', 'AppToast', 'queryAssetSync', 'VaultViewModel', 'Logger', '$r',
  'KDF_PARAM_KEY', 'MASTER_KEY', 'EMAIL_KEY', 'EntryRouter', 'GeneratorDatabaseUtil', 'GENERATOR_HISTORY_TABLE',
  'DatabaseUtil', 'clearAssetAndPreferences', 'WindowPrivacyUtil', `return class Unlock {
    async handlePasswordAuth() { ${body(unlockFile, 'handlePasswordAuth')} }
    async startPasswordAuth(generation) { ${passwordBody} }
    invalidatePasswordAuth() { ${body(unlockFile, 'invalidatePasswordAuth')} }
    isPasswordAuthCurrent(generation) { ${body(unlockFile, 'isPasswordAuthCurrent')} }
    aboutToDisappear() { ${body(unlockFile, 'aboutToDisappear')} }
    onHidden() { ${hiddenBody} }
    async logout() { ${body(unlockFile, 'logout').replace('cleanupErrors: string[]', 'cleanupErrors')} }
    finishUnlock() { ${body(unlockFile, 'finishUnlock').replace('info: NavPathInfo[]', 'info')} }
    waitForUnlockButtonUpdate() { return Promise.resolve(); }
    getUIContext() { return {}; }
    cancelBiometricAuth() {}
  };`);
function deferred() {
  let resolve, reject;
  const promise = new Promise((ok, fail) => { resolve = ok; reject = fail; });
  return { promise, resolve, reject };
}
function passwordFixture(kdf) {
  const pending = [];
  const events = [];
  const derive = () => {
    const request = deferred();
    pending.push(request);
    return request.promise;
  };
  const assets = { KDF_PARAM_KEY: JSON.stringify({ kdf }), MASTER_KEY: 'saved-key', EMAIL_KEY: 'person@example.com' };
  const Unlock = PasswordUnlock({ deriveKeyPBKDF2: derive, deriveKeyArgon2id: derive },
    { show: (_ui, message) => events.push(message) }, key => assets[key],
    { beginSession: () => events.push('session'), prepareForLogout: async () => {} }, { error() {} }, key => key,
    'KDF_PARAM_KEY', 'MASTER_KEY', 'EMAIL_KEY', { UnlockPage: 'UnlockPage', VaultPage: 'VaultPage', LoginPage: 'LoginPage' },
    { getInstance: () => ({ deleteAllData: async () => {} }) }, 'history',
    { getInstance: () => ({ clearVaultData: async () => {} }) }, () => {}, { applyForCurrentState: async () => {} });
  const unlock = new Unlock();
  Object.assign(unlock, {
    isPageActive: true, isPasswordAuthenticating: false, isBiometricAuthenticating: false,
    passwordAuthGeneration: 0, masterPassword: 'secret',
    pathInfos: { getPathStack: () => [], replacePath: info => events.push(info.name), pop: () => events.push('pop') }
  });
  return { unlock, pending, events };
}
function settle(request, outcome) {
  if (outcome === 'error') request.reject(new Error('KDF failed'));
  else request.resolve(outcome === 'success' ? 'saved-key' : 'wrong-key');
}
async function checkPasswordGenerations() {
  for (const kdf of [0, 1]) {
    for (const outcome of ['success', 'wrong', 'error']) {
      const current = passwordFixture(kdf);
      const task = current.unlock.handlePasswordAuth();
      await Promise.resolve();
      assert.equal(current.pending.length, 1, 'current attempt reaches KDF');
      settle(current.pending[0], outcome);
      await task;
      assert.deepEqual(current.events, outcome === 'success' ? ['session', 'VaultPage'] :
        [outcome === 'wrong' ? 'app.string.unlock_wrong_password' : 'app.string.unlock_verification_failed'],
      'current KDF retains existing success/error behavior');
      assert.equal(current.unlock.isPasswordAuthenticating, false);
    }
    for (const lifecycle of ['onHidden', 'aboutToDisappear', 'logout']) {
      for (const outcome of ['success', 'wrong', 'error']) {
        const stale = passwordFixture(kdf);
        const task = stale.unlock.handlePasswordAuth();
        await Promise.resolve();
        await stale.unlock[lifecycle]();
        stale.unlock.isPageActive = true;
        settle(stale.pending[0], outcome);
        await task;
        assert.deepEqual(stale.events, lifecycle === 'logout' ? ['LoginPage'] : [],
          lifecycle + ' then redisplay discards old KDF ' + outcome);
      }
    }
    for (const outcome of ['success', 'wrong', 'error']) {
      const replaced = passwordFixture(kdf);
      const oldTask = replaced.unlock.handlePasswordAuth();
      await Promise.resolve();
      replaced.unlock.onHidden();
      replaced.unlock.isPageActive = true;
      replaced.unlock.masterPassword = 'new secret';
      const newTask = replaced.unlock.handlePasswordAuth();
      await Promise.resolve();
      settle(replaced.pending[0], outcome);
      await oldTask;
      assert.equal(replaced.unlock.isPasswordAuthenticating, true, 'old finally does not reset new attempt');
      assert.deepEqual(replaced.events, [], 'old attempt does not unlock, toast or navigate');
      settle(replaced.pending[1], 'success');
      await newTask;
      assert.deepEqual(replaced.events, ['session', 'VaultPage'], 'new attempt completes normally');
    }
  }
  const beforeKdf = passwordFixture(0);
  const buttonUpdate = deferred();
  beforeKdf.unlock.waitForUnlockButtonUpdate = () => buttonUpdate.promise;
  const task = beforeKdf.unlock.handlePasswordAuth();
  beforeKdf.unlock.onHidden();
  beforeKdf.unlock.isPageActive = true;
  buttonUpdate.resolve();
  await task;
  assert.equal(beforeKdf.pending.length, 0, 'invalidated button update does not start KDF');
  assert.deepEqual(beforeKdf.events, []);
  console.log('PASS: automatic biometric guards and password KDF generation lifecycle');
}
checkPasswordGenerations().catch(error => { console.error(error); process.exitCode = 1; });
