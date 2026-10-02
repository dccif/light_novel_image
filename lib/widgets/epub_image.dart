import 'dart:typed_data';

import 'package:extended_image/extended_image.dart';
import 'package:fluent_ui/fluent_ui.dart';

import '../models/image_entry.dart';
import '../services/image_data_cache.dart';

class EpubImage extends StatefulWidget {
  final ImageEntry image;
  final ImageDataCache cache;
  final int? thumbnailPixels;
  const EpubImage({
    super.key,
    required this.image,
    required this.cache,
    this.thumbnailPixels,
  });

  static ExtendedImage buildImage(
    Uint8List bytes,
    ImageEntry image, {
    int? thumbnailPixels,
  }) {
    // cover 使用短边目标，另一边由解码器按原始比例计算。
    final portrait = image.resolution.width < image.resolution.height;
    return ExtendedImage.memory(
      bytes,
      cacheWidth: thumbnailPixels != null && portrait
          ? thumbnailPixels.clamp(1, image.resolution.width)
          : null,
      cacheHeight: thumbnailPixels != null && !portrait
          ? thumbnailPixels.clamp(1, image.resolution.height)
          : null,
      fit: thumbnailPixels == null ? BoxFit.contain : BoxFit.cover,
      mode: thumbnailPixels == null
          ? ExtendedImageMode.gesture
          : ExtendedImageMode.none,
      clearMemoryCacheWhenDispose: thumbnailPixels != null,
      initGestureConfigHandler: (_) => GestureConfig(
        minScale: 0.8,
        maxScale: 5,
        animationMinScale: 0.8,
        animationMaxScale: 5,
        inPageView: true,
      ),
      loadStateChanged: (state) => switch (state.extendedImageLoadState) {
        LoadState.loading => const Center(child: ProgressRing()),
        LoadState.failed => const Center(
          child: Icon(FluentIcons.error, size: 24),
        ),
        LoadState.completed => null,
      },
    );
  }

  @override
  State<EpubImage> createState() => _EpubImageState();
}

class _EpubImageState extends State<EpubImage> {
  late Future<Uint8List> _bytes;
  @override
  void initState() {
    super.initState();
    _bytes = widget.cache.read(widget.image);
  }

  @override
  void didUpdateWidget(EpubImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image.id != widget.image.id ||
        oldWidget.cache != widget.cache) {
      _bytes = widget.cache.read(widget.image);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: _bytes,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Center(child: Icon(FluentIcons.error));
      }
      if (!snapshot.hasData) return const Center(child: ProgressRing());
      return EpubImage.buildImage(
        snapshot.data!,
        widget.image,
        thumbnailPixels: widget.thumbnailPixels,
      );
    },
  );
}
