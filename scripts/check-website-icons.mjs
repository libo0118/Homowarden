import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { stripTypeScriptTypes } from 'node:module';

const root = new URL('../', import.meta.url);
const state = { enabled: undefined, serverType: 0, vault: 'https://vault.example.com', calls: 0, fail: false };
globalThis.__websiteIconCheck = {
  DataPreferences: { getInstance: () => ({
    getSync: key => key === 'website_icons' ? state.enabled : state.serverType,
    putSync: (_, value) => { state.enabled = value; }
  }) },
  AppStorage: { setOrCreate: (_, value) => { state.linkedEnabled = value; } },
  getServerEndpoints: async () => {
    state.calls++;
    if (state.fail) throw new Error('Unavailable');
    return { vaultBaseUrl: state.vault };
  }
};
async function loadEts(path, prefix) {
  const source = (await readFile(new URL(path, root), 'utf8')).replace(/^import .+;\r?\n/gm, '');
  const code = prefix + stripTypeScriptTypes(source, { mode: 'strip' });
  return import(`data:text/javascript;base64,${Buffer.from(code).toString('base64')}`);
}
const {PUBLIC_TLDS} = await loadEts('entry/src/main/ets/utils/PublicTlds.ets', '');
assert.equal(PUBLIC_TLDS.size, 1437, 'The pinned IANA snapshot must remain complete');
globalThis.__websiteIconCheck.publicTlds = PUBLIC_TLDS;
const icons = await loadEts('entry/src/main/ets/utils/WebsiteIconUtil.ets', `
  const {DataPreferences, AppStorage, getServerEndpoints} = globalThis.__websiteIconCheck;
  const PUBLIC_TLDS = globalThis.__websiteIconCheck.publicTlds;
  const ServerType = {US: 0, EU: 1, SELF_HOSTED: 2};
  const WEBSITE_ICONS = 'website_icons', SERVER_TYPE_KEY = 'server_type';
`);
for (const [uri, host] of [
  ['https://github.com/user?token=private#secret', 'github.com'],
  ['http://GITHUB.com./login', 'github.com'],
  ['https://user:password@github.com:443/private', 'github.com'],
  ['https://accounts.google.com', 'accounts.google.com'],
  ['https://example.co.uk', 'example.co.uk'],
  ['https://example.app', 'example.app'],
  ['https://example.dev', 'example.dev'],
  ['https://example.cloud', 'example.cloud'],
  ['https://example.tech', 'example.tech'],
  ['https://example.zip', 'example.zip'],
  ['https://xn--bcher-kva.de', 'xn--bcher-kva.de'],
  ['https://example.xn--fiqs8s', 'example.xn--fiqs8s'],
  ['https://example.xn--p1ai', 'example.xn--p1ai']
]) assert.equal(icons.getPublicWebsiteHostname(uri), host);
for (const uri of [
  'github.com', 'androidapp://com.github.android', 'iosapp://github', 'ftp://github.com',
  'https://localhost', 'https://login.localhost', 'https://router.lan', 'https://vault.internal',
  'https://host.local', 'https://host.corp', 'https://host.private', 'https://host.home.arpa',
  'https://host.test', 'https://host.invalid', 'https://host.onion', 'https://10.0.0.1',
  'https://printer.thisisnotatld', 'https://vault.customtld', 'https://host.zz',
  'https://host.xn--thisisnotatld', 'https://host.localdomain', 'https://host.intranet',
  'https://host.home', 'https://host.example', 'https://host.arpa',
  'http://192.168.1.1', 'https://172.16.1.1', 'https://169.254.1.1', 'https://127.0.0.1',
  'https://8.8.8.8', 'https://[::1]', 'https://[2001:4860:4860::8888]',
  'https://2130706433', 'https://0177.0.0.1', 'https://0x7f000001', 'https://0x7f.0.0.1',
  'https://github.com@192.168.1.1', 'https://github.com\\@localhost',
  'https://github.com:65536', 'https://github.com:0', 'https://github.com:bad',
  'https://github.com%2flocal', 'https://bad_name.com', 'https://-bad.com', 'https://github..com',
  'https://github.com\n', 'https://书籍.cn'
]) assert.equal(icons.getPublicWebsiteHostname(uri), '', uri);
assert.equal(icons.buildWebsiteIconUrl('https://icons.bitwarden.net', 'github.com'),
  'https://icons.bitwarden.net/github.com/icon.png');
