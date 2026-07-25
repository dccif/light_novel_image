import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:extended_image/extended_image.dart';
import 'package:light_novel_image/models/image_context.dart';
import 'package:light_novel_image/services/system_viewer_service.dart';
import 'package:light_novel_image/utils/scroll_visibility.dart';

class ImageGalleryWidget extends StatefulWidget {
  final List<Uint8List> images;
  final List<String> imageNames;
  final List<ImageContext?> imageContexts;
  final int initialIndex;
  final VoidCallback? onEscape;
  final String? bookIdentifier;
  final Function(int)? onIndexChanged; // 新增：索引变化回调

  const ImageGalleryWidget({
    super.key,
    required this.images,
    required this.imageNames,
    required this.imageContexts,
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
  final ScrollController _contextScrollController = ScrollController();
  final GlobalKey _imageMarkerKey = GlobalKey();
  final GlobalKey _contextViewportKey = GlobalKey();
  bool _isImageMarkerOutOfView = false;
  bool _isRestoringImageMarker = false;

  ImageContext? get _currentImageContext {
    if (_currentIndex < 0 || _currentIndex >= widget.imageContexts.length) {
      return null;
    }
    final context = widget.imageContexts[_currentIndex];
    return context?.hasContent ?? false ? context : null;
  }

  // 缓存控制器和焦点节点，避免每次 build 都创建新实例
  late final FlyoutController _flyoutController;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = ExtendedPageController(initialPage: _currentIndex);
    _flyoutController = FlyoutController();
    _focusNode = FocusNode();
    _contextScrollController.addListener(_updateImageMarkerVisibility);
    // 预加载当前图片和前后一张图片
    _preloadImages(_currentIndex);
    _scrollContextToImageMarker();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _contextScrollController.removeListener(_updateImageMarkerVisibility);
    _contextScrollController.dispose();
    _focusNode.dispose();
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
      _isImageMarkerOutOfView = false;
      _isRestoringImageMarker = true;
    });
    // 当页面改变时，预加载新的前后图片
    _preloadImages(index);
    _scrollContextToImageMarker();

