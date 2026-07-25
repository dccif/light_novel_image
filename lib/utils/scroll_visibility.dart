/// 判断一个内容区域是否完整处于滚动视口中。
class ScrollVisibility {
  const ScrollVisibility._();

  static bool isFullyVisible({
    required double itemTop,
    required double itemBottom,
    required double viewportTop,
    required double viewportBottom,
  }) {
    return itemTop >= viewportTop && itemBottom <= viewportBottom;
  }
}
