/// EPUB 正文中与图片关联的完整书籍内容及图片位置。
class ImageContext {
  final String chapterTitle;
  final int chapterOrder;
  final String content;
  final int imageOffset;
  final BookText? document;

  const ImageContext({
    required this.chapterTitle,
    required this.chapterOrder,
    required this.content,
    required this.imageOffset,
    this.document,
  });

  /// 纯图片页不会生成上下文，因此不应显示说明面板。
  bool get hasContent => content.isNotEmpty;

  int get _safeImageOffset => imageOffset.clamp(0, content.length);

  /// 图片出现位置之前的完整正文。
  String get textBeforeImage =>
      content.substring(0, _safeImageOffset).trimRight();

  /// 图片出现位置之后的完整正文。
  String get textAfterImage => content.substring(_safeImageOffset).trimLeft();
}

/// 所有图片共享正文和段落索引。只在布局可见段落时创建小段 substring。
class BookText {
  final String content;
  final List<int> starts;
  final List<int> ends;

  BookText(this.content) : starts = [], ends = [] {
    for (final match in RegExp(r'[^\n]+').allMatches(content)) {
      var start = match.start;
      while (start < match.end) {
        var end = (start + 2048).clamp(start, match.end);
        if (end < match.end &&
            content.codeUnitAt(end - 1) >= 0xD800 &&
            content.codeUnitAt(end - 1) <= 0xDBFF) {
          end--;
        }
        starts.add(start);
        ends.add(end);
        start = end;
      }
    }
  }

  int get length => starts.length;
  String paragraph(int index) => content.substring(starts[index], ends[index]);

  int paragraphAt(int offset) {
    if (starts.isEmpty) return 0;
    var low = 0;
    var high = starts.length;
    while (low < high) {
      final mid = (low + high) ~/ 2;
      if (ends[mid] < offset) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low.clamp(0, starts.length - 1);
  }
}
