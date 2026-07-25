/// EPUB 正文中与图片关联的完整书籍内容及图片位置。
class ImageContext {
  final String chapterTitle;
  final int chapterOrder;
  final String content;
  final int imageOffset;

  const ImageContext({
    required this.chapterTitle,
    required this.chapterOrder,
    required this.content,
    required this.imageOffset,
  });

  /// 纯图片页不会生成上下文，因此不应显示说明面板。
  bool get hasContent => content.trim().isNotEmpty;

  int get _safeImageOffset => imageOffset.clamp(0, content.length);

  /// 图片出现位置之前的完整正文。
  String get textBeforeImage =>
      content.substring(0, _safeImageOffset).trimRight();

  /// 图片出现位置之后的完整正文。
  String get textAfterImage => content.substring(_safeImageOffset).trimLeft();
}