assert.equal(icons.buildWebsiteIconUrl('https://icons.bitwarden.net', '192.168.1.1'), '');
assert.equal(icons.buildWebsiteIconUrl('https://icons.bitwarden.net', 'printer.thisisnotatld'), '');
assert.equal(icons.buildWebsiteIconUrl('https://icons.bitwarden.net', 'vault.internal'), '');
assert.equal(icons.WebsiteIconUtil.isEnabled(), true);
icons.WebsiteIconUtil.setEnabled(false);
assert.equal(icons.WebsiteIconUtil.isEnabled(), false);
assert.equal(state.linkedEnabled, false);
assert.equal(await icons.WebsiteIconUtil.getIconBaseUrl(), 'https://icons.bitwarden.net');
state.serverType = 1;
assert.equal(await icons.WebsiteIconUtil.getIconBaseUrl(), 'https://icons.bitwarden.eu');
assert.equal(state.calls, 0, 'Public regions must not resolve the self-hosted endpoint');
state.serverType = 2;
state.vault = 'https://vault.example.com/subpath/';
assert.equal(await icons.WebsiteIconUtil.getIconBaseUrl(), 'https://vault.example.com/subpath/icons');
state.vault = 'http://192.168.1.2:8080';
assert.equal(await icons.WebsiteIconUtil.getIconBaseUrl(), 'http://192.168.1.2:8080/icons');
state.fail = true;
assert.equal(await icons.WebsiteIconUtil.getIconBaseUrl(), '');
state.fail = false;
state.vault = 'https://user:password@vault.example.com';
assert.equal(await icons.WebsiteIconUtil.getIconBaseUrl(), '');
state.serverType = 99;
assert.equal(await icons.WebsiteIconUtil.getIconBaseUrl(), '', 'An unknown server must not use a public fallback');

const rows = [
  {cipher_id: 'good', username: 'user', totp: 'totp', uris: JSON.stringify([{uri: 'bad'}, {uri: 'good'}])},
  {cipher_id: 'broken-json', username: 'user', totp: 'totp', uris: '{'},
  {cipher_id: 'wrong-shape', username: 'user', totp: 'totp', uris: '{"uri":"good"}'},
  {cipher_id: 'private', username: 'user', totp: 'totp', uris: JSON.stringify([{uri: 'private'}])},
  {cipher_id: 'custom-tld', username: 'user', totp: 'totp', uris: JSON.stringify([{uri: 'custom-tld'}])}
];
globalThis.__websiteIconCheck.rows = rows;
globalThis.__websiteIconCheck.hostname = icons.getPublicWebsiteHostname;
const {TotpListViewModel} = await loadEts('entry/src/main/ets/viewmodel/TotpListViewModel.ets', `
  const getPublicWebsiteHostname = globalThis.__websiteIconCheck.hostname;
  const Logger = {error: () => {}};
  const CipherItemType = {LOGIN: 1}, DBTableName = {LOGINS: 'cipher_logins'};
  const DatabaseUtil = {getInstance: () => ({queryAllRowsSync: () => globalThis.__websiteIconCheck.rows})};
  const CryptoUtil = {decryptCipherKey: async () => 'key', decryptField: async value => {
    if (value === 'bad') throw new Error('Corrupt encrypted URI');
    if (value === 'good') return 'https://github.com/account?token=secret';
    if (value === 'private') return 'https://vault.internal';
    if (value === 'custom-tld') return 'https://printer.thisisnotatld';
    return value;
  }};
`);
const model = new TotpListViewModel();
model.allCiphers = rows.map(row => ({id: row.cipher_id, type: 1, key: null, login: null}));
await model.loadLogins();
assert.equal(model.filteredCiphers.length, 5, 'An invalid URI must not remove its verification code');
assert.deepEqual([...model.websiteIconHosts], [['good', 'github.com']]);
console.log('Website icon checks passed: delegated-TLD privacy, regional endpoints, preference, and malformed-URI fallback.');
