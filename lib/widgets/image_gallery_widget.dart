import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:extended_image/extended_image.dart';
import 'package:light_novel_image/services/system_viewer_service.dart';

class ImageGalleryWidget extends StatefulWidget {
  final List<Uint8List> images;
  final List<String> imageNames;
  final int initialIndex;
  final VoidCallback? onEscape;
  final String? bookIdentifier;
  final Function(int)? onIndexChanged; // 新增：索引变化回调

  const ImageGalleryWidget({
    super.key,
    required this.images,
    required this.imageNames,
    required this.initialIndex,
    this.onEscape,
    this.bookIdentifier,
    this.onIndexChanged,
  });

  @override
  State<ImageGalleryWidget> createState() => _ImageGalleryWidgetState();
}

class _ImageGalleryWidgetState extends State<ImageGalleryWidget> {
  late ExtendedPageController _pageController;
  late int _currentIndex;
  final Set<int> _preloadedImages = <int>{};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = ExtendedPageController(initialPage: _currentIndex);
    // 预加载当前图片和前后一张图片
    _preloadImages(_currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// 预加载当前图片和前后一张图片
  void _preloadImages(int currentIndex) {
    // 预加载当前图片
    if (currentIndex >= 0 && currentIndex < widget.images.length) {
      _preloadImage(currentIndex);
    }

    // 预加载前一张图片
    if (currentIndex - 1 >= 0) {
      _preloadImage(currentIndex - 1);
    }

    // 预加载后一张图片
    if (currentIndex + 1 < widget.images.length) {
      _preloadImage(currentIndex + 1);
    }
  }

  /// 预加载单张图片
  void _preloadImage(int index) {
    if (_preloadedImages.contains(index)) return;

    _preloadedImages.add(index);

    // 在后台预创建ExtendedImage widget来触发预加载
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // 创建一个不可见的ExtendedImage来预加载
      final preloadWidget = ExtendedImage.memory(
        widget.images[index],
        fit: BoxFit.contain,
        mode: ExtendedImageMode.gesture,
        width: 1,
        height: 1,
        loadStateChanged: (state) {
          if (state.extendedImageLoadState == LoadState.completed) {
            debugPrint('预加载图片完成: ${widget.imageNames[index]}');
          }
          return null;
        },
      );

      // 触发图片加载
      precacheImage(preloadWidget.image, context);
    });
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    // 当页面改变时，预加载新的前后图片
    _preloadImages(index);

