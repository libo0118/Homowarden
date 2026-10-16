import { AppToast } from '../utils/AppToast';
import { queryAssetSync } from '../utils/AssetUtil';
import { EMAIL_KEY, SAVE_EMAIL, ServerType } from '../utils/Constants';
import { LoginViewModel } from '../viewmodel/LoginViewModel';
import { EntryRouter } from '../../../../EntryRouter';
import { common } from '@kit.AbilityKit';
import { DataPreferences } from '@abner/datastore';
import { HdsNavDestination } from '@hms.hds.hdsBaseComponent';
import { WindowPrivacyUtil } from '../utils/WindowPrivacyUtil';
import { FormDialog } from '../component/FormDialog';
import { TwoFactorProvider } from '../model/AccessToken';
import { AppText, AppTextKey } from '../localization/AppText';
import { AppTextResolver } from '../localization/AppTextResolver';
import { VaultViewModel } from '../viewmodel/VaultViewModel';
import { FormFactorUtil } from '../utils/FormFactorUtil';
import { LogExportDialog } from '../component/LogExportDialog';

@CustomDialog
struct ServerTypeDialog {
  controller: CustomDialogController;
  onSelect: (serverType: ServerType) => void = () => {
  };

  private select(serverType: ServerType): void {
    this.controller.close();
    this.onSelect(serverType);
  }

  @Builder
  private serverOption(text: ResourceStr, serverType: ServerType) {
    Button(text)
      .type(ButtonType.Normal)
      .width('100%')
      .height(48)
      .borderRadius(8)
      .backgroundColor($r('app.color.translucent_button_background'))
      .fontColor($r('app.color.brand_accent_color'))
      .onClick(() => {
        this.select(serverType);
      })
  }

  build() {
    Column({ space: 8 }) {
      this.serverOption('bitwarden.com', ServerType.US)
      this.serverOption('bitwarden.eu', ServerType.EU)
      this.serverOption($r('app.string.server_self_hosted'), ServerType.SELF_HOSTED)
      Button($r('app.string.common_cancel'))
        .type(ButtonType.Normal)
        .width('100%')
        .height(48)
        .borderRadius(8)
        .backgroundColor($r('app.color.translucent_button_background'))
        .fontColor($r('app.color.brand_accent_color'))
        .onClick(() => {
          this.controller.close();
        })
    }
    .padding(16)
  }
}

@Builder
export function LoginPageBuilder() {
  LoginPage();
}

@Component
export struct LoginPage {
  @State viewModel: LoginViewModel = new LoginViewModel();
  @State isLoading: boolean = false;
  @State isNeed2FA: boolean = false;
  @State isNeedNewDevice: boolean = false;
  @State twoFactorInputError: boolean = false;
  @State twoFactorInputHint: ResourceStr = '';
  @State needToSaveEmail: boolean = false;
  @State twoFactorRemember: boolean = false;
  @State pendingEmailLogin: boolean = false;
  @State verificationSubmitting: boolean = false;
  @State feedbackVisible: boolean = false;
  @State mobilePasswordStep: boolean = false;
  private exitTime: number = 0;
  private isPc: boolean = FormFactorUtil.isPc();
  pathInfos: NavPathStack = new NavPathStack();

  private logExportDialogController: CustomDialogController = new CustomDialogController({
    builder: LogExportDialog({}),
    autoCancel: false,
    alignment: DialogAlignment.Center,
    customStyle: false
  })