    // 通知外部索引变化
    widget.onIndexChanged?.call(index);
  }

  void _scrollContextToImageMarker() {
    if (mounted) {
      setState(() {
        _isRestoringImageMarker = true;
        _isImageMarkerOutOfView = false;
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final markerContext = _imageMarkerKey.currentContext;
      if (!mounted || markerContext == null) {
        _finishImageMarkerRestoration();
        return;
      }
      Scrollable.ensureVisible(
        markerContext,
        duration: const Duration(milliseconds: 180),
        alignment: 0.35,
        curve: Curves.easeOut,
      ).whenComplete(_finishImageMarkerRestoration);
    });
  }

  void _finishImageMarkerRestoration() {
    if (!mounted) return;
    _isRestoringImageMarker = false;
    _updateImageMarkerVisibility();
  }

  void _updateImageMarkerVisibility() {
    if (!mounted || _isRestoringImageMarker) return;
    final marker = _imageMarkerKey.currentContext?.findRenderObject();
    final viewport = _contextViewportKey.currentContext?.findRenderObject();
    if (marker is! RenderBox || viewport is! RenderBox) {
      if (_isImageMarkerOutOfView) {
        setState(() => _isImageMarkerOutOfView = false);
      }
      return;
    }

    final markerTop = marker.localToGlobal(Offset.zero).dy;
    final markerBottom = markerTop + marker.size.height;
    final viewportTop = viewport.localToGlobal(Offset.zero).dy;
    final viewportBottom = viewportTop + viewport.size.height;
    final isOutOfView = !ScrollVisibility.isFullyVisible(
      itemTop: markerTop,
      itemBottom: markerBottom,
      viewportTop: viewportTop,
      viewportBottom: viewportBottom,
    );
    if (_isImageMarkerOutOfView != isOutOfView) {
      setState(() => _isImageMarkerOutOfView = isOutOfView);
    }
  }

  KeyEventResult _handleGalleryKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      widget.onEscape?.call();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      _openInSystemViewer();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _previousImage();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _nextImage();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _previousImage() {
    if (_currentIndex > 0) {
      _currentIndex--;
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 80),
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
        duration: const Duration(milliseconds: 80),
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

  /// 构建手势配置（缓存以避免重复创建）
  static GestureConfig _buildGestureConfig(ExtendedImageState state) {
    return GestureConfig(
      // 启用缩放功能
      minScale: 0.8,
      animationMinScale: 0.8,
      maxScale: 5.0,
      animationMaxScale: 5.0,
      speed: 1.0,
      inertialSpeed: 100.0,
      initialScale: 1.0,
      inPageView: true,
      initialAlignment: InitialAlignment.center,
    );
  }

  /// 构建加载状态组件（使用 const 优化）
  static Widget? _buildLoadStateWidget(ExtendedImageState state) {
    switch (state.extendedImageLoadState) {
      case LoadState.loading:
        return const Center(child: ProgressRing());
      case LoadState.completed:
        return null;
      case LoadState.failed:
        return const Center(child: Icon(FluentIcons.error, size: 48));
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
            onPressed: _openInSystemViewer,
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

  Widget _buildImageContextPanel(ImageContext imageContext) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FluentTheme.of(context).micaBackgroundColor,
        border: Border(
          left: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(FluentIcons.info, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '图片上下文',
                    style: FluentTheme.of(context).typography.subtitle,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '第 ${imageContext.chapterOrder} 节 · ${imageContext.chapterTitle}',
                style: FluentTheme.of(context).typography.caption,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  key: _contextViewportKey,
                  controller: _contextScrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (imageContext.textBeforeImage.isNotEmpty)
                        SelectableText(
                          imageContext.textBeforeImage,
                          style: FluentTheme.of(context).typography.body,
                        ),
                      if (imageContext.textBeforeImage.isNotEmpty)
                        const SizedBox(height: 16),
                      Container(
                        key: _imageMarkerKey,
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: FluentTheme.of(
                            context,
                          ).accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: FluentTheme.of(
                              context,
                            ).accentColor.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              FluentIcons.photo2,
                              size: 14,
                              color: FluentTheme.of(context).accentColor,
                            ),
                            const SizedBox(width: 8),
                            const Text('图片原文位置'),
                          ],
                        ),
                      ),
                      if (imageContext.textAfterImage.isNotEmpty)
                        const SizedBox(height: 16),
                      if (imageContext.textAfterImage.isNotEmpty)
                        SelectableText(
                          imageContext.textAfterImage,
                          style: FluentTheme.of(context).typography.body,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_isImageMarkerOutOfView)
            Positioned(
              right: 12,
              bottom: 12,
              child: Tooltip(
                message: '回到图片原文位置',
                child: Container(
                  decoration: BoxDecoration(
                    color: FluentTheme.of(context).accentColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(FluentIcons.photo2, color: Colors.white),
                    onPressed: _scrollContextToImageMarker,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: FluentTheme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
      ),
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        descendantsAreFocusable: false,
        onKeyEvent: _handleGalleryKeyEvent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Row(
            children: [
              Expanded(
                child: FlyoutTarget(
                  controller: _flyoutController,
                  child: Listener(
                    onPointerSignal: (pointerSignal) {
                      if (pointerSignal is PointerScrollEvent) {
                        // 直接检测 Ctrl 键状态，避免状态管理
                        final isCtrlPressed =
                            HardwareKeyboard.instance.isControlPressed;

                        // 如果按住了 Ctrl 键，让 ExtendedImage 处理缩放
                        if (isCtrlPressed) {
                          // 不处理滚轮事件，让 ExtendedImage 的缩放功能接管
                          return;
                        }

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

                        _flyoutController.showFlyout(
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
                            initGestureConfigHandler: _buildGestureConfig,
                            loadStateChanged: _buildLoadStateWidget,
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              if (_currentImageContext != null)
                _buildImageContextPanel(_currentImageContext!),
            ],
          ),
        ),
      ),
    );
  }
}
