import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

class ImageGalleryWidget extends StatelessWidget {
  final List<Uint8List> images;
  final PageController pageController;
  final int currentIndex;
  final Function(int) onPageChanged;
  final VoidCallback onOpenInSystemViewer;
  final VoidCallback onPreviousImage;
  final VoidCallback onNextImage;

  const ImageGalleryWidget({
    super.key,
    required this.images,
    required this.pageController,
    required this.currentIndex,
    required this.onPageChanged,
    required this.onOpenInSystemViewer,
    required this.onPreviousImage,
    required this.onNextImage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: FluentTheme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent) {
              if (event.logicalKey == LogicalKeyboardKey.enter) {
                onOpenInSystemViewer();
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                onPreviousImage();
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                onNextImage();
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: GestureDetector(
            onDoubleTap: onOpenInSystemViewer,
            child: PhotoViewGallery.builder(
              scrollPhysics: const BouncingScrollPhysics(),
              builder: (BuildContext context, int index) {
                return PhotoViewGalleryPageOptions(
                  imageProvider: MemoryImage(images[index]),
                  initialScale: PhotoViewComputedScale.contained,
                  minScale: PhotoViewComputedScale.contained * 0.1,
                  maxScale: PhotoViewComputedScale.covered * 4.0,
                  heroAttributes: PhotoViewHeroAttributes(tag: index),
                );
              },
              itemCount: images.length,
              loadingBuilder: (context, event) =>
                  const Center(child: ProgressRing()),
              pageController: pageController,
              onPageChanged: onPageChanged,
              backgroundDecoration: BoxDecoration(color: Colors.transparent),
            ),
          ),
        ),
      ),
    );
  }
}
