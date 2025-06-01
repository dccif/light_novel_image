import 'package:flutter/foundation.dart';
import 'package:image_size_getter/image_size_getter.dart';
import 'package:light_novel_image/models/image_resolution.dart';

class ImageResolutionService {
  /// 使用 image_size_getter 获取图片分辨率（只读取元数据，不解码图片）
  static ImageResolution getImageResolution(Uint8List imageData) {
    try {
      final memoryInput = MemoryInput(imageData);
      final sizeResult = ImageSizeGetter.getSizeResult(memoryInput);
      final size = sizeResult.size;

      // 检查是否需要根据 EXIF 方向旋转
      final ImageResolution resolution;
      if (size.needRotate) {
        // 当需要旋转时，宽度和高度需要交换
        resolution = ImageResolution(width: size.height, height: size.width);
      } else {
        resolution = ImageResolution(width: size.width, height: size.height);
      }

      debugPrint(
        '获取图片分辨率: ${resolution.width}x${resolution.height} '
        '(解码器: ${sizeResult.decoder.decoderName}${size.needRotate ? ', 已旋转' : ''})',
      );

      return resolution;
    } catch (e) {
      debugPrint('获取图片分辨率失败: $e');
      // 返回默认分辨率
      return const ImageResolution(width: 800, height: 600);
    }
  }

  /// 批量获取图片分辨率（可以在后台线程中运行）
  static List<ImageResolution> getImageResolutions(List<Uint8List> images) {
    final resolutions = <ImageResolution>[];

    debugPrint('开始分析 ${images.length} 张图片的分辨率...');

    for (int i = 0; i < images.length; i++) {
      final resolution = getImageResolution(images[i]);
      resolutions.add(resolution);

      // 显示进度
      if ((i + 1) % 10 == 0 || i == images.length - 1) {
        debugPrint(
          '已处理 ${i + 1}/${images.length} 张图片的分辨率 '
          '(${((i + 1) / images.length * 100).toStringAsFixed(1)}%)',
        );
      }
    }

    debugPrint('分辨率分析完成！');
    return resolutions;
  }

  /// 异步批量获取图片分辨率（可以在隔离线程中运行）
  static Future<List<ImageResolution>> getImageResolutionsAsync(
    List<Uint8List> images,
  ) async {
    return compute(_getImageResolutionsInIsolate, images);
  }

  /// 在隔离线程中运行的静态函数
  static List<ImageResolution> _getImageResolutionsInIsolate(
    List<Uint8List> images,
  ) {
    return getImageResolutions(images);
  }
}
