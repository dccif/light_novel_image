class GridMetrics {
  static const columns = 3;
  static const padding = 8.0;
  static const spacing = 8.0;
  final double width;
  const GridMetrics(this.width);

  double get cellSize =>
      ((width - 2 * padding - (columns - 1) * spacing) / columns).clamp(
        1,
        double.infinity,
      );
  double get rowStride => cellSize + spacing;
  double centeredOffset(int index, double viewportHeight, double maxExtent) =>
      (padding +
              (index ~/ columns) * rowStride +
              cellSize / 2 -
              viewportHeight / 2)
          .clamp(0, maxExtent);
}
