import 'package:flutter_test/flutter_test.dart';
import 'package:epub_image/models/image_resolution.dart';
import 'package:epub_image/services/epub_parser_service.dart';

void main() {
  group('分辨率计算测试', () {
    test('应该正确计算最常见分辨率和最大宽度', () {
      // 创建测试数据
      final resolutions = [
        const ImageResolution(width: 800, height: 600), // 4:3
        const ImageResolution(width: 800, height: 600), // 4:3 (最常见)
        const ImageResolution(width: 1200, height: 800), // 3:2 (最宽)
        const ImageResolution(width: 1024, height: 768), // 4:3
        const ImageResolution(width: 800, height: 1200), // 最高
      ];

      final statistics = EpubParserService.calculateResolutionStatistics(
        resolutions,
      );

      // 验证最常见分辨率
      expect(
        statistics.mostCommonResolution,
        const ImageResolution(width: 800, height: 600),
      );
      expect(statistics.mostCommonResolutionCount, 2);

      // 验证最大宽度和高度
      expect(statistics.maxWidth, 1200);
      expect(statistics.maxHeight, 1200);

      // 验证推荐窗口尺寸（现在直接使用最大宽度和高度）
      final recommended = statistics.recommendedWindowSize;
      expect(recommended.width, 1200); // 直接使用最大宽度
      expect(recommended.height, 1200); // 直接使用最大高度
    });

    test('应该正确处理空列表', () {
      final statistics = EpubParserService.calculateResolutionStatistics([]);

      expect(statistics.mostCommonResolution, isNull);
      expect(statistics.mostCommonResolutionCount, 0);
      expect(statistics.maxWidth, 800); // 默认值
      expect(statistics.maxHeight, 600); // 默认值

      // 验证推荐窗口尺寸使用默认值
      final recommended = statistics.recommendedWindowSize;
      expect(recommended.width, 800);
      expect(recommended.height, 600);
    });

    test('宽高比计算应该正确', () {
      const resolution = ImageResolution(width: 800, height: 600);
      expect(resolution.aspectRatio, closeTo(800 / 600, 0.001));

      const squareResolution = ImageResolution(width: 500, height: 500);
      expect(squareResolution.aspectRatio, 1.0);
    });
  });
}
