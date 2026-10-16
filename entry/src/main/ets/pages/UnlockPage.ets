import { EntryRouter } from '../../../../EntryRouter';
import { userAuth } from '@kit.UserAuthenticationKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import { AppToast } from '../utils/AppToast';
import { DataPreferences } from '@abner/datastore';
import {
  BIOMETRIC_AUTH,
  EMAIL_KEY,
  KDF_PARAM_KEY,
  LOGIN_STATUS_KEY,
  MASTER_KEY,
  SERVER_ADDRESS_KEY,
  SERVER_BASE_URL_EU,
  SERVER_BASE_URL_US,
  SERVER_TYPE_KEY,
  ServerType,
  USER_KEY
} from '../utils/Constants';
import { Logger } from '@nzy/logger';
import { clearAssetAndPreferences, queryAssetSync } from '../utils/AssetUtil';
import { PreloginResponse } from '../model/Prelogin';
import { CryptoUtil } from '../utils/CryptoUtil';
import { HdsNavDestination } from '@hms.hds.hdsBaseComponent';
import { WindowPrivacyUtil } from '../utils/WindowPrivacyUtil';
import { AdaptiveTextButton } from '../component/AdaptiveButton';
import { DatabaseUtil } from '../utils/DatabaseUtil';
import { GENERATOR_HISTORY_TABLE, GeneratorDatabaseUtil } from '../utils/GeneratorDatabaseUtil';
import { VaultViewModel } from '../viewmodel/VaultViewModel';
import { FormFactorUtil } from '../utils/FormFactorUtil';

@Builder
export function UnlockPageBuilder() {
  UnlockPage();
}

@Component
export struct UnlockPage {
  pathInfos: NavPathStack = new NavPathStack();
  private exitTime: number = 0;
  @State private masterPassword: string = "";
  @State private passwordVisible: boolean = false;
  @State private passwordFocused: boolean = false;
  @State private biometricEnabled: boolean = false;
  @State private isPasswordAuthenticating: boolean = false;
  @State private isBiometricAuthenticating: boolean = false;
  @State private accountEmail: string = '';
  @State private serverAddress: string = '';
  private biometricAuthInstance: userAuth.UserAuthInstance | undefined = undefined;
  private isPageActive: boolean = false;
  private passwordAuthGeneration: number = 0;
  private isPc: boolean = FormFactorUtil.isPc();

