import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:epub_image/models/image_resolution.dart';

class ImageResolutionService {
  /// 获取图片分辨率（必须在主线程中调用）
  static Future<ImageResolution> getImageResolution(Uint8List imageData) async {
    try {
      final codec = await ui.instantiateImageCodec(imageData);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final resolution = ImageResolution(
        width: image.width,
        height: image.height,
      );

      // 释放图像资源
      image.dispose();

      return resolution;
    } catch (e) {
      debugPrint('获取图片分辨率失败: $e');
      // 返回默认分辨率
      return const ImageResolution(width: 800, height: 600);
    }
  }

  /// 批量获取图片分辨率
  static Future<List<ImageResolution>> getImageResolutions(
    List<Uint8List> images,
  ) async {
    final resolutions = <ImageResolution>[];

    debugPrint('开始分析 ${images.length} 张图片的分辨率...');

    for (int i = 0; i < images.length; i++) {
      final resolution = await getImageResolution(images[i]);
      resolutions.add(resolution);

      // 显示进度
      if ((i + 1) % 5 == 0 || i == images.length - 1) {
        debugPrint(
          '已处理 ${i + 1}/${images.length} 张图片的分辨率 (${((i + 1) / images.length * 100).toStringAsFixed(1)}%)',
        );
      }
    }

    debugPrint('分辨率分析完成！');
    return resolutions;
  }
}
