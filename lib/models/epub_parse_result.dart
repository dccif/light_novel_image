import 'dart:typed_data';
import 'book_info.dart';

class EpubParseResult {
  final List<BookInfo> books;
  final List<Uint8List> allImages;
  final List<String> allImageNames;
  final List<int> imageBookIndexes; // 每张图片属于哪本书

  const EpubParseResult({
    required this.books,
    required this.allImages,
    required this.allImageNames,
    required this.imageBookIndexes,
  });

  @override
  String toString() {
    return 'EpubParseResult(books: ${books.length}, images: ${allImages.length})';
  }
}
