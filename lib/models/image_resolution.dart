class ImageResolution {
  final int width;
  final int height;

  const ImageResolution({required this.width, required this.height});

  /// 获取宽高比
  double get aspectRatio => height > 0 ? width / height : 1.0;

  @override
  String toString() {
    return '${width}x$height';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ImageResolution &&
        other.width == width &&
        other.height == height;
  }

  @override
  int get hashCode {
    return width.hashCode ^ height.hashCode;
  }
}

/// 分辨率统计信息
class ResolutionStatistics {
  final Map<ImageResolution, int> resolutionCounts;
  final ImageResolution? mostCommonResolution;
  final int mostCommonResolutionCount;
  final int maxWidth; // 所有图片中的最大宽度
  final int maxHeight; // 所有图片中的最大高度

  const ResolutionStatistics({
    required this.resolutionCounts,
    this.mostCommonResolution,
    required this.mostCommonResolutionCount,
    required this.maxWidth,
    required this.maxHeight,
  });

  /// 根据所有图片的最大宽度和高度计算推荐的窗口尺寸
  ImageResolution get recommendedWindowSize {
    // 直接使用最大宽度和最大高度
    return ImageResolution(width: maxWidth, height: maxHeight);
  }

  @override
  String toString() {
    return 'ResolutionStatistics(mostCommon: $mostCommonResolution, count: $mostCommonResolutionCount, maxSize: ${maxWidth}x$maxHeight, total: ${resolutionCounts.length})';
  }
}
