import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

class ImageGalleryWidget extends StatelessWidget {
  final List<Uint8List> images;
  final List<String> imageNames;
  final PageController pageController;
  final int currentIndex;
  final Function(int) onPageChanged;
  final VoidCallback onOpenInSystemViewer;
  final VoidCallback onPreviousImage;
  final VoidCallback onNextImage;
  final Function(String) onCopyToClipboard;
  final Function(String) onOpenWithDialog;

  const ImageGalleryWidget({
    super.key,
    required this.images,
    required this.imageNames,
    required this.pageController,
    required this.currentIndex,
    required this.onPageChanged,
    required this.onOpenInSystemViewer,
    required this.onPreviousImage,
    required this.onNextImage,
    required this.onCopyToClipboard,
    required this.onOpenWithDialog,
  });

  List<MenuFlyoutItemBase> _buildContextMenuItems() {
    final String currentImageName = imageNames[currentIndex];

    return [
      MenuFlyoutItem(
        leading: const Icon(FluentIcons.copy, size: 16),
        text: const Text('复制文件到剪贴板'),
        onPressed: () => onCopyToClipboard(currentImageName),
      ),
      const MenuFlyoutSeparator(),
      MenuFlyoutSubItem(
        text: const Text('打开方式'),
        leading: const Icon(FluentIcons.open_with, size: 16),
        items: (context) => [
          MenuFlyoutItem(
            leading: const Icon(FluentIcons.view, size: 16),
            text: const Text('系统默认查看器'),
            onPressed: () => onOpenInSystemViewer(),
          ),
          MenuFlyoutItem(
            leading: const Icon(FluentIcons.open_with, size: 16),
            text: const Text('选择其他应用...'),
            onPressed: () => onOpenWithDialog(currentImageName),
          ),
        ],
      ),
      const MenuFlyoutSeparator(),
      MenuFlyoutItem(
        leading: const Icon(FluentIcons.info, size: 16),
        text: Text('图片: $currentImageName'),
        onPressed: null, // 禁用状态，仅显示信息
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final flyoutController = FlyoutController();

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
          child: FlyoutTarget(
            controller: flyoutController,
            child: GestureDetector(
              onSecondaryTapDown: (details) {
                // 显示 Fluent UI 右键菜单
                Offset position = details.localPosition;
                position = Offset(position.dx + 20, position.dy + 70);

                flyoutController.showFlyout(
                  position: position,
                  builder: (context) {
                    return MenuFlyout(items: _buildContextMenuItems());
                  },
                );
              },
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
                backgroundDecoration: const BoxDecoration(
                  color: Colors.transparent,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
