import { Cipher, CipherDisplayNameKind, CipherDisplaySubtitleKind } from '../model/CipherModels';
import { CipherItemType } from '../utils/Constants';

export enum CipherCopyField {
  USERNAME = 0,
  PASSWORD = 1,
  TOTP = 2,
  CARD_NUMBER = 3,
  SECURITY_CODE = 4,
  EMAIL = 5,
  PHONE = 6,
  ADDRESS = 7
}

@Component
export struct CipherItem {
  cipher: Cipher = {} as Cipher;
  @Prop grouped: boolean = false;
  @Prop firstInGroup: boolean = false;
  @Prop lastInGroup: boolean = false;
  onTap?: () => void;
  onCopyField?: (field: CipherCopyField) => void;
  onEdit?: () => void;
  onOpenUrl?: () => void;

  @Builder
  CipherTypeIcon() {
    Image(this.getTypeIcon())
      .width(24)
      .height(24)
      .objectFit(ImageFit.Contain)
      .margin({ right: 16 })
      .accessibilityLevel('no')
  }

  private getTypeIcon(): Resource {
    switch (this.cipher.type) {
      case CipherItemType.LOGIN:
        return $r('app.media.icon_cipher_login');
      case CipherItemType.NOTE:
        return $r('app.media.icon_cipher_note');
      case CipherItemType.CARD:
        return $r('app.media.icon_cipher_card');
      case CipherItemType.IDENTITY:
        return $r('app.media.icon_cipher_identity');
      default:
        return $r('app.media.icon_cipher_unknown');
    }
  }

  private getDisplayName(): ResourceStr {
    if (this.cipher.displayNameKind === CipherDisplayNameKind.DECRYPTION_FAILED) {
      // 解密失败时不得把原始密文直接展示给用户
      return $r('app.string.vault_decryption_failed_name');
    }
    return this.cipher.name;
  }

  private getDisplaySubtitle(): ResourceStr {
    switch (this.cipher.displaySubtitleKind) {
      case CipherDisplaySubtitleKind.DECRYPTION_FAILED:
        return $r('app.string.vault_decryption_failed_subtitle');
      case CipherDisplaySubtitleKind.LOGIN:
        return $r('app.string.vault_type_login');
      case CipherDisplaySubtitleKind.NOTE:
        return $r('app.string.vault_type_note');
      case CipherDisplaySubtitleKind.CARD:
        return $r('app.string.vault_type_card');
      case CipherDisplaySubtitleKind.IDENTITY:
        return $r('app.string.vault_type_identity');
      case CipherDisplaySubtitleKind.UNKNOWN:
        return $r('app.string.vault_type_unknown');
      default:
        return this.cipher.subtitle ?? '';
    }
  }

  private getMenuItems(): MenuElement[] {
    const items: MenuElement[] = [];
    if (this.cipher.type === CipherItemType.LOGIN) {
      this.addCopyMenuItem(items, $r('app.string.vault_copy_username'), CipherCopyField.USERNAME);
      this.addCopyMenuItem(items, $r('app.string.vault_copy_password'), CipherCopyField.PASSWORD);
      if (this.cipher.hasTotp) {
        this.addCopyMenuItem(items, $r('app.string.vault_copy_totp'), CipherCopyField.TOTP);
      }
    } else if (this.cipher.type === CipherItemType.CARD) {
      this.addCopyMenuItem(items, $r('app.string.vault_copy_card_number'), CipherCopyField.CARD_NUMBER);
      this.addCopyMenuItem(items, $r('app.string.vault_copy_security_code'), CipherCopyField.SECURITY_CODE);
    } else if (this.cipher.type === CipherItemType.IDENTITY) {
      this.addCopyMenuItem(items, $r('app.string.vault_copy_username'), CipherCopyField.USERNAME);
      this.addCopyMenuItem(items, $r('app.string.vault_copy_email'), CipherCopyField.EMAIL);
      this.addCopyMenuItem(items, $r('app.string.vault_copy_phone'), CipherCopyField.PHONE);
      this.addCopyMenuItem(items, $r('app.string.vault_copy_address'), CipherCopyField.ADDRESS);
    }
    items.push({
      value: $r('app.string.common_view'),
      action: () => this.onTap?.()
    });
    if (this.cipher.edit && !this.cipher.deletedDate) {
      items.push({
        value: $r('app.string.common_edit'),
        action: () => this.onEdit?.()
      });
    }
    if (this.cipher.type === CipherItemType.LOGIN) {
      items.push({
        value: $r('app.string.vault_menu_open_url'),
        action: () => this.onOpenUrl?.()
      });
    }
    return items;
  }

  private addCopyMenuItem(items: MenuElement[], label: ResourceStr, field: CipherCopyField): void {
    items.push({
      value: label,
      action: () => this.onCopyField?.(field)
    });
  }

  @Builder
  private ContextMenuBuilder() {
    Menu() {
      ForEach(this.getMenuItems(), (item: MenuElement) => {
        MenuItem({ content: item.value })
          .onClick(() => {
            item.action?.();
          })
      })
    }
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Row() {
      Row() {
        // 类型图标
        this.CipherTypeIcon()

        // 内容区域
        Column() {
          Text(this.getDisplayName())
            .fontSize(15)
            .lineHeight(20)
            .fontWeight(FontWeight.Regular)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(this.getDisplaySubtitle())
            .fontSize(13)
            .lineHeight(18)
            .fontColor($r('app.color.vault_secondary_text'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 2 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .alignItems(VerticalAlign.Center)
      .accessibilityGroup(true)
      .onClick(() => {
        this.onTap?.();
      })

      Button() {
        Text('\u22ef')
          .fontSize(24)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.icon_primary'))
      }
      .type(ButtonType.Circle)
      .buttonStyle(ButtonStyleMode.TEXTUAL)
      .width(48)
      .height(48)
      .padding(0)
      .accessibilityText($r('app.string.vault_item_menu'))
      .bindMenu(this.getMenuItems(), {
        backgroundColor: $r('app.color.menu_background_color'),
        backgroundBlurStyle: BlurStyle.NONE
      })
      }
      .width('100%')
      .constraintSize({ minHeight: 60 })
      .padding({ left: 16, right: 4, top: 6, bottom: 6 })
      if (!this.grouped || !this.lastInGroup) {
        Divider()
          .color($r('app.color.vault_divider_color'))
          .margin({ left: 56 })
      }
    }
    .width('100%')
    .backgroundColor($r('app.color.vault_list_background'))
    .borderRadius({
      topLeft: this.grouped && this.firstInGroup ? 12 : 0,
      topRight: this.grouped && this.firstInGroup ? 12 : 0,
      bottomLeft: this.grouped && this.lastInGroup ? 12 : 0,
      bottomRight: this.grouped && this.lastInGroup ? 12 : 0
    })
    .clip(true)
    .bindContextMenu(this.ContextMenuBuilder, ResponseType.RightClick, {
      backgroundColor: $r('app.color.menu_background_color'),
      backgroundBlurStyle: BlurStyle.NONE
    })
  }
}
