import { AppDropdown } from './AppDropdown';
import { AppDropdownOption } from '../model/AppUiModels';

@Component
export struct CipherDetailDropdownItem {
  // 文本标题
  @Prop label: ResourceStr;
  // 显示文本内容
  @Prop content: ResourceStr;
  // 下拉菜单选项
  @Prop dropdownOptions: AppDropdownOption[];
  // 下拉菜单组ID
  @Prop groupId: string;
  // 当前选中的值
  @Prop selectedValue: number;
  // 值变化回调
  onValueChange?: (value: number) => void;
  // 是否编辑模式
  @Prop isEditable: boolean = false;

  private getAccessibilityLabel(): string {
    if (typeof this.label === 'string') {
      return this.label;
    }
    return this.getUIContext().getHostContext()?.resourceManager.getStringSync(this.label.id) ?? '';
  }

  build() {
    Column({ space: 4 }) {
      Text(this.label)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.vault_secondary_text'))
        .width('100%')

      if (this.isEditable) {
        AppDropdown({
          options: this.dropdownOptions,
          value: this.selectedValue,
          accessibilityLabel: this.label,
          onChange: (value: number) => {
            if (this.onValueChange) {
              this.onValueChange(value);
            }
          }
        })
      } else {
        Text(this.content)
          .fontSize(16)
          .width('100%')
      }
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
  }
}
