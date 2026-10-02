import 'dart:typed_data';

import 'image_context.dart';
import 'image_resolution.dart';

/// 图片的元数据与存储位置，避免多个平行数组产生错位。
class ImageEntry {
  final String id;
  final String archivePath;
  final String name;
  final int bookIndex;
  final ImageResolution resolution;
  final ImageContext? context;
  final Uint8List? bytes;
  final String? filePath;

  const ImageEntry({
    required this.id,
    required this.archivePath,
    required this.name,
    required this.bookIndex,
    required this.resolution,
    this.context,
    this.bytes,
    this.filePath,
  }) : assert((bytes == null) != (filePath == null));

  int get area => resolution.width * resolution.height;
}
