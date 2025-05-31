class BookInfo {
  final String title;
  final String filePath;
  final int startImageIndex;
  final int endImageIndex;

  const BookInfo({
    required this.title,
    required this.filePath,
    required this.startImageIndex,
    required this.endImageIndex,
  });

  @override
  String toString() {
    return 'BookInfo(title: $title, filePath: $filePath, startImageIndex: $startImageIndex, endImageIndex: $endImageIndex)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BookInfo &&
        other.title == title &&
        other.filePath == filePath &&
        other.startImageIndex == startImageIndex &&
        other.endImageIndex == endImageIndex;
  }

  @override
  int get hashCode {
    return title.hashCode ^
        filePath.hashCode ^
        startImageIndex.hashCode ^
        endImageIndex.hashCode;
  }
}
