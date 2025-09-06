import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:extended_image/extended_image.dart';

class ImageGridWidget extends StatefulWidget {
  final List<Uint8List> images;
  final List<String> imageNames;
  final Function(int) onImageTap;
  final ScrollController? scrollController;
  final int? highlightedIndex; // 高亮显示的图片索引
  final Function(double)? onRowHeightCalculated; // 行高计算完成回调
  final bool shouldCalculateRowHeight; // 是否应该计算行高

  const ImageGridWidget({
    super.key,
    required this.images,
    required this.imageNames,
    required this.onImageTap,
    this.scrollController,
    this.highlightedIndex,
    this.onRowHeightCalculated,
    this.shouldCalculateRowHeight = false,
  });

  @override
  State<ImageGridWidget> createState() => _ImageGridWidgetState();
}

class _ImageGridWidgetState extends State<ImageGridWidget> {
  final GlobalKey _gridKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // 只有在被明确要求时才计算行高
    if (widget.shouldCalculateRowHeight) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _calculateAndReportRowHeight();
      });
    }
  }

  @override
  void didUpdateWidget(ImageGridWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 如果shouldCalculateRowHeight从false变为true，触发行高计算
    if (!oldWidget.shouldCalculateRowHeight &&
        widget.shouldCalculateRowHeight) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _calculateAndReportRowHeight();
      });
    }
  }

  /// 计算并报告实际的行高
  void _calculateAndReportRowHeight() {
    try {
      final RenderBox? renderBox =
          _gridKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null && widget.scrollController?.hasClients == true) {
        final ScrollPosition position = widget.scrollController!.position;

        // 获取总的可滚动内容高度
        final double maxScrollExtent = position.maxScrollExtent;
        final double viewportHeight = position.viewportDimension;
        final double totalContentHeight = maxScrollExtent + viewportHeight;

        const int itemsPerRow = 3;
        final int totalRows =
            (widget.images.length + itemsPerRow - 1) ~/ itemsPerRow;

        if (totalRows > 0) {
          // 计算平均行高（减去padding）
          const double padding = 16.0; // 上下padding总和
          final double contentHeight = totalContentHeight - padding;
          final double averageRowHeight = contentHeight / totalRows;

          debugPrint(
            'GridWidget计算行高: $averageRowHeight (总高度: $totalContentHeight, 行数: $totalRows)',
          );

          // 通过回调报告计算的行高
          widget.onRowHeightCalculated?.call(averageRowHeight);
        }
      }
    } catch (e) {
      debugPrint('GridWidget计算行高失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: _gridKey,
      decoration: BoxDecoration(
        color: FluentTheme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: GridView.builder(
          controller: widget.scrollController,
          padding: const EdgeInsets.all(8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemCount: widget.images.length,
          itemBuilder: (context, index) {
            return _buildImageTile(context, index);
          },
        ),
      ),
    );
  }

  Widget _buildImageTile(BuildContext context, int imageIndex) {
    final bool isHighlighted = widget.highlightedIndex == imageIndex;

    return GestureDetector(
      onTap: () => widget.onImageTap(imageIndex),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isHighlighted
                ? FluentTheme.of(context).accentColor
                : Colors.grey.withValues(alpha: 0.2),
            width: isHighlighted ? 3.0 : 1.0,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ExtendedImage.memory(
                widget.images[imageIndex],
                fit: BoxFit.cover,
                loadStateChanged: (state) {
                  switch (state.extendedImageLoadState) {
                    case LoadState.loading:
                      return const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: ProgressRing(),
                        ),
                      );
                    case LoadState.completed:
                      return null;
                    case LoadState.failed:
                      return const Center(
                        child: Icon(FluentIcons.error, size: 24),
                      );
                  }
                },
              ),
              // 添加悬停效果
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.0),
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.0),
                    ),
                  ),
                ),
              ),
              // 图片信息显示
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Text(
                    widget.imageNames[imageIndex],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
