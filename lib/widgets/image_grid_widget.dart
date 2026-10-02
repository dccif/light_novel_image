import 'package:fluent_ui/fluent_ui.dart';

import '../models/image_entry.dart';
import '../services/image_data_cache.dart';
import '../utils/grid_metrics.dart';
import 'epub_image.dart';

class ImageGridWidget extends StatelessWidget {
  final List<ImageEntry> images;
  final ImageDataCache cache;
  final ValueChanged<int> onImageTap;
  final ScrollController scrollController;
  final int highlightedIndex;
  final ValueChanged<GridMetrics> onMetricsChanged;

  const ImageGridWidget({
    super.key,
    required this.images,
    required this.cache,
    required this.onImageTap,
    required this.scrollController,
    required this.highlightedIndex,
    required this.onMetricsChanged,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final metrics = GridMetrics(constraints.maxWidth);
      final pixels = (metrics.cellSize * MediaQuery.devicePixelRatioOf(context))
          .ceil();
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => onMetricsChanged(metrics),
      );
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: GridView.builder(
          controller: scrollController,
          padding: const EdgeInsets.all(GridMetrics.padding),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: GridMetrics.columns,
            crossAxisSpacing: GridMetrics.spacing,
            mainAxisSpacing: GridMetrics.spacing,
          ),
          itemCount: images.length,
          itemBuilder: (context, index) {
            final image = images[index];
            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => onImageTap(index),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: index == highlightedIndex
                          ? FluentTheme.of(context).accentColor
                          : Colors.grey.withValues(alpha: 0.2),
                      width: index == highlightedIndex ? 3 : 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        EpubImage(
                          key: ValueKey(image.id),
                          image: image,
                          cache: cache,
                          thumbnailPixels: pixels,
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.6),
                            padding: const EdgeInsets.all(4),
                            child: Text(
                              image.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    },
  );
}
