import 'package:fluent_ui/fluent_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:light_novel_image/models/book_info.dart';
import 'package:light_novel_image/models/image_resolution.dart';
import 'package:light_novel_image/services/epub_parser_service.dart';
import 'package:light_novel_image/services/image_resolution_service.dart';
import 'package:light_novel_image/services/system_viewer_service.dart';
import 'package:light_novel_image/widgets/image_gallery_widget.dart';
import 'package:light_novel_image/widgets/image_grid_widget.dart';

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
  List<ImageResolution> _imageResolutions = [];
  ResolutionStatistics? _resolutionStatistics;
  bool _isLoading = true;
  bool _isAnalyzingResolutions = false;
  String? _error;
  int _currentIndex = 0;
  int _currentBookIndex = 0;
  bool _isGridView = true; // 默认显示九宫格视图

  // 排序后的图片数据
  List<Uint8List> _sortedImages = [];
  List<String> _sortedImageNames = [];
  List<int> _sortedImageBookIndexes = [];
  List<int> _sortedIndices = []; // 原始索引到排序索引的映射

  // 保存GridView的滚动位置
  final ScrollController _gridScrollController = ScrollController();

  // 缓存计算出的实际行高
  double? _cachedRowHeight;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _loadEpubImages();
  }

  @override
  void dispose() {
    _gridScrollController.dispose();
    SystemViewerService.cleanupTempFiles();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    await SystemViewerService.initTempDir();
  }

  /// 重置窗口大小到默认值
  Future<void> _resetWindowSize() async {
    if (!kIsWeb) {
      try {
        const defaultSize = Size(800, 800);
        await windowManager.setSize(defaultSize);
        debugPrint(
          '窗口大小已重置为: ${defaultSize.width.toInt()}x${defaultSize.height.toInt()}',
        );
      } catch (e) {
        debugPrint('重置窗口大小失败: $e');
      }
    }
  }

  /// 返回首页并重置窗口大小
  Future<void> _goBackHome() async {
    await _resetWindowSize();
    if (mounted) {
      context.go('/');
    }
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

  /// 根据图片分辨率对图片进行排序
  void _sortImages() {
    if (_imageResolutions.isEmpty ||
        _imageResolutions.length != _images.length) {
      // 如果没有分辨率信息，保持原始顺序
      _sortedImages = List.from(_images);
      _sortedImageNames = List.from(_imageNames);
      _sortedImageBookIndexes = List.from(_imageBookIndexes);
      _sortedIndices = List.generate(_images.length, (index) => index);
      return;
    }

    // 按面积（宽*高）从大到小排序
    final List<MapEntry<int, int>> indexAreaPairs = [];
    for (int i = 0; i < _images.length; i++) {
      final area = _imageResolutions[i].width * _imageResolutions[i].height;
      indexAreaPairs.add(MapEntry(i, area));
    }

    indexAreaPairs.sort((a, b) => b.value.compareTo(a.value));
    _sortedIndices = indexAreaPairs.map((e) => e.key).toList();

    // 根据排序后的索引重新排列所有相关数据
    _sortedImages = _sortedIndices.map((index) => _images[index]).toList();
    _sortedImageNames = _sortedIndices
        .map((index) => _imageNames[index])
        .toList();
    _sortedImageBookIndexes = _sortedIndices
        .map((index) => _imageBookIndexes[index])
        .toList();
  }

  void _updateCurrentBook() {
    if (_sortedImageBookIndexes.isNotEmpty &&
        _currentIndex < _sortedImageBookIndexes.length) {
      final newBookIndex = _sortedImageBookIndexes[_currentIndex];
      if (newBookIndex != _currentBookIndex) {
        setState(() {
          _currentBookIndex = newBookIndex;
        });
      }
    }
  }

  String? get _currentBookIdentifier {
    if (_books.isNotEmpty && _currentBookIndex < _books.length) {
      return _books[_currentBookIndex].title;
    }
    return null;
  }

  void _onImageTap(int imageIndex) {
    setState(() {
      _currentIndex = imageIndex;
      _isGridView = false;
    });
    _updateCurrentBook();
  }

  void _toggleView() {
    setState(() {
      _isGridView = !_isGridView;
    });

    // 如果切换到九宫格视图，滚动到当前图片所在行
    if (_isGridView) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToCurrentImageRow();
      });
    }
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
      // 使用 image_size_getter 在后台线程中获取图片分辨率
      final resolutions = await ImageResolutionService.getImageResolutionsAsync(
        _images,
      );

      // 统计分辨率信息
      final statistics = EpubParserService.calculateResolutionStatistics(
        resolutions,
      );

      if (mounted) {
        setState(() {
          _imageResolutions = resolutions;
          _resolutionStatistics = statistics;
          _isAnalyzingResolutions = false;
        });

        // 对图片进行排序
        _sortImages();

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

  void _onGalleryEscape() {
    setState(() {
      _isGridView = true;
    });

    // 返回九宫格时，立即滚动到当前图片所在行的居中位置
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentImageRow();
    });
  }

  /// 处理图片查看器中的索引变化
  void _onGalleryIndexChanged(int newIndex) {
    if (_currentIndex != newIndex) {
      setState(() {
        _currentIndex = newIndex;
      });
      _updateCurrentBook();
      debugPrint('图片查看器索引变化: $_currentIndex');
    }
  }

  /// 滚动到当前图片所在行，使其尽可能居中显示
  void _scrollToCurrentImageRow() {
    if (!_gridScrollController.hasClients) return;

    // 等待GridView完全构建后再计算滚动位置
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _performScrollToCurrentRow();
    });
  }

  /// 执行实际的滚动操作，使用动态计算的行高
  void _performScrollToCurrentRow() {
    if (!_gridScrollController.hasClients) return;

    const int itemsPerRow = 3;
    final int totalImages = _sortedImages.isNotEmpty
        ? _sortedImages.length
        : _images.length;

    if (totalImages == 0) return;

    // 计算当前图片在第几行（从0开始）
    final int currentRow = _currentIndex ~/ itemsPerRow;
    final int totalRows = (totalImages + itemsPerRow - 1) ~/ itemsPerRow;

    // 使用缓存的行高或动态计算
    double actualRowHeight = _cachedRowHeight ?? _calculateActualRowHeight();

    // 如果无法计算实际行高，使用估算值
    if (actualRowHeight <= 0) {
      actualRowHeight = 128.0; // 默认估算值
    }

    // 获取可视区域高度
    final double viewportHeight =
        _gridScrollController.position.viewportDimension;
    final double visibleRows = viewportHeight / actualRowHeight;

    double targetOffset;

    if (totalRows <= visibleRows) {
      // 如果总行数小于等于可视行数，滚动到顶部
      targetOffset = 0.0;
    } else {
      // 计算让当前行居中的滚动位置
      final double centerOffset =
          (currentRow * actualRowHeight) -
          (viewportHeight / 2) +
          (actualRowHeight / 2);

      // 确保滚动位置在有效范围内
      final double maxScrollExtent =
          _gridScrollController.position.maxScrollExtent;
      targetOffset = centerOffset.clamp(0.0, maxScrollExtent);
    }

    debugPrint('滚动到行 $currentRow，使用行高 $actualRowHeight，目标位置 $targetOffset');

    // 立即跳转到目标位置，不使用动画
    _gridScrollController.jumpTo(targetOffset);
  }

  /// 行高计算完成的回调
  void _onRowHeightCalculated(double rowHeight) {
    _cachedRowHeight = rowHeight;
    debugPrint('收到GridWidget计算的行高: $rowHeight');

    // 如果需要滚动，现在使用准确的行高重新计算
    if (_isGridView && !_isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _performScrollToCurrentRow();
      });
    }
  }

  /// 动态计算实际的网格行高
  double _calculateActualRowHeight() {
    try {
      // 如果GridView还没有内容，返回0
      if (!_gridScrollController.hasClients) return 0.0;

      final ScrollPosition position = _gridScrollController.position;

      // 获取总的可滚动内容高度
      final double maxScrollExtent = position.maxScrollExtent;
      final double viewportHeight = position.viewportDimension;
      final double totalContentHeight = maxScrollExtent + viewportHeight;

      const int itemsPerRow = 3;
      final int totalImages = _sortedImages.isNotEmpty
          ? _sortedImages.length
          : _images.length;
      final int totalRows = (totalImages + itemsPerRow - 1) ~/ itemsPerRow;

      if (totalRows <= 0) return 0.0;

      // 计算平均行高（包括padding）
      const double topPadding = 8.0; // GridView的顶部padding
      const double bottomPadding = 8.0; // GridView的底部padding
      final double contentHeight =
          totalContentHeight - topPadding - bottomPadding;

      final double averageRowHeight = contentHeight / totalRows;

      debugPrint(
        '动态计算行高: $averageRowHeight (总内容高度: $totalContentHeight, 行数: $totalRows)',
      );

      return averageRowHeight;
    } catch (e) {
      debugPrint('计算实际行高失败: $e');
      return 0.0;
    }
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
          if (!_isLoading && _images.isNotEmpty && _isGridView) _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Button(
          onPressed: _goBackHome,
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
          Button(
            onPressed: _toggleView,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isGridView ? FluentIcons.view : FluentIcons.grid_view_medium,
                ),
                const SizedBox(width: 4),
                Text(_isGridView ? '查看器' : '九宫格'),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (_isGridView)
            Text(
              '共 ${_sortedImages.isNotEmpty ? _sortedImages.length : _images.length} 张图片',
              style: FluentTheme.of(context).typography.body,
            )
          else
            Text(
              '${_currentIndex + 1} / ${_sortedImages.isNotEmpty ? _sortedImages.length : _images.length}',
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
            Button(onPressed: _goBackHome, child: const Text('返回首页')),
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

    if (_isGridView) {
      return ImageGridWidget(
        images: _sortedImages.isNotEmpty ? _sortedImages : _images,
        imageNames: _sortedImageNames.isNotEmpty
            ? _sortedImageNames
            : _imageNames,
        onImageTap: _onImageTap,
        scrollController: _gridScrollController,
        highlightedIndex: _currentIndex,
        onRowHeightCalculated: _onRowHeightCalculated,
      );
    } else {
      return ImageGalleryWidget(
        images: _sortedImages.isNotEmpty ? _sortedImages : _images,
        imageNames: _sortedImageNames.isNotEmpty
            ? _sortedImageNames
            : _imageNames,
        initialIndex: _currentIndex,
        bookIdentifier: _currentBookIdentifier,
        onEscape: _onGalleryEscape,
        onIndexChanged: _onGalleryIndexChanged,
      );
    }
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_resolutionStatistics != null &&
              _resolutionStatistics!.mostCommonResolution != null)
            Text(
              '最常见分辨率: ${_resolutionStatistics!.mostCommonResolution} (${_resolutionStatistics!.mostCommonResolutionCount}张)',
              style: FluentTheme.of(context).typography.caption,
            ),
        ],
      ),
    );
  }
}