    // 通知外部索引变化
    widget.onIndexChanged?.call(index);
  }

  void _previousImage() {
    if (_currentIndex > 0) {
      _currentIndex--;
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      // 通知外部索引变化
      widget.onIndexChanged?.call(_currentIndex);
    }
  }

  void _nextImage() {
    if (_currentIndex < widget.images.length - 1) {
      _currentIndex++;
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      // 通知外部索引变化
      widget.onIndexChanged?.call(_currentIndex);
    }
  }

  Future<void> _openInSystemViewer() async {
    if (_currentIndex >= widget.images.length) return;

    await SystemViewerService.openImageInSystemViewer(
      widget.images[_currentIndex],
      widget.imageNames[_currentIndex],
      widget.bookIdentifier,
    );
  }

  /// 复制当前图片到剪贴板
  Future<void> _copyToClipboard(String imageName) async {
    if (_currentIndex >= widget.images.length) return;

    try {
      await SystemViewerService.copyFileToClipboard(
        widget.images[_currentIndex],
        imageName,
        widget.bookIdentifier,
      );

      // 显示成功提示
      if (mounted) {
        displayInfoBar(
          context,
          builder: (context, close) {
            return InfoBar(
              title: const Text('成功'),
              content: Text('图片 "$imageName" 已复制到剪贴板'),
              severity: InfoBarSeverity.success,
              action: IconButton(
                icon: const Icon(FluentIcons.clear),
                onPressed: close,
              ),
            );
          },
        );
      }
    } catch (e) {
      // 显示错误提示
      if (mounted) {
        displayInfoBar(
          context,
          builder: (context, close) {
            return InfoBar(
              title: const Text('复制失败'),
              content: Text('无法复制图片到剪贴板: $e'),
              severity: InfoBarSeverity.error,
              action: IconButton(
                icon: const Icon(FluentIcons.clear),
                onPressed: close,
              ),
            );
          },
        );
      }
    }
  }

  /// 显示选择打开方式对话框
  Future<void> _openWithDialog(String imageName) async {
    if (_currentIndex >= widget.images.length) return;

    try {
      await SystemViewerService.openImageWithDialog(
        widget.images[_currentIndex],
        imageName,
        widget.bookIdentifier,
      );
    } catch (e) {
      // 显示错误提示
      if (mounted) {
        displayInfoBar(
          context,
          builder: (context, close) {
            return InfoBar(
              title: const Text('打开失败'),
              content: Text('无法打开选择应用程序对话框: $e'),
              severity: InfoBarSeverity.error,
              action: IconButton(
                icon: const Icon(FluentIcons.clear),
                onPressed: close,
              ),
            );
          },
        );
      }
    }
  }

  List<MenuFlyoutItemBase> _buildContextMenuItems() {
    final String currentImageName = widget.imageNames[_currentIndex];

    return [
      MenuFlyoutItem(
        leading: const Icon(FluentIcons.copy, size: 16),
        text: const Text('复制文件到剪贴板'),
        onPressed: () => _copyToClipboard(currentImageName),
      ),
      const MenuFlyoutSeparator(),
      MenuFlyoutSubItem(
        text: const Text('打开方式'),
        leading: const Icon(FluentIcons.open_with, size: 16),
        items: (context) => [
          MenuFlyoutItem(
            leading: const Icon(FluentIcons.view, size: 16),
            text: const Text('系统默认查看器'),
            onPressed: () => _openInSystemViewer(),
          ),
          MenuFlyoutItem(
            leading: const Icon(FluentIcons.open_with, size: 16),
            text: const Text('选择其他应用...'),
            onPressed: () => _openWithDialog(currentImageName),
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
              if (event.logicalKey == LogicalKeyboardKey.escape) {
                widget.onEscape?.call();
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.enter) {
                _openInSystemViewer();
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                _previousImage();
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                _nextImage();
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: FlyoutTarget(
            controller: flyoutController,
            child: Listener(
              onPointerSignal: (pointerSignal) {
                if (pointerSignal is PointerScrollEvent) {
                  // 只处理垂直滚动，忽略水平滚动
                  final verticalDelta = pointerSignal.scrollDelta.dy;
                  if (verticalDelta.abs() > 10) {
                    // 添加阈值避免误触
                    if (verticalDelta > 0) {
                      _nextImage();
                    } else {
                      _previousImage();
                    }
                  }
                }
              },
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
                child: ExtendedImageGesturePageView.builder(
                  controller: _pageController,
                  itemCount: widget.images.length,
                  onPageChanged: _onPageChanged,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemBuilder: (BuildContext context, int index) {
                    return ExtendedImage.memory(
                      widget.images[index],
                      fit: BoxFit.contain,
                      mode: ExtendedImageMode.gesture,
                      initGestureConfigHandler: (ExtendedImageState state) {
                        return GestureConfig(
                          // 禁用缩放功能 - 最小和最大缩放都设为1.0
                          minScale: 1.0,
                          animationMinScale: 1.0,
                          maxScale: 1.0,
                          animationMaxScale: 1.0,
                          speed: 1.0,
                          inertialSpeed: 100.0,
                          initialScale: 1.0,
                          inPageView: true,
                          initialAlignment: InitialAlignment.center,
                          // 禁用所有手势交互，只保留PageView的滑动
                          gestureDetailsIsChanged: null,
                        );
                      },
                      loadStateChanged: (ExtendedImageState state) {
                        switch (state.extendedImageLoadState) {
                          case LoadState.loading:
                            return const Center(child: ProgressRing());
                          case LoadState.completed:
                            return null;
                          case LoadState.failed:
                            return const Center(
                              child: Icon(FluentIcons.error, size: 48),
                            );
                        }
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