  aboutToAppear() {
    this.biometricEnabled = DataPreferences.getInstance().getSync<number>(BIOMETRIC_AUTH) == 1;
    this.accountEmail = queryAssetSync(EMAIL_KEY);
    const serverType = DataPreferences.getInstance().getSync<ServerType>(SERVER_TYPE_KEY);
    const storedAddress = DataPreferences.getInstance().getSync<string>(SERVER_ADDRESS_KEY) || '';
    this.serverAddress = serverType === ServerType.SELF_HOSTED ?
      storedAddress.replace(/^https?:\/\//i, '').replace(/\/+$/g, '') :
      (serverType === ServerType.EU ? SERVER_BASE_URL_EU : SERVER_BASE_URL_US);
  }

  aboutToDisappear() {
    this.isPageActive = false;
    this.invalidatePasswordAuth();
    this.cancelBiometricAuth();
    this.masterPassword = '';
  }

  @Builder
  private mobileContent() {
    Column() {
      Row() {
        Text($r('app.string.unlock_verify_title'))
          .fontSize(19)
          .lineHeight(24)
          .fontWeight(600)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        Button() {
          Text(this.accountEmail.slice(0, 2).toUpperCase() || 'H')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.button_foreground_color'))
            .width(28)
            .height(28)
            .textAlign(TextAlign.Center)
            .backgroundColor($r('app.color.button_background_color'))
            .borderRadius(14)
        }
        .type(ButtonType.Normal)
        .width(48)
        .height(48)
        .padding(0)
        .backgroundColor(Color.Transparent)
        .accessibilityText($r('app.string.settings_account'))
        .onClick(() => {
          this.getUIContext().showAlertDialog({
            title: $r('app.string.settings_account'),
            message: $r('app.string.unlock_account_context', this.accountEmail, this.serverAddress),
            confirm: { value: $r('app.string.common_confirm'), action: () => {} }
          });
        })
        Button() {
          Image($r('app.media.icon_more'))
            .width(24)
            .height(24)
            .fillColor($r('app.color.settings_icon_color'))
        }
        .type(ButtonType.Normal)
        .width(48)
        .height(48)
        .padding(12)
        .backgroundColor(Color.Transparent)
        .accessibilityText($r('app.string.vault_item_menu'))
        .enabled(!this.isPasswordAuthenticating && !this.isBiometricAuthenticating)
        .bindMenu([{ value: $r('app.string.unlock_logout'), action: () => { this.confirmLogout(); } }], {
          backgroundColor: $r('app.color.menu_background_color'),
          backgroundBlurStyle: BlurStyle.NONE
        })
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 4 })
      .backgroundColor($r('app.color.start_window_background'))

      Scroll() {
        Column() {
          Column() {
            Row() {
              Column() {
                if (this.passwordFocused || this.masterPassword.length > 0) {
                  Text($r('app.string.login_master_password'))
                    .fontSize(12)
                    .lineHeight(16)
                    .fontColor($r('app.color.vault_secondary_text'))
                    .width('100%')
                }
              TextInput({
                placeholder: this.passwordFocused || this.masterPassword.length > 0 ? '' :
                  $r('app.string.login_master_password'),
                text: this.masterPassword
              })
                .accessibilityText($r('app.string.unlock_enter_master_password'))
                .type(this.passwordVisible ? InputType.Normal : InputType.Password)
                .showPasswordIcon(false)
                .enterKeyType(EnterKeyType.Go)
                .fontSize(14)
                .placeholderFont({ size: 15 })
                .fontColor($r('sys.color.font_primary'))
                .placeholderColor($r('app.color.vault_secondary_text'))
                .height(this.passwordFocused || this.masterPassword.length > 0 ? 32 : 56)
                .padding(0)
                .borderRadius(0)
                .backgroundColor(Color.Transparent)
                .enabled(!this.isPasswordAuthenticating && !this.isBiometricAuthenticating)
                .onFocus(() => {
                  this.passwordFocused = true;
                })
                .onBlur(() => {
                  this.passwordFocused = false;
                })
                .onChange((value: string) => {
                  this.masterPassword = value;
                })
                .onSubmit(() => {
                  void this.handlePasswordAuth();
                })
              }
              .layoutWeight(1)
              Button() {
                Image(this.passwordVisible ? $r('app.media.icon_hide') : $r('app.media.icon_show'))
                  .width(24)
                  .height(24)
                  .fillColor($r('app.color.settings_icon_color'))
              }
              .type(ButtonType.Normal)
              .width(48)
              .height(48)
              .padding(12)
              .backgroundColor(Color.Transparent)
              .accessibilityText(this.passwordVisible ? $r('app.string.accessibility_hide') :
                $r('app.string.accessibility_show'))
              .onClick(() => {
                this.passwordVisible = !this.passwordVisible;
              })
            }
            .width('100%')
            .height(68)

            Divider().color($r('app.color.vault_divider_color'))

            Text($r('app.string.unlock_vault_locked_description'))
              .fontSize(13)
              .lineHeight(18)
              .fontColor($r('app.color.vault_secondary_text'))
              .width('100%')
              .margin({ top: 12 })
            Text($r('app.string.unlock_account_context', this.accountEmail, this.serverAddress))
              .fontSize(13)
              .lineHeight(18)
              .fontColor($r('app.color.vault_secondary_text'))
              .width('100%')
              .margin({ top: 16, bottom: 12 })
          }
          .width('100%')
          .padding({ left: 16, right: 16 })
          .backgroundColor($r('app.color.vault_list_background'))
          .borderRadius(8)

          if (this.biometricEnabled) {
            Button($r('app.string.unlock_use_biometrics'))
              .type(ButtonType.Normal)
              .width('100%')
              .height(48)
              .borderRadius(24)
              .border({ width: 1, color: $r('app.color.brand_accent_color') })
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.brand_accent_color'))
              .backgroundColor(Color.Transparent)
              .margin({ top: 24 })
              .enabled(!this.isPasswordAuthenticating && !this.isBiometricAuthenticating)
              .onClick(() => {
                this.startBiometricAuth();
              })
          }

          Button(this.isPasswordAuthenticating ? $r('app.string.unlock_in_progress') :
            $r('app.string.unlock_action'))
            .type(ButtonType.Normal)
            .width('100%')
            .height(48)
            .borderRadius(24)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.masterPassword.length > 0 ? $r('app.color.button_foreground_color') :
              $r('app.color.vault_secondary_text'))
            .backgroundColor(this.masterPassword.length > 0 ? $r('app.color.button_background_color') :
              $r('app.color.vault_divider_color'))
            .margin({ top: this.biometricEnabled ? 12 : 24 })
            .enabled(this.masterPassword.length > 0 && !this.isPasswordAuthenticating &&
              !this.isBiometricAuthenticating)
            .onClick(() => {
              void this.handlePasswordAuth();
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 24 })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.start_window_background'))
  }

  build() {
    HdsNavDestination() {
      if (!this.isPc) {
        this.mobileContent()
      } else {
      Column() {
        // 应用图标
        Image($r('app.media.app_small_icon'))
          .width(120)
          .height(120)
          .margin({ bottom: 24 })

        Column() {
          Text($r('app.string.unlock_locked_prompt'))
            .fontSize(14)
            .fontColor('#666666')
            .margin({
              left: 16,
              right: 16,
              top: 12,
              bottom: 12
            })

          TextInput({ text: this.masterPassword })
            .accessibilityText($r('app.string.unlock_enter_master_password'))
            .onChange((v: string) => {
              this.masterPassword = v;
            })
            .onSubmit(async () => {
              await this.handlePasswordAuth();
            })
            .margin({ left: 16, right: 16, bottom: 24 })
            .type(InputType.Password)
        }
        .width(this.isPc ? '60%' : '100%')
        .constraintSize({ maxWidth: 640 })
        .alignItems(HorizontalAlign.Center)

        // 按钮
        Column({ space: 6 }) {
          // 密码解锁
          AdaptiveTextButton({
            text: this.isPasswordAuthenticating ? $r('app.string.unlock_in_progress') :
              $r('app.string.unlock_master_password'),
            barWidth: 240,
            barHeight: 50,
            fontSize: 18,
            contentPadding: 6,
            translucent: true,
            buttonEnabled: !this.isPasswordAuthenticating,
            onButtonClick: () => {
              void this.handlePasswordAuth();
            }
          })

          if (this.biometricEnabled) {
            // 生物识别解锁
            AdaptiveTextButton({
              text: $r('app.string.unlock_biometrics'),
              barWidth: 240,
              barHeight: 50,
              fontSize: 18,
              contentPadding: 6,
              translucent: true,
              onButtonClick: () => {
                this.startBiometricAuth();
              }
            })
          }

          // 注销
          AdaptiveTextButton({
            text: $r('app.string.unlock_logout'),
            barWidth: 240,
            barHeight: 50,
            fontSize: 18,
            contentPadding: 6,
            translucent: true,
            translucentFontColor: $r('sys.color.warning'),
            onButtonClick: () => {
              void this.logout();
            }
          })
        }

      }
      .width('100%')
      .height('100%')
      .padding({ top: 24, bottom: 24 })
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      }
    }
    .titleBar({
      content: { title: { mainTitle: $r('app.string.unlock_verify_title') } },
      enableComponentSafeArea: true
    })
    .hideTitleBar(true)
    .onReady((ctx: NavDestinationContext) => {
      this.pathInfos = ctx.pathStack;
    })
    .onShown(() => {
      this.isPageActive = true;
      if (!this.isPc && this.biometricEnabled && this.hasUnlockCredentials() &&
        VaultViewModel.consumeAutoBiometricPrompt()) {
        this.startBiometricAuth();
      }
    })
    .onHidden(() => {
      this.isPageActive = false;
      this.invalidatePasswordAuth();
      this.cancelBiometricAuth();
    })
    .hideBackButton(true).onBackPressed(() => {
      const currentTime = new Date().getTime();
      if (currentTime - this.exitTime < 2000) {
        (this.getUIContext().getHostContext() as common.UIAbilityContext)?.terminateSelf();
      } else {
        this.exitTime = currentTime;
        this.getUIContext().getPromptAction().showToast({
          message: $r('app.string.common_back_exit')
        });
      }
      return true;
    })
  }

  private confirmLogout(): void {
    this.getUIContext().showAlertDialog({
      title: $r('app.string.common_confirm'),
      message: $r('app.string.settings_logout_confirm'),
      primaryButton: { value: $r('app.string.common_cancel'), action: () => {} },
      secondaryButton: { value: $r('app.string.unlock_logout'), action: () => { void this.logout(); } }
    });
  }

  private async logout(): Promise<void> {
    this.isPageActive = false;
    this.invalidatePasswordAuth();
    this.cancelBiometricAuth();
    const cleanupErrors: string[] = [];
    try {
      await VaultViewModel.prepareForLogout();
    } catch (error) {
      cleanupErrors.push(`${error}`);
      Logger.error(`Failed to prepare vault for logout: ${error}`);
    }
    try {
      await GeneratorDatabaseUtil.getInstance().deleteAllData(GENERATOR_HISTORY_TABLE);
    } catch (error) {
      cleanupErrors.push(`${error}`);
      Logger.error(`Failed to clear generator history during logout: ${error}`);
    }
    try {
      await DatabaseUtil.getInstance().clearVaultData();
    } catch (error) {
      cleanupErrors.push(`${error}`);
      Logger.error(`Failed to clear vault database during logout: ${error}`);
    }
    try {
      clearAssetAndPreferences();
    } catch (error) {
      cleanupErrors.push(`${error}`);
      Logger.error(`Failed to clear credentials during logout: ${error}`);
    }
    try {
      await WindowPrivacyUtil.applyForCurrentState();
    } catch (error) {
      cleanupErrors.push(`${error}`);
      Logger.error(`Failed to update window privacy during logout: ${error}`);
    }
    this.pathInfos.replacePath({ name: EntryRouter.LoginPage });
    if (cleanupErrors.length > 0) {
      Logger.error(`Logout completed with cleanup errors: ${cleanupErrors.join('; ')}`);
      AppToast.show(this.getUIContext(), $r('app.string.error_storage'));
    }
  }

  /**
   * 使用保存的 KDF 参数重新派生主密钥，验证通过后按原页面栈恢复导航
   */
  private async handlePasswordAuth(): Promise<void> {
    if (!this.isPageActive || this.isPasswordAuthenticating || this.isBiometricAuthenticating) {
      return;
    }
    const generation = ++this.passwordAuthGeneration;
    this.isPasswordAuthenticating = true;
    try {
      // 先让 ArkUI 提交“解锁中”文案与禁用态，再开始可能耗时的本地 KDF
      await this.waitForUnlockButtonUpdate();
      if (!this.isPasswordAuthCurrent(generation)) {
        return;
      }
      await this.startPasswordAuth(generation);
    } finally {
      if (generation === this.passwordAuthGeneration) {
        this.isPasswordAuthenticating = false;
      }
    }
  }

  private invalidatePasswordAuth(): void {
    this.passwordAuthGeneration++;
    this.isPasswordAuthenticating = false;
  }

  private isPasswordAuthCurrent(generation: number): boolean {
    return this.isPageActive && generation === this.passwordAuthGeneration;
  }

  private waitForUnlockButtonUpdate(): Promise<void> {
    return new Promise<void>((resolve: () => void) => {
      setTimeout(resolve, 0);
    });
  }

  private async startPasswordAuth(generation: number): Promise<void> {
    if (!this.masterPassword || this.masterPassword.length === 0) {
      AppToast.show(this.getUIContext(), $r('app.string.unlock_enter_master_password'));
      return;
    }

    try {
      // 获取存储的 KDF 参数
      const kdfParamStr: string = queryAssetSync(KDF_PARAM_KEY);

      if (!kdfParamStr) {
        AppToast.show(this.getUIContext(), $r('app.string.unlock_parameters_failed'));
        this.pathInfos.replacePath({ name: "LoginPage" });
        return;
      }

      const kdfParams: PreloginResponse = JSON.parse(kdfParamStr);
      const storedMasterKey = queryAssetSync(MASTER_KEY);
      const email = queryAssetSync(EMAIL_KEY);
      if (!storedMasterKey) {
        AppToast.show(this.getUIContext(), $r('app.string.unlock_parameters_failed'));
        this.pathInfos.replacePath({ name: "LoginPage" });
        return;
      }

      // 使用输入的密码重新派生主密钥
      let derivedMasterKey: string = '';
      const salt = email.trim().toLowerCase() || '';

      if (kdfParams.kdf === 0) {
        // PBKDF2
        derivedMasterKey = await CryptoUtil.deriveKeyPBKDF2(
          this.masterPassword,
          salt,
          kdfParams.kdfIterations || 100000,
          32
        );
      } else if (kdfParams.kdf === 1) {
        // Argon2id
        derivedMasterKey = await CryptoUtil.deriveKeyArgon2id(
          this.masterPassword,
          salt,
          kdfParams.kdfIterations || 2,
          kdfParams.kdfMemory || 16,
          kdfParams.kdfParallelism || 1,
          32
        );
      } else {
        AppToast.show(this.getUIContext(), $r('app.string.unlock_parameters_failed'));
        this.pathInfos.replacePath({ name: "LoginPage" });
        return;
      }

      if (!this.isPasswordAuthCurrent(generation)) {
        return;
      }

      // 验证派生的主密钥是否与存储的匹配
      if (derivedMasterKey === storedMasterKey) {
        // 解锁只更新时间戳和导航状态，不把输入的主密码持久化
        this.finishUnlock();
      } else {
        AppToast.show(this.getUIContext(), $r('app.string.unlock_wrong_password'));
        return;
      }
    } catch (error) {
      if (!this.isPasswordAuthCurrent(generation)) {
        return;
      }
      Logger.error(`Master password verification failed: ${error}`);
      AppToast.show(this.getUIContext(), $r('app.string.unlock_verification_failed'));
      return;
    }
  }

  private hasUnlockCredentials(): boolean {
    if (DataPreferences.getInstance().getSync<number>(LOGIN_STATUS_KEY) !== 1 ||
      !queryAssetSync(EMAIL_KEY) || !queryAssetSync(MASTER_KEY) || !queryAssetSync(USER_KEY)) {
      return false;
    }
    try {
      const parameters: PreloginResponse = JSON.parse(queryAssetSync(KDF_PARAM_KEY));
      return parameters.kdf === 0 || parameters.kdf === 1;
    } catch (_error) {
      return false;
    }
  }

  private finishUnlock(): void {
    if (!this.isPageActive) {
      return;
    }
    const info: NavPathInfo[] = this.pathInfos.getPathStack();
    this.masterPassword = '';
    VaultViewModel.beginSession();
    if (info.length === 0 || info[0].name === EntryRouter.UnlockPage) {
      this.pathInfos.replacePath({ name: EntryRouter.VaultPage });
    } else {
      this.pathInfos.pop();
    }
  }

  private cancelBiometricAuth(): void {
    const activeAuth = this.biometricAuthInstance;
    this.biometricAuthInstance = undefined;
    this.isBiometricAuthenticating = false;
    if (activeAuth) {
      try {
        activeAuth.off('result');
        activeAuth.cancel();
      } catch (error) {
        Logger.error(`Failed to cancel biometric auth: ${error}`);
      }
    }
  }

  /**
   * 使用一次性随机挑战发起系统级认证，成功后恢复被锁定前的页面栈
   */
  startBiometricAuth() {
    if (!this.isPageActive || this.isBiometricAuthenticating || this.isPasswordAuthenticating ||
      !this.biometricEnabled) {
      return;
    }
    if (!this.hasUnlockCredentials()) {
      AppToast.show(this.getUIContext(), $r('app.string.unlock_parameters_failed'));
      return;
    }
    this.isBiometricAuthenticating = true;
    try {
      const rand = cryptoFramework.createRandom();
      const len: number = 16; // 生成 16 字节随机数
      let randData: Uint8Array | null = null;
      let retryCount = 0;
      while (retryCount < 3) {
        randData = rand?.generateRandomSync(len)?.data;
        if (randData) {
          break;
        }
        retryCount++;
      }
      if (!randData) {
        this.isBiometricAuthenticating = false;
        AppToast.show(this.getUIContext(), $r('app.string.unlock_biometric_start_failed'));
        return;
      }

      // 设置认证参数
      const authParam: userAuth.AuthParam = {
        challenge: randData,
        authType: [userAuth.UserAuthType.PIN, userAuth.UserAuthType.FACE, userAuth.UserAuthType.FINGERPRINT],
        authTrustLevel: userAuth.AuthTrustLevel.ATL3,
      };

      // 配置认证界面
      const authTitle: string = this.getUIContext().getHostContext()?.resourceManager
        .getStringSync($r('app.string.unlock_auth_title')) ?? '';
      const widgetParam: userAuth.WidgetParam = {
        title: authTitle,
      };

      // 获取认证对象
      const userAuthInstance = userAuth.getUserAuthInstance(authParam, widgetParam);
      this.biometricAuthInstance = userAuthInstance;
      Logger.info('get userAuth instance success');

      // 订阅认证结果
      userAuthInstance.on('result', {
        onResult: (result) => {
          if (this.biometricAuthInstance !== userAuthInstance || !this.isPageActive) {
            return;
          }
          Logger.info('Biometric authentication callback received');
          // 结果监听为一次性订阅，页面复用时不能残留旧回调
          userAuthInstance.off('result');
          this.biometricAuthInstance = undefined;
          this.isBiometricAuthenticating = false;

          if (result.result === userAuth.UserAuthResultCode.SUCCESS) {
            this.finishUnlock();
          } else {
            // 认证失败，显示提示
            AppToast.show(this.getUIContext(), $r('app.string.unlock_biometric_failed'));
          }
        }
      });
      Logger.info('auth on success');
      userAuthInstance.start();
      Logger.info('auth start success');
    } catch (error) {
      this.cancelBiometricAuth();
      const err = error as BusinessError;
      Logger.error(`Failed to start biometric auth. Error: ${JSON.stringify(err)}`);
      AppToast.show(this.getUIContext(), $r('app.string.unlock_biometric_start_failed'));
    }
  }
}
