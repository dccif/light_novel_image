import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:extended_image/extended_image.dart';
import 'package:light_novel_image/models/image_context.dart';
import 'package:light_novel_image/services/system_viewer_service.dart';

import '../models/image_entry.dart';
import '../services/image_data_cache.dart';
import 'epub_image.dart';
import 'image_context_panel.dart';

class ImageGalleryWidget extends StatefulWidget {
  final List<ImageEntry> images;
  final ImageDataCache cache;
  final int initialIndex;
  final VoidCallback? onEscape;
  final ValueChanged<int>? onIndexChanged;

  const ImageGalleryWidget({
    super.key,
    required this.images,
    required this.cache,
    required this.initialIndex,
    this.onEscape,
    this.onIndexChanged,
  });

  @override
  State<ImageGalleryWidget> createState() => _ImageGalleryWidgetState();
}

class _ImageGalleryWidgetState extends State<ImageGalleryWidget> {
  late ExtendedPageController _pageController;
  late int _currentIndex;
  ImageContext? get _currentImageContext =>
      widget.images[_currentIndex].context;

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
    // 当前图片由可见组件加载；这里只预加载邻近图片。
    _preloadImages(_currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _flyoutController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  int _preloadGeneration = 0;
  void _preloadImages(int currentIndex) {
    final generation = ++_preloadGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      for (final index in [currentIndex - 1, currentIndex + 1]) {
        if (!mounted || generation != _preloadGeneration) return;
        if (index < 0 || index >= widget.images.length) continue;
        try {
          final image = widget.images[index];
          final bytes = await widget.cache.read(image);
          if (!mounted || generation != _preloadGeneration) return;
          final provider = EpubImage.buildImage(bytes, image).image;
          final status = await provider.obtainCacheStatus(
            configuration: createLocalImageConfiguration(context),
          );
          if (!mounted || generation != _preloadGeneration) return;
          if (status == null ||
              (!status.pending && !status.keepAlive && !status.live)) {
            await precacheImage(provider, context);
          }
        } catch (error) {
          debugPrint('预加载失败: $error');
        }
      }
    });
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    _preloadImages(index);
    widget.onIndexChanged?.call(index);
  }

  KeyEventResult _handleGalleryKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
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

  void _previousImage() => _navigate(-1);
  void _nextImage() => _navigate(1);
  void _navigate(int delta) {
    final index = (_currentIndex + delta).clamp(0, widget.images.length - 1);
    if (index == _currentIndex) return;
    // 键盘/滚轮直接切页，避免连续输入与动画完成回调竞争。
    _currentIndex = index;
    _pageController.jumpToPage(index);
  }

  Future<void> _openInSystemViewer() => _performImageAction(
    '打开失败',
    (image, bytes) => SystemViewerService.openImageInSystemViewer(
      bytes,
      image.name,
      image.id,
    ),
  );
  Future<void> _copyToClipboard(String imageName) =>
      _performImageAction('复制失败', (image, bytes) async {
        await SystemViewerService.copyFileToClipboard(
          bytes,
          image.name,
          image.id,
        );
        if (mounted) {
          _showInfo('成功', '图片 "$imageName" 已复制到剪贴板', InfoBarSeverity.success);
        }
      });
  Future<void> _openWithDialog(String imageName) => _performImageAction(
    '打开失败',
    (image, bytes) =>
        SystemViewerService.openImageWithDialog(bytes, image.name, image.id),
  );

  Future<void> _performImageAction(
    String title,
    Future<void> Function(ImageEntry, Uint8List) action,
  ) async {
    final image = widget.images[_currentIndex];
    try {
      final bytes = await widget.cache.read(image);
      if (mounted) await action(image, bytes);
    } catch (error) {
      if (mounted) _showInfo(title, '$error', InfoBarSeverity.error);
    }
  }

  void _showInfo(String title, String message, InfoBarSeverity severity) {
    displayInfoBar(
      context,
      builder: (context, close) => InfoBar(
        title: Text(title),
        content: Text(message),
        severity: severity,
        action: IconButton(
          icon: const Icon(FluentIcons.clear),
          onPressed: close,
        ),
      ),
    );
  }

  List<MenuFlyoutItemBase> _buildContextMenuItems() {
    final String currentImageName = widget.images[_currentIndex].name;

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
                          return EpubImage(
                            key: ValueKey(widget.images[index].id),
                            image: widget.images[index],
                            cache: widget.cache,
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              if (_currentImageContext?.hasContent ?? false)
                ImageContextPanel(
                  key: ValueKey(widget.images[_currentIndex].id),
                  imageContext: _currentImageContext!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
