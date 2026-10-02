import 'dart:io';
import 'dart:typed_data';

import 'package:image_size_getter/file_input.dart';
import 'package:image_size_getter/image_size_getter.dart';
import 'package:light_novel_image/models/image_resolution.dart';

class ImageResolutionService {
  /// 使用 image_size_getter 获取图片分辨率（只读取元数据，不解码图片）
  static ImageResolution getImageResolution(Uint8List imageData) {
    return _getResolution(MemoryInput(imageData));
  }

  static ImageResolution getFileResolution(File file) =>
      _getResolution(FileInput(file));

  static ImageResolution _getResolution(ImageInput input) {
    try {
      final sizeResult = ImageSizeGetter.getSizeResult(input);
      final size = sizeResult.size;

      // 检查是否需要根据 EXIF 方向旋转
      final ImageResolution resolution;
      if (size.needRotate) {
        // 当需要旋转时，宽度和高度需要交换
        resolution = ImageResolution(width: size.height, height: size.width);
      } else {
        resolution = ImageResolution(width: size.width, height: size.height);
      }

      return resolution;
    } catch (e) {
      // 返回默认分辨率
      return const ImageResolution(width: 800, height: 600);
    }
  }
}
