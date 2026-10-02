import 'package:flutter_test/flutter_test.dart';
import 'package:light_novel_image/utils/grid_metrics.dart';

void main() {
  test('几何来自实际宽度，短网格不会把视口误计为行高', () {
    const metrics = GridMetrics(332);
    expect(metrics.cellSize, 100);
    expect(metrics.rowStride, 108);
    expect(metrics.centeredOffset(0, 600, 0), 0);
    expect(metrics.centeredOffset(15, 200, 1000), 498);
    expect(const GridMetrics(632).cellSize, 200);
  });
}
