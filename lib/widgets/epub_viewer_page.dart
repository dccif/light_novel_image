import 'package:fluent_ui/fluent_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';
import 'package:epub_image/models/book_info.dart';
import 'package:epub_image/models/image_resolution.dart';
import 'package:epub_image/services/epub_parser_service.dart';
import 'package:epub_image/services/image_resolution_service.dart';
import 'package:epub_image/services/system_viewer_service.dart';
import 'package:epub_image/widgets/image_gallery_widget.dart';

class EpubViewerPage extends StatefulWidget {
  final List<String> epubPaths;

  const EpubViewerPage({super.key, required this.epubPaths});

  @override
  State<EpubViewerPage> createState() => _EpubViewerPageState();
}

class _EpubViewerPageState extends State<EpubViewerPage> {
  List<Uint8List> _images = [];
  List<String> _imageNames = [];
  List<BookInfo> _books = [];
  List<int> _imageBookIndexes = [];
  ResolutionStatistics? _resolutionStatistics;
  bool _isLoading = true;
  bool _isAnalyzingResolutions = false;
  String? _error;
  int _currentIndex = 0;
  int _currentBookIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _loadEpubImages();
  }

  @override
  void dispose() {
    _pageController.dispose();
    SystemViewerService.cleanupTempFiles();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    await SystemViewerService.initTempDir();
  }

  String get _currentBookTitle {
    if (_books.isEmpty || _currentBookIndex >= _books.length) {
      return '';
    }
    final totalBooks = _books.length;
    if (totalBooks > 1) {
      String title =
          '${_books[_currentBookIndex].title} (${_currentBookIndex + 1}/$totalBooks)';

      // 添加分辨率统计信息
      if (_resolutionStatistics != null &&
          _resolutionStatistics!.mostCommonResolution != null) {
        final stats = _resolutionStatistics!;
        title +=
            ' - 最常见: ${stats.mostCommonResolution} (${stats.mostCommonResolutionCount}张)';
        title += ' | 最大尺寸: ${stats.maxWidth}x${stats.maxHeight}';
      }

      return title;
    }

    String title = _books[_currentBookIndex].title;

    // 添加分辨率统计信息
    if (_resolutionStatistics != null &&
        _resolutionStatistics!.mostCommonResolution != null) {
      final stats = _resolutionStatistics!;
      title +=
          ' - 最常见: ${stats.mostCommonResolution} (${stats.mostCommonResolutionCount}张)';
      title += ' | 最大尺寸: ${stats.maxWidth}x${stats.maxHeight}';
    }

    return title;
  }

  void _updateCurrentBook() {
    if (_imageBookIndexes.isNotEmpty &&
        _currentIndex < _imageBookIndexes.length) {
      final newBookIndex = _imageBookIndexes[_currentIndex];
      if (newBookIndex != _currentBookIndex) {
        setState(() {
          _currentBookIndex = newBookIndex;
        });
      }
    }
  }

  Future<void> _openInSystemViewer() async {
    if (_currentIndex >= _images.length) return;

    await SystemViewerService.openImageInSystemViewer(
      _images[_currentIndex],
      _imageNames[_currentIndex],
    );
  }

  /// 自动调整窗口大小到推荐尺寸（直接使用最大宽度和最大高度）
  Future<void> _adjustWindowSizeToMostCommonResolution() async {
    if (!kIsWeb && _resolutionStatistics != null) {
      final recommendedSize = _resolutionStatistics!.recommendedWindowSize;

      // 添加一些边距来容纳UI元素（头部、页脚等）
      const double headerHeight = 60; // 头部高度
      const double footerHeight = 60; // 页脚高度
      const double padding = 32; // 左右边距

      final windowWidth = recommendedSize.width.toDouble() + padding;
      final windowHeight =
          recommendedSize.height.toDouble() +
          headerHeight +
          footerHeight +
          padding;

      try {
        // 尝试获取屏幕的真实分辨率
        final mediaData = MediaQuery.of(context);
        final screenWidth = mediaData.size.width * mediaData.devicePixelRatio;
        final screenHeight = mediaData.size.height * mediaData.devicePixelRatio;

        // 使用屏幕的90%作为最大窗口尺寸，保留一些边距
        final double maxAllowedWidth = screenWidth * 0.9;
        final double maxAllowedHeight = screenHeight * 0.9;

        // 确保有合理的最小和最大限制
        final double screenLimitWidth = maxAllowedWidth > 800
            ? maxAllowedWidth
            : 1920;
        final double screenLimitHeight = maxAllowedHeight > 600
            ? maxAllowedHeight
            : 1080;

        final finalWidth = windowWidth.clamp(400.0, screenLimitWidth);
        final finalHeight = windowHeight.clamp(300.0, screenLimitHeight);

        // 设置窗口大小
        await windowManager.setSize(Size(finalWidth, finalHeight));

        // 将窗口居中
        await windowManager.center();

        debugPrint('窗口大小已调整为: ${finalWidth.toInt()}x${finalHeight.toInt()}');
        debugPrint(
          '基于图片尺寸: 最大宽度=${recommendedSize.width}, 最大高度=${recommendedSize.height}',
        );
        debugPrint(
          '屏幕分辨率: ${screenWidth.toInt()}x${screenHeight.toInt()}, 限制: ${screenLimitWidth.toInt()}x${screenLimitHeight.toInt()}',
        );
      } catch (e) {
        debugPrint('调整窗口大小失败: $e');
        // 如果获取屏幕信息失败，使用默认限制
        try {
          final finalWidth = windowWidth.clamp(400.0, 1920.0);
          final finalHeight = windowHeight.clamp(300.0, 1080.0);
          await windowManager.setSize(Size(finalWidth, finalHeight));
          await windowManager.center();
          debugPrint(
            '使用默认限制调整窗口大小: ${finalWidth.toInt()}x${finalHeight.toInt()}',
          );
        } catch (e2) {
          debugPrint('窗口大小调整完全失败: $e2');
        }
      }
    }
  }

  /// 分析图片分辨率
  Future<void> _analyzeImageResolutions() async {
    if (_images.isEmpty) return;

    setState(() {
      _isAnalyzingResolutions = true;
    });

    try {
      // 在主线程中获取图片分辨率
      final resolutions = await ImageResolutionService.getImageResolutions(
        _images,
      );

      // 统计分辨率信息
      final statistics = EpubParserService.calculateResolutionStatistics(
        resolutions,
      );

      if (mounted) {
        setState(() {
          _resolutionStatistics = statistics;
          _isAnalyzingResolutions = false;
        });

        // 自动调整窗口大小
        await _adjustWindowSizeToMostCommonResolution();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAnalyzingResolutions = false;
          _error = '分析图片分辨率失败: $e';
        });
      }
    }
  }

  Future<void> _loadEpubImages() async {
    try {
      final result = await compute(
        EpubParserService.parseMultipleEpubs,
        widget.epubPaths,
      );

      if (mounted) {
        setState(() {
          _books = result.books;
          _images = result.allImages;
          _imageNames = result.allImageNames;
          _imageBookIndexes = result.imageBookIndexes;
          _currentBookIndex = _imageBookIndexes.isNotEmpty
              ? _imageBookIndexes[0]
              : 0;
          _isLoading = false;
        });

        // 开始分析图片分辨率
        await _analyzeImageResolutions();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '加载失败: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _previousImage() {
    if (_currentIndex > 0) {
      _currentIndex--;
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _updateCurrentBook();
    }
  }

  void _nextImage() {
    if (_currentIndex < _images.length - 1) {
      _currentIndex++;
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _updateCurrentBook();
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    _updateCurrentBook();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 8),
          Expanded(child: _buildContent()),
          if (!_isLoading && _images.isNotEmpty) _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Button(
          onPressed: () => context.go('/'),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [Icon(FluentIcons.back), SizedBox(width: 8), Text('返回')],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            _currentBookTitle,
            style: FluentTheme.of(context).typography.subtitle,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 16),
        if (!_isLoading && _images.isNotEmpty) ...[
          Text(
            '${_currentIndex + 1} / ${_images.length}',
            style: FluentTheme.of(context).typography.body,
          ),
        ],
        if (_isAnalyzingResolutions) ...[
          const SizedBox(width: 8),
          const SizedBox(width: 16, height: 16, child: ProgressRing()),
          const SizedBox(width: 4),
          Text('分析中...', style: FluentTheme.of(context).typography.caption),
        ],
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [ProgressRing(), SizedBox(height: 16), Text('正在加载图片...')],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(FluentIcons.error, size: 48),
            const SizedBox(height: 16),
            Text(_error!),
            const SizedBox(height: 16),
            Button(onPressed: () => context.go('/'), child: const Text('返回首页')),
          ],
        ),
      );
    }

    if (_images.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(FluentIcons.photo2, size: 48),
            SizedBox(height: 16),
            Text('所选epub文件中没有找到图片'),
          ],
        ),
      );
    }

    return ImageGalleryWidget(
      images: _images,
      pageController: _pageController,
      currentIndex: _currentIndex,
      onPageChanged: _onPageChanged,
      onOpenInSystemViewer: _openInSystemViewer,
      onPreviousImage: _previousImage,
      onNextImage: _nextImage,
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Button(
            onPressed: _currentIndex > 0 ? _previousImage : null,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(FluentIcons.chevron_left),
                SizedBox(width: 4),
                Text('上一张'),
              ],
            ),
          ),
          const SizedBox(width: 16),
          if (_images.isNotEmpty)
            Text(
              _imageNames[_currentIndex],
              style: FluentTheme.of(context).typography.caption,
            ),
          const SizedBox(width: 16),
          Button(
            onPressed: _currentIndex < _images.length - 1 ? _nextImage : null,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('下一张'),
                SizedBox(width: 4),
                Icon(FluentIcons.chevron_right),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
