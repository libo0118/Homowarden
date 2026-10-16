import { AppToast } from '../utils/AppToast';
import { Cipher } from '../model/CipherModels';
import { TOTPUtil } from '../utils/TOTPUtil';
import { BusinessError, pasteboard } from '@kit.BasicServicesKit';
import { Logger } from '@nzy/logger';

/**
 * TOTP验证码列表项组件
 * 显示密码项信息和TOTP验证码
 */
@Component
export struct TotpListItem {
  @Prop cipher: Cipher;
  @Prop firstInGroup: boolean = false;
  @Prop lastInGroup: boolean = false;
  @Prop @Watch('handleWebsiteIconChanged') websiteIconUrl: string = '';
  @State websiteIconFailed: boolean = false;
  @State currentCode: string = '--- ---';
  @State remainingSeconds: number = 30;
  @Prop currentTime: number = Date.now(); // 从父组件接收时间变化
  private timerId: number = -1;
  onTap?: () => void;

  async aboutToAppear() {
    await this.updateCode();
    // 定时器仅属于当前组件实例，组件销毁时由 aboutToDisappear 对称释放
    this.startTimer();
  }

  aboutToDisappear() {
    this.stopTimer();
  }

  private handleWebsiteIconChanged(): void {
    this.websiteIconFailed = false;
  }

  /**
   * 更新验证码和剩余时间
   */
  private async updateCode() {
    if (this.cipher.login?.totp) {
      try {
        const code = await TOTPUtil.generateTOTP(this.cipher.login.totp);
        // 格式化为 3+3 格式，便于阅读
        this.currentCode = `${code.substring(0, 3)} ${code.substring(3)}`;
        this.remainingSeconds = TOTPUtil.getRemainingSeconds();
      } catch (error) {
        this.currentCode = '------';
      }
    }
  }

  /**
   * 启动定时器
   */
  private startTimer() {
    // 每秒更新一次
    this.timerId = setInterval(() => {
      const newRemaining = TOTPUtil.getRemainingSeconds();

      // 检测是否进入新的30秒周期
      if (newRemaining > this.remainingSeconds || newRemaining === 30) {
        // 新的周期，更新验证码
        this.updateCode();
      } else {
        // 仅更新剩余时间
        this.remainingSeconds = newRemaining;
      }
    }, 1000);
  }

  /**
   * 停止定时器
   */
  private stopTimer() {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  /**
   * 复制验证码到剪贴板
   */
  private async copyCode() {
    try {
      // 验证码属于短期敏感数据，仅在用户主动操作时写入系统剪贴板
      const codeToCopy = this.currentCode.replace(/\s/g, '');
      if (codeToCopy === '------') {
        AppToast.show(this.getUIContext(), $r('app.string.totp_invalid'));
        return;
      }

      const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, codeToCopy);
      const systemPasteboard = pasteboard.getSystemPasteboard();
      await systemPasteboard.setData(pasteData);
      AppToast.show(this.getUIContext(), $r('app.string.totp_copied'));
    } catch (error) {
      const err = error as BusinessError;
      Logger.error(`Failed to copy code: ${err.message}`);
      AppToast.show(this.getUIContext(), $r('app.string.totp_copy_failed'));
    }
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Row() {
        Row() {
          Stack() {
            if (this.websiteIconUrl && !this.websiteIconFailed) {
              Image(this.websiteIconUrl)
                .alt($r('app.media.icon_cipher_login'))
                .width(24)
                .height(24)
                .objectFit(ImageFit.Contain)
                .onError(() => { this.websiteIconFailed = true; })
                .accessibilityLevel('no')
            } else {
              Image($r('app.media.icon_cipher_login'))
                .width(24)
                .height(24)
                .objectFit(ImageFit.Contain)
                .accessibilityLevel('no')
            }
          }
          .width(24)
          .height(24)
          .margin({ right: 16 })
          .accessibilityLevel('no')

          Column() {
            Text(this.cipher.name)
              .fontSize(15)
              .lineHeight(20)
              .fontWeight(FontWeight.Regular)
              .fontColor($r('sys.color.font_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            if (this.cipher.login?.username) {
              Text(this.cipher.login.username)
                .fontSize(13)
                .lineHeight(18)
                .fontColor($r('app.color.vault_secondary_text'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .margin({ top: 2 })
            }

          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .layoutWeight(1)
        .alignItems(VerticalAlign.Center)
        .accessibilityGroup(true)
        .onClick(() => {
          this.onTap?.();
        })

        Column() {
          Stack({ alignContent: Alignment.Center }) {
            Progress({ value: this.remainingSeconds, total: 30, type: ProgressType.Ring })
              .width(30)
              .height(30)
              .color($r('app.color.brand_accent_color'))
              .style({ strokeWidth: 3 })
            Text(this.remainingSeconds.toString())
              .fontSize(12)
              .fontColor($r('app.color.vault_secondary_text'))
          }
          .width(30)
          .height(30)
          .accessibilityLevel('no')
        }
        .width(56)
        .height(56)
        .justifyContent(FlexAlign.Center)
        .accessibilityGroup(true)
        .accessibilityText($r('app.string.totp_seconds', this.remainingSeconds))

        Text(this.currentCode)
          .fontSize(14)
          .lineHeight(20)
          .fontFamily('monospace')
          .letterSpacing(0.5)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)

        Button() {
          Image($r('app.media.icon_copy'))
            .width(24)
            .height(24)
            .fillColor($r('sys.color.icon_primary'))
            .accessibilityLevel('no')
        }
        .type(ButtonType.Circle)
        .buttonStyle(ButtonStyleMode.TEXTUAL)
        .width(48)
        .height(48)
        .margin({ left: 16 })
        .padding(0)
        .accessibilityText($r('app.string.accessibility_copy_totp'))
        .onClick(() => {
          this.copyCode();
        })
      }
      .width('100%')
      .constraintSize({ minHeight: 80 })
      .padding({ left: 16, right: 4, top: 10, bottom: 10 })

      if (!this.lastInGroup) {
        Divider()
          .color($r('app.color.vault_divider_color'))
          .margin({ left: 56 })
      }
    }
    .width('100%')
    .backgroundColor($r('app.color.vault_list_background'))
    .borderRadius({
      topLeft: this.firstInGroup ? 8 : 0,
      topRight: this.firstInGroup ? 8 : 0,
      bottomLeft: this.lastInGroup ? 8 : 0,
      bottomRight: this.lastInGroup ? 8 : 0
    })
    .clip(true)
  }
}
