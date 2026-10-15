import { MainNavigationItem, mainNavigationItems, MainTab } from './MainNavigationItems';

/** 宽屏主导航，页签语义与手机底部导航保持一致 */
@Component
export struct MainSideRail {
  @Prop selectedMainTab: MainTab = MainTab.VAULT;
  onSelect: (tab: MainTab) => void = () => {};

  @Builder
  private navigationItem(tab: MainTab, label: Resource, icon: Resource) {
    Row() {
      Column({ space: 4 }) {
        Image(icon)
          .width(24)
          .height(24)
          .fillColor($r('app.color.main_rail_icon_color'))
        Text(label)
          .fontSize(12)
          .fontWeight(this.selectedMainTab === tab ? FontWeight.Medium : FontWeight.Regular)
          .fontColor($r('app.color.main_rail_icon_color'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .opacity(this.selectedMainTab === tab ? 1 : 0.9)
    }
    .width(96)
    .height(64)
    .backgroundColor(this.selectedMainTab === tab ?
      $r('app.color.main_rail_selected_background') : Color.Transparent)
    .borderRadius(6)
    .margin({ left: 8, right: 8, top: 4, bottom: 4 })
    .accessibilityGroup(true)
    .accessibilityText(label)
    .onClick(() => this.onSelect(tab))
  }

  build() {
    Column() {
      ForEach(mainNavigationItems(), (item: MainNavigationItem) => {
        this.navigationItem(item.tab, item.label, item.icon)
      }, (item: MainNavigationItem) => item.tab.toString())
    }
    .width(112)
    .height('100%')
    .padding({ top: 8 })
    .backgroundColor($r('app.color.main_nav_background'))
  }
}
