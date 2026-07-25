import 'dart:typed_data';
import 'book_info.dart';
import 'image_context.dart';
import 'image_resolution.dart';

class EpubParseResult {
  final List<BookInfo> books;
  final List<Uint8List> allImages;
  final List<String> allImageNames;
  final List<int> imageBookIndexes; // 每张图片属于哪本书
  final List<ImageContext?> imageContexts; // 与图片索引对齐的正文上下文
  final List<ImageResolution> imageResolutions; // 每张图片的分辨率
  final ResolutionStatistics resolutionStatistics; // 分辨率统计信息

  const EpubParseResult({
    required this.books,
    required this.allImages,
    required this.allImageNames,
    required this.imageBookIndexes,
    required this.imageContexts,
    required this.imageResolutions,
    required this.resolutionStatistics,
  });

  @override
  String toString() {
    return 'EpubParseResult(books: ${books.length}, images: ${allImages.length}, resolutions: ${resolutionStatistics.resolutionCounts.length})';
  }
}