  private serverTypeDialogController: CustomDialogController = new CustomDialogController({
    builder: ServerTypeDialog({
      onSelect: (serverType: ServerType) => {
        this.viewModel.serverType = serverType;
        this.viewModel.clearError();
        this.feedbackVisible = false;
      }
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    customStyle: false
  })

  // 两步验证弹框控制器（系统原生 @CustomDialog 容器）
  twoFactorDialogController: CustomDialogController = new CustomDialogController({
    builder: FormDialog({
      title: $r('app.string.login_two_factor_title'),
      contentBuilder: (): void => this.twoFactorInputContent(),
      cancel: () => {
        this.isNeed2FA = false;
        this.feedbackVisible = false;
      },
      confirm: async (): Promise<void> => {
        await this.handleTwoFactorConfirm();
      }
    }),
    cancel: () => {
      this.isNeed2FA = false;
    },
    onWillDismiss: (action: DismissDialogAction) => {
      if (!this.verificationSubmitting) {
        this.isNeed2FA = false;
        action.dismiss();
      }
    },
    autoCancel: false,
    alignment: DialogAlignment.Center,
    customStyle: false
  })

  // 新设备验证弹框控制器
  newDeviceDialogController: CustomDialogController = new CustomDialogController({
    builder: FormDialog({
      title: $r('app.string.login_new_device_title'),
      contentBuilder: (): void => this.newDeviceInputContent(),
      cancel: () => {
        this.isNeedNewDevice = false;
        this.feedbackVisible = false;
      },
      confirm: async (): Promise<void> => {
        await this.handleNewDeviceConfirm();
      }
    }),
    cancel: () => {
      this.isNeedNewDevice = false;
    },
    onWillDismiss: (action: DismissDialogAction) => {
      if (!this.verificationSubmitting) {
        this.isNeedNewDevice = false;
        action.dismiss();
      }
    },
    autoCancel: false,
    alignment: DialogAlignment.Center,
    customStyle: false
  })

  aboutToAppear() {
    this.viewModel.loadServerConfig();
    const queryResult = DataPreferences.getInstance().getSync<number>(SAVE_EMAIL);
    if (queryResult && queryResult == 1) {
      this.needToSaveEmail = true;
      this.viewModel.needSaveEmail = true;
      this.loadSaveEmail();
    }
  }

  private loadSaveEmail() {
    const email = queryAssetSync(EMAIL_KEY);
    if (email) {
      this.viewModel.email = email;
    }
  }

  @Builder
  twoFactorInputContent() {
    Column({ space: 20 }) {
      Text(this.viewModel.twoFactorProvider === TwoFactorProvider.WEB_AUTHN ? $r('app.string.login_passkey_prompt') : $r('app.string.login_two_factor_prompt'))
        .margin(12)

      if (this.getVisibleTwoFactorProviders().length > 1) {
        Column({ space: 8 }) {
          ForEach(this.getVisibleTwoFactorProviders(), (provider: number) => {
            Button(this.getTwoFactorProviderText(provider))
              .width('100%')
              .backgroundColor($r('app.color.translucent_button_background'))
              .fontColor($r('sys.color.font_primary'))
              .stateEffect(provider !== this.viewModel.twoFactorProvider)
              .enabled(provider !== this.viewModel.twoFactorProvider)
              .onClick(() => {
                this.viewModel.setTwoFactorProvider(provider);
                this.twoFactorInputError = false;
                this.feedbackVisible = false;
                this.updateUI();
              })
          })
        }
      }

      if (this.viewModel.twoFactorProvider !== TwoFactorProvider.WEB_AUTHN) {
        TextInput({ placeholder: $r('app.string.login_enter') })
          .accessibilityText($r('app.string.login_two_factor_prompt'))
          .onChange(value => {
            this.viewModel.twoFactorToken = value;
            this.twoFactorInputError = false;
            this.feedbackVisible = false;
          })
          .onSubmit(async () => {
            await this.handleTwoFactorConfirm();
          })
          .type(InputType.Number)
      }

      Row() {
        Toggle({ type: ToggleType.Switch, isOn: this.twoFactorRemember })
          .selectedColor($r('app.color.brand_accent_color'))
          .onChange((isOn: boolean) => {
            this.twoFactorRemember = isOn;
            this.viewModel.twoFactorRemember = isOn;
          })
          .accessibilityText($r('app.string.login_remember_me'))
        Text($r('app.string.login_remember_me'))
          .margin(12)
      }

      if (this.twoFactorInputError) {
        Text(this.twoFactorInputHint)
          .width("100%")
          .textAlign(TextAlign.Center)
          .fontColor(Color.Red)
          .fontSize(16)
        if (this.feedbackVisible) {
          this.feedbackEntry()
        }
      }

      if (this.viewModel.twoFactorProvider == TwoFactorProvider.EMAIL) {
        Button($r('app.string.login_send_email_code'))
          .onClick(async () => {
            // 请求未结束前禁用按钮，避免并发发送多个邮箱验证码
            this.pendingEmailLogin = true;
            const result = await this.viewModel.doSendEmailLogin();
            if (!result) {
              this.twoFactorInputError = true;
              this.feedbackVisible = true;
              this.twoFactorInputHint = AppTextResolver.resource(this.viewModel.errorMessage ??
                new AppText(AppTextKey.CODE_SEND_FAILED));
            } else {
              this.twoFactorInputError = true;
              this.feedbackVisible = false;
              this.twoFactorInputHint = $r('app.string.login_code_sent');
            }
            this.pendingEmailLogin = false;
          })
          .enabled(!this.pendingEmailLogin)
      }
    }
  }

  @Builder
  newDeviceInputContent() {
    Column({ space: 20 }) {
      Text($r('app.string.login_new_device_prompt'))
        .margin(12)
      TextInput({ placeholder: $r('app.string.login_enter') })
        .accessibilityText($r('app.string.login_new_device_prompt'))
        .onChange(value => {
          this.viewModel.twoFactorToken = value;
          this.twoFactorInputError = false;
          this.feedbackVisible = false;
        })
        .onSubmit(async () => {
          await this.handleNewDeviceConfirm();
        })
        .type(InputType.Number)

      if (this.twoFactorInputError) {
        Text(this.twoFactorInputHint)
          .width("100%")
          .textAlign(TextAlign.Center)
          .fontColor(Color.Red)
          .fontSize(16)
        if (this.feedbackVisible) {
          this.feedbackEntry()
        }
      }

      Button($r('app.string.login_send_email_code'))
        .onClick(async () => {
          // 新设备验证码重发与 2FA 邮件发送共享防重入状态
          this.pendingEmailLogin = true;
          const result = await this.viewModel.doResendNewDeviceOtp();
          if (!result) {
            this.twoFactorInputError = true;
            this.feedbackVisible = true;
            this.twoFactorInputHint = AppTextResolver.resource(this.viewModel.errorMessage ??
              new AppText(AppTextKey.CODE_SEND_FAILED));
          } else {
            this.twoFactorInputError = true;
            this.feedbackVisible = false;
            this.twoFactorInputHint = $r('app.string.login_code_sent');
          }
          this.pendingEmailLogin = false;
        })
        .enabled(!this.pendingEmailLogin)
    }
  }

  @Builder
  private mobileLandingContent() {
    Column() {
      Row({ space: 12 }) {
        Image($r('app.media.app_small_icon'))
          .width(56)
          .height(56)
          .accessibilityLevel('no')
        Text('Homowarden')
          .fontSize(32)
          .fontWeight(FontWeight.Normal)
          .fontColor($r('app.color.brand_accent_color'))
      }
      .justifyContent(FlexAlign.Center)
      .width('100%')
      .margin({ top: 52, bottom: 64 })

      Text($r('app.string.login_welcome'))
        .fontSize(18)
        .lineHeight(26)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .textAlign(TextAlign.Center)
        .width('100%')
        .margin({ bottom: 24 })

      Column() {
        Column() {
          Text($r('app.string.login_email'))
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.vault_secondary_text'))
            .width('100%')
          TextInput({ text: this.viewModel.email })
            .accessibilityText($r('app.string.login_email'))
            .type(InputType.Email)
            .enterKeyType(EnterKeyType.Next)
            .fontSize(16)
            .height(32)
            .padding(0)
            .borderRadius(0)
            .backgroundColor(Color.Transparent)
            .onChange((value: string) => {
              this.viewModel.email = value;
              this.viewModel.clearError();
              this.feedbackVisible = false;
            })
            .onSubmit(() => {
              this.continueToPassword();
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        .constraintSize({ minHeight: 60 })

        Divider()
          .color($r('app.color.vault_divider_color'))

        Button() {
          Row({ space: 8 }) {
            Text($r('app.string.login_environment'))
              .fontSize(14)
              .fontColor($r('app.color.vault_secondary_text'))
            Blank()
            Text(this.getServerTypeButtonText())
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.brand_accent_color'))
            Image($r('app.media.icon_chevron_down'))
              .width(16)
              .height(16)
              .fillColor($r('app.color.brand_accent_color'))
              .accessibilityLevel('no')
          }
          .width('100%')
        }
        .type(ButtonType.Normal)
        .width('100%')
        .height(48)
        .padding({ left: 16, right: 16 })
        .backgroundColor(Color.Transparent)
        .borderRadius({ bottomLeft: 12, bottomRight: 12 })
        .accessibilityText($r('app.string.login_select_server'))
        .onClick(() => {
          this.serverTypeDialogController.open();
        })
      }
      .width('100%')
      .backgroundColor($r('app.color.vault_list_background'))
      .borderRadius(12)

      if (this.viewModel.serverType === ServerType.SELF_HOSTED) {
        Row({ space: 8 }) {
          Text('https://')
            .fontSize(16)
            .fontColor($r('app.color.vault_secondary_text'))
          TextInput({
            placeholder: $r('app.string.login_domain_placeholder'),
            text: this.viewModel.serverAddress
          })
            .accessibilityText($r('app.string.login_select_server'))
            .type(InputType.URL)
            .fontSize(16)
            .height(48)
            .padding(0)
            .backgroundColor(Color.Transparent)
            .layoutWeight(1)
            .onChange((value: string) => {
              this.viewModel.serverAddress = value;
              this.viewModel.clearError();
              this.feedbackVisible = false;
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
        .backgroundColor($r('app.color.vault_list_background'))
        .borderRadius(12)
        .margin({ top: 8 })
      }

      Row({ space: 16 }) {
        Text($r('app.string.login_remember_email'))
          .fontSize(16)
          .fontColor($r('sys.color.font_primary'))
          .layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.needToSaveEmail })
          .width(52)
          .height(32)
          .selectedColor($r('app.color.brand_accent_color'))
          .onChange((isOn: boolean) => {
            this.needToSaveEmail = isOn;
            this.viewModel.needSaveEmail = isOn;
            DataPreferences.getInstance().putSync(SAVE_EMAIL, isOn ? 1 : 0);
          })
          .accessibilityText($r('app.string.login_remember_email'))
      }
      .width('100%')
      .constraintSize({ minHeight: 56 })
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor($r('app.color.vault_list_background'))
      .borderRadius(12)
      .margin({ top: 8, bottom: 24 })

      Button($r('app.string.login_continue'))
        .type(ButtonType.Normal)
        .width('100%')
        .height(48)
        .borderRadius(24)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.button_foreground_color'))
        .backgroundColor($r('app.color.button_background_color'))
        .enabled(this.viewModel.email.trim().length > 0)
        .onClick(() => {
          this.continueToPassword();
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 24 })
  }

  @Builder
  private mobilePasswordContent() {
    Column() {
      Column() {
        Text($r('app.string.login_master_password'))
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.vault_secondary_text'))
          .width('100%')
        TextInput({ text: this.viewModel.password })
          .accessibilityText($r('app.string.login_master_password'))
          .type(InputType.Password)
          .enterKeyType(EnterKeyType.Go)
          .fontSize(16)
          .height(36)
          .padding(0)
          .borderRadius(0)
          .backgroundColor(Color.Transparent)
          .enabled(!this.isLoading)
          .onChange((value: string) => {
            this.viewModel.password = value;
            this.viewModel.clearError();
            this.feedbackVisible = false;
          })
          .onSubmit(async () => {
            await this.handleLogin();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .constraintSize({ minHeight: 60 })
      .backgroundColor($r('app.color.vault_list_background'))
      .borderRadius(12)

      Button(this.isLoading ? $r('app.string.login_in_progress') : $r('app.string.login_action'))
        .type(ButtonType.Normal)
        .width('100%')
        .height(48)
        .borderRadius(24)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.button_foreground_color'))
        .backgroundColor($r('app.color.button_background_color'))
        .margin({ top: 24 })
        .enabled(!this.isLoading && this.viewModel.password.length > 0)
        .onClick(() => {
          void this.handleLogin();
        })

      Text($r('app.string.login_account_context', this.viewModel.email.trim(), this.getSelectedServerAddress()))
        .fontSize(12)
        .lineHeight(16)
        .fontColor($r('app.color.vault_secondary_text'))
        .textAlign(TextAlign.Center)
        .width('100%')
        .margin({ top: 24 })
      Button($r('app.string.login_not_you'))
        .type(ButtonType.Normal)
        .height(48)
        .padding({ left: 16, right: 16 })
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .backgroundColor(Color.Transparent)
        .fontColor($r('app.color.brand_accent_color'))
        .enabled(!this.isLoading)
        .onClick(() => {
          this.returnToEmail();
        })

      if (this.viewModel.errorMessage) {
        Text(AppTextResolver.resource(this.viewModel.errorMessage))
          .fontSize(14)
          .fontColor(Color.Red)
          .width('100%')
          .margin({ top: 12 })
        if (this.feedbackVisible) {
          this.feedbackEntry()
        }
      }
      if (this.viewModel.successMessage) {
        Text(AppTextResolver.resource(this.viewModel.successMessage))
          .fontSize(14)
          .fontColor(Color.Green)
          .width('100%')
          .margin({ top: 12 })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 24 })
  }

  @Builder
  private mobileContent() {
    Column() {
      if (this.mobilePasswordStep) {
        Row({ space: 16 }) {
          Button() {
            Image($r('app.media.icon_cancel'))
              .width(24)
              .height(24)
              .fillColor($r('sys.color.font_primary'))
          }
          .type(ButtonType.Normal)
          .width(48)
          .height(48)
          .padding(12)
          .borderRadius(24)
          .backgroundColor(Color.Transparent)
          .accessibilityText($r('app.string.common_cancel'))
          .enabled(!this.isLoading)
          .onClick(() => {
            this.returnToEmail();
          })
          Text('Homowarden')
            .fontSize(19)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
            .layoutWeight(1)
        }
        .height(48)
        .width('100%')
        .padding({ left: 4, right: 16 })
      }

      Scroll() {
        Column() {
          if (this.mobilePasswordStep) {
            this.mobilePasswordContent()
          } else {
            this.mobileLandingContent()
          }
        }
        .width('100%')
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.start_window_background'))
  }

  private continueToPassword(): void {
    if (this.viewModel.email.trim().length === 0) {
      AppToast.show(this.getUIContext(), $r('app.string.login_error_email_required'));
      return;
    }
    if (this.viewModel.serverType === ServerType.SELF_HOSTED &&
      this.viewModel.serverAddress.trim().length === 0) {
      AppToast.show(this.getUIContext(), $r('app.string.login_error_server_required'));
      return;
    }
    this.viewModel.clearError();
    this.feedbackVisible = false;
    this.mobilePasswordStep = true;
    this.getUIContext().getFocusController().clearFocus();
  }

  private returnToEmail(): void {
    this.mobilePasswordStep = false;
    this.viewModel.password = '';
    this.viewModel.clearError();
    this.feedbackVisible = false;
    this.exitTime = 0;
    this.getUIContext().getFocusController().clearFocus();
  }

  private getSelectedServerAddress(): string {
    if (this.viewModel.serverType === ServerType.SELF_HOSTED) {
      return 'https://' + this.viewModel.serverAddress;
    }
    return this.viewModel.serverType === ServerType.EU ? 'bitwarden.eu' : 'bitwarden.com';
  }

  build() {
    HdsNavDestination() {
      if (this.isPc) {
      Column() {
        Column() {
        Text('Homowarden')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.brand_accent_color'))
          .margin({ bottom: 16 })

        // 邮箱输入框
        TextInput({
          placeholder: $r('app.string.login_email_placeholder'),
          text: this.viewModel.email
        })
          .accessibilityText($r('app.string.login_email'))
          .type(InputType.Email)
          .onChange((value: string) => {
            this.viewModel.email = value;
            this.viewModel.clearError();
            this.feedbackVisible = false;
          })
          .margin(12)

        // 密码输入框
        TextInput({
          placeholder: $r('app.string.login_password_placeholder'),
          text: this.viewModel.password
        })
          .accessibilityText($r('app.string.login_password'))
          .type(InputType.Password)
          .onChange((value: string) => {
            this.viewModel.password = value;
            this.viewModel.clearError();
            this.feedbackVisible = false;
          })
          .onSubmit(async () => {
            await this.handleLogin();
          })
          .margin(12)

        // 记住邮箱的开关，关联viewModel的needSaveEmail
        Row() {
          Text($r('app.string.login_remember_email'))
            .fontSize(16)
            .margin(12)
          Toggle({ type: ToggleType.Switch, isOn: this.needToSaveEmail })
            .selectedColor($r('app.color.brand_accent_color'))
            .onChange((isOn: boolean) => {
              this.needToSaveEmail = isOn;
              this.viewModel.needSaveEmail = isOn;
              DataPreferences.getInstance().putSync(SAVE_EMAIL, isOn ? 1 : 0);
            })
            .accessibilityText($r('app.string.login_remember_email'))
        }

        Row() {
          // 服务器选择
          Text($r('app.string.login_select_server'))
            .fontSize(16)
            .margin({ right: 8 })
          Button(this.getServerTypeButtonText())
            .stateEffect(false)
            .fontColor($r('app.color.brand_accent_color'))
            .buttonStyle(ButtonStyleMode.TEXTUAL)
            .onClick(() => {
              this.serverTypeDialogController.open();
            })
        }

        if (this.viewModel.serverType == ServerType.SELF_HOSTED) {
          Row() {
            Text('https://')
              .fontSize(16)
              .margin({ right: 8 })
            TextInput({
              placeholder: $r('app.string.login_domain_placeholder'),
              text: this.viewModel.serverAddress
            })
              .accessibilityText($r('app.string.login_select_server'))
              .type(InputType.URL)
              .onChange((value: string) => {
                this.viewModel.serverAddress = value;
                this.viewModel.clearError();
                this.feedbackVisible = false;
              })
              .layoutWeight(1)
          }
          .width('100%')
          .margin(12)
        }

        Button(this.isLoading ? $r('app.string.login_in_progress') : $r('app.string.login_action'))
          .type(ButtonType.Normal)
          .width('100%')
          .height(44)
          .fontSize(16)
          .fontColor($r('app.color.button_foreground_color'))
          .backgroundColor($r('app.color.button_background_color'))
          .borderRadius(6)
          .enabled(!this.isLoading)
          .onClick(() => {
            this.handleLogin();
          })

        // 显示错误信息
        if (this.viewModel.errorMessage) {
          Text(AppTextResolver.resource(this.viewModel.errorMessage))
            .fontSize(14)
            .fontColor(Color.Red)
            .margin(12)
          if (this.feedbackVisible) {
            this.feedbackEntry()
          }
        }

        // 显示成功信息
        if (this.viewModel.successMessage) {
          Text(AppTextResolver.resource(this.viewModel.successMessage))
            .fontSize(14)
            .fontColor(Color.Green)
            .margin(12)
        }

        }
        .width('100%')
        .constraintSize({ maxWidth: 440 })
        .padding({ left: 24, right: 24, top: 28, bottom: 28 })
        .backgroundColor($r('app.color.vault_list_background'))
        .borderRadius(8)
        .borderWidth(1)
        .borderColor($r('app.color.vault_divider_color'))
      }
      .width('100%')
      .height('100%')
      .padding(24)
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.Center)
      .backgroundColor($r('app.color.start_window_background'))
      } else {
        this.mobileContent()
      }
    }
    .titleBar({
      content: {
        title: {
          mainTitle: $r('app.string.login_action')
        }
      },
      enableComponentSafeArea: true
    })
    .hideTitleBar(true)
    .hideBackButton(true)
    .onReady((ctx: NavDestinationContext) => {
      this.pathInfos = ctx.pathStack;
    })
    .onBackPressed(() => {
      if (!this.isPc && this.mobilePasswordStep) {
        if (!this.isLoading) {
          this.returnToEmail();
        }
        return true;
      }
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

  @Builder
  private feedbackEntry() {
    Button($r('app.string.login_feedback'))
      .buttonStyle(ButtonStyleMode.TEXTUAL)
      .fontColor($r('app.color.brand_accent_color'))
      .onClick(() => {
        this.logExportDialogController.open();
      })
  }

  // 处理登录逻辑
  private async handleLogin(): Promise<void> {
    if (this.isLoading) {
      return;
    }
    if (this.viewModel.email.trim().length === 0 || this.viewModel.password.trim().length === 0) {
      AppToast.show(this.getUIContext(), $r('app.string.error_validation'));
      return;
    }
    if (this.viewModel.serverType === ServerType.SELF_HOSTED &&
      this.viewModel.serverAddress.trim().length === 0) {
      AppToast.show(this.getUIContext(), $r('app.string.error_validation'));
      return;
    }
    this.twoFactorInputError = false;
    this.feedbackVisible = false;
    this.viewModel.clearError();
    this.isLoading = true;
    try {
      this.viewModel.needTwoFactor = false;
      this.viewModel.needNewDevice = false;
      const loginSuccess = await this.viewModel.login();
      if (this.viewModel.needTwoFactor) {
        if (this.prepareTwoFactorDialog()) {
          this.isNeed2FA = true;
          this.twoFactorDialogController.open();
        }
      } else if (this.viewModel.needNewDevice) {
        this.isNeedNewDevice = true;
        this.newDeviceDialogController.open();
      } else if (loginSuccess) {
        // 登录成功，跳转到密码库页面
        await this.navigateToVault();
      } else if (this.viewModel.errorMessage) {
        this.feedbackVisible = true;
      }
      this.updateUI();
      this.getUIContext().getFocusController().clearFocus();
    } finally {
      this.isLoading = false;
    }
  }

  // 两步验证确认：异步校验验证码/Passkey，失败时保持弹框打开
  private async handleTwoFactorConfirm(): Promise<void> {
    if (this.verificationSubmitting) {
      return;
    }
    this.verificationSubmitting = true;
    try {
      await this.performTwoFactorConfirm();
    } finally {
      this.verificationSubmitting = false;
    }
  }

  private async performTwoFactorConfirm(): Promise<void> {
    if (this.viewModel.twoFactorProvider === TwoFactorProvider.WEB_AUTHN) {
      const context = this.getUIContext().getHostContext() as common.Context;
      const passkeyResult = await this.viewModel.performPasskeyTwoFactor(context);
      if (!passkeyResult) {
        this.twoFactorInputError = true;
        this.feedbackVisible = true;
        this.twoFactorInputHint = AppTextResolver.resource(this.viewModel.errorMessage ??
          new AppText(AppTextKey.PASSKEY_FAILED));
        return;
      }
    } else {
      const valueLength = this.viewModel.twoFactorToken.trim().length;
      this.twoFactorInputError = !valueLength;
      if (this.twoFactorInputError) {
        this.feedbackVisible = false;
        this.twoFactorInputHint = $r('app.string.login_error_code_required');
        return;
      }
    }
    const result = await this.viewModel.continueLogin();
    if (!result) {
      this.twoFactorInputError = true;
      this.feedbackVisible = true;
      this.twoFactorInputHint = AppTextResolver.resource(this.viewModel.errorMessage ??
        new AppText(this.viewModel.twoFactorProvider === TwoFactorProvider.WEB_AUTHN ?
          AppTextKey.PASSKEY_FAILED : AppTextKey.CODE_INVALID));
      return;
    }
    this.updateUI();
    this.isNeed2FA = false;
    this.twoFactorDialogController.close();
    await this.navigateToVault();
  }

  // 新设备验证确认：异步校验验证码，失败时保持弹框打开
  private async handleNewDeviceConfirm(): Promise<void> {
    if (this.verificationSubmitting) {
      return;
    }
    this.verificationSubmitting = true;
    try {
      await this.performNewDeviceConfirm();
    } finally {
      this.verificationSubmitting = false;
    }
  }

  private async performNewDeviceConfirm(): Promise<void> {
    const valueLength = this.viewModel.twoFactorToken.trim().length;
    this.twoFactorInputError = !valueLength;
    if (this.twoFactorInputError) {
      this.feedbackVisible = false;
      this.twoFactorInputHint = $r('app.string.login_error_code_required');
      return;
    }
    const result = await this.viewModel.continueLogin();
    if (!result) {
      this.twoFactorInputError = true;
      this.feedbackVisible = true;
      this.twoFactorInputHint = AppTextResolver.resource(this.viewModel.errorMessage ??
        new AppText(AppTextKey.CODE_INVALID));
      return;
    }
    this.updateUI();
    this.isNeedNewDevice = false;
    this.newDeviceDialogController.close();
    await this.navigateToVault();
  }

  private prepareTwoFactorDialog(): boolean {
    const visibleProviders = this.getVisibleTwoFactorProviders();
    if (visibleProviders.length === 0) {
      this.viewModel.errorMessage = new AppText(AppTextKey.TWO_FACTOR_UNSUPPORTED);
      this.viewModel.needTwoFactor = false;
      return false;
    }

    if (!visibleProviders.includes(this.viewModel.twoFactorProvider)) {
      this.viewModel.setTwoFactorProvider(visibleProviders[0]);
    }

    return true;
  }

  // 跳转到密码库页面
  private async navigateToVault(): Promise<void> {
    await WindowPrivacyUtil.applyForCurrentState();
    VaultViewModel.beginSession();
    this.pathInfos.replacePath({ name: EntryRouter.VaultPage });
  }

  // 更新UI状态
  private updateUI(): void {
    // 使用clone方法创建新的ViewModel实例来触发UI更新
    this.viewModel = this.viewModel.clone();
  }

  private getTwoFactorProviderText(provider: number): ResourceStr {
    switch (provider) {
      case TwoFactorProvider.WEB_AUTHN:
        return $r('app.string.login_provider_passkey');
      case TwoFactorProvider.EMAIL:
        return $r('app.string.login_provider_email');
      default:
        return $r('app.string.login_provider_authenticator');
    }
  }

  private getVisibleTwoFactorProviders(): number[] {
    // 暂时隐藏通行密钥入口
    return this.viewModel.availableTwoFactorProviders.filter((provider: number) => {
      return provider !== TwoFactorProvider.WEB_AUTHN;
    });
  }

  // 获取服务器类型按钮文本
  private getServerTypeButtonText(): ResourceStr {
    switch (this.viewModel.serverType) {
      case ServerType.EU:
        return 'bitwarden.eu';
      case ServerType.SELF_HOSTED:
        return $r('app.string.server_self_hosted');
      default:
        return 'bitwarden.com';
    }
  }

}
