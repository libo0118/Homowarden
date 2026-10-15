/** 宽屏三栏容器，具体列表与详情内容由主页面注入 */
@Component
export struct AdaptiveShell {
  @BuilderParam railBuilder: () => void;
  @BuilderParam listBuilder: () => void;
  @BuilderParam detailBuilder: () => void;

  build() {
    Row() {
      this.railBuilder()
      Column() {
        this.listBuilder()
      }
      .width('36%')
      .height('100%')
      .backgroundColor($r('app.color.vault_list_background'))
      Divider()
        .vertical(true)
        .width(1)
        .height('100%')
        .color($r('app.color.vault_divider_color'))
      Column() {
        this.detailBuilder()
      }
      .layoutWeight(1)
      .height('100%')
      .backgroundColor($r('app.color.vault_detail_background'))
    }
    .width('100%')
    .height('100%')
  }
}
