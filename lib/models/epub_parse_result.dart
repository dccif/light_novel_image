import 'book_info.dart';
import 'image_entry.dart';
import 'image_resolution.dart';

class EpubImportRequest {
  final List<String> paths;
  final String cacheDirectory;
  final int memoryBudget;

  const EpubImportRequest(
    this.paths,
    this.cacheDirectory, {
    this.memoryBudget = 16 * 1024 * 1024,
  });
}

class EpubParseResult {
  final List<BookInfo> books;
  final List<ImageEntry> images;
  final ResolutionStatistics resolutionStatistics; // 分辨率统计信息

  const EpubParseResult({
    required this.books,
    required this.images,
    required this.resolutionStatistics,
  });

  @override
  String toString() {
    return 'EpubParseResult(books: ${books.length}, images: ${images.length})';
  }
}
