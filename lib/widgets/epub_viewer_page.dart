import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

import '../models/book_info.dart';
import '../models/epub_parse_result.dart';
import '../models/image_entry.dart';
import '../models/image_resolution.dart';
import '../services/epub_parser_service.dart';
import '../services/image_data_cache.dart';
import '../utils/grid_metrics.dart';
import 'image_gallery_widget.dart';
import 'image_grid_widget.dart';

class EpubViewerPage extends StatefulWidget {
  final List<String> epubPaths;
  const EpubViewerPage({super.key, required this.epubPaths});
  @override
  State<EpubViewerPage> createState() => _EpubViewerPageState();
}

class _EpubViewerPageState extends State<EpubViewerPage> {
  List<ImageEntry> _images = [];
  List<BookInfo> _books = [];
  ResolutionStatistics? _statistics;
  final _cache = ImageDataCache();
  final _gridScroll = ScrollController();
  Directory? _importDirectory;
  bool _importing = true;
  bool _loading = true;
  bool _grid = true;
  int _index = 0;
  String? _error;
  GridMetrics? _metrics;
  bool _restoreGrid = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _cache.close();
    _gridScroll.dispose();
    // 此程序同一时刻只有一个导入页。释放缓存键持有的编码字节。
    PaintingBinding.instance.imageCache.clear();
    if (!_importing) unawaited(_cleanImportDirectory());
    super.dispose();
  }

  Future<void> _cleanImportDirectory() async {
    final directory = _importDirectory;
    _importDirectory = null;
    if (directory == null) return;
    try {
      if (await directory.exists()) await directory.delete(recursive: true);
    } catch (error) {
      debugPrint('清理导入缓存失败: $error');
    }
  }

  Future<void> _load() async {
    try {
      final temporary = await getTemporaryDirectory();
      final root = await Directory(
        path.join(temporary.path, 'epub_viewer_imports'),
      ).create(recursive: true);
      _importDirectory = await root.createTemp('session_');
      if (!mounted) return;
      final result = await compute(
        EpubParserService.parseMultipleEpubs,
        EpubImportRequest(widget.epubPaths, _importDirectory!.path),
      );
      if (!mounted) return;
      final indices = List.generate(result.images.length, (i) => i)
        ..sort((a, b) {
          final area = result.images[b].area.compareTo(result.images[a].area);
          return area == 0 ? a.compareTo(b) : area;
        });
      setState(() {
        _books = result.books;
        _images = _OrderedImages(result.images, indices);
        _statistics = result.resolutionStatistics;
        _loading = false;
      });
      if (_images.isNotEmpty) await _adjustWindow();
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '加载失败: $error';
        });
      }
    } finally {
      _importing = false;
      if (!mounted) await _cleanImportDirectory();
    }
  }

  Future<void> _adjustWindow() async {
    if (kIsWeb || !mounted) return;
    try {
      final display = View.of(context).display;
      final screen = display.size / display.devicePixelRatio;
      final dimensions = _statistics!.recommendedWindowSize;
      await windowManager.setSize(
        Size(
          (dimensions.width + 32.0).clamp(
            400,
            (screen.width * 0.9).clamp(400, double.infinity),
          ),
          (dimensions.height + 152.0).clamp(
            300,
            (screen.height * 0.9).clamp(300, double.infinity),
          ),
        ),
      );
    } catch (error) {
      debugPrint('调整窗口大小失败: $error');
    }
  }

  Future<void> _home() async {
    try {
      await windowManager.setSize(const Size(800, 800));
    } catch (error) {
      debugPrint('重置窗口大小失败: $error');
    }
    if (mounted) context.go('/');
  }

  String get _commonResolution => _statistics?.mostCommonResolution == null
      ? ''
      : '最常见: ${_statistics!.mostCommonResolution} (${_statistics!.mostCommonResolutionCount}张)';

  String get _title {
    if (_books.isEmpty) return '';
    final bookIndex = _images.isEmpty ? 0 : _images[_index].bookIndex;
    var title = _books[bookIndex].title;
    if (_books.length > 1) title += ' (${bookIndex + 1}/${_books.length})';
    if (_commonResolution.isNotEmpty) {
      title +=
          ' - $_commonResolution | 最大尺寸: ${_statistics!.maxWidth}x${_statistics!.maxHeight}';
    }
    return title;
  }

  void _select(int index) => setState(() {
    _index = index;
    _grid = false;
  });
  void _showGrid() => setState(() {
    _grid = true;
    _restoreGrid = true;
  });
  void _toggle() {
    if (_grid) {
      setState(() => _grid = false);
    } else {
      _showGrid();
    }
  }

  void _onMetrics(GridMetrics metrics) {
    if (!mounted || !_grid || !_gridScroll.hasClients) return;
    final changed = _metrics?.width != metrics.width;
    _metrics = metrics;
    if (!_restoreGrid && !changed) return;
    _restoreGrid = false;
    final position = _gridScroll.position;
    _gridScroll.jumpTo(
      metrics.centeredOffset(
        _index,
        position.viewportDimension,
        position.maxScrollExtent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        Row(
          children: [
            Button(
              onPressed: _home,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.back),
                  SizedBox(width: 8),
                  Text('返回'),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                _title,
                overflow: TextOverflow.ellipsis,
                style: FluentTheme.of(context).typography.subtitle,
              ),
            ),
            if (!_loading && _images.isNotEmpty) ...[
              Button(onPressed: _toggle, child: Text(_grid ? '查看器' : '九宫格')),
              const SizedBox(width: 8),
              Text(
                _grid
                    ? '共 ${_images.length} 张图片'
                    : '${_index + 1} / ${_images.length}',
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Expanded(child: _content()),
        if (!_loading && _images.isNotEmpty && _grid)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _commonResolution,
              style: FluentTheme.of(context).typography.caption,
            ),
          ),
      ],
    ),
  );

  Widget _content() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [ProgressRing(), SizedBox(height: 16), Text('正在加载图片...')],
        ),
      );
    }
    if (_error != null) return Center(child: Text(_error!));
    if (_images.isEmpty) return const Center(child: Text('所选epub文件中没有找到图片'));
    // 隐藏视图销毁，不保留网格的解码图片和布局状态。
    if (_grid) {
      return ImageGridWidget(
        images: _images,
        cache: _cache,
        scrollController: _gridScroll,
        highlightedIndex: _index,
        onImageTap: _select,
        onMetricsChanged: _onMetrics,
      );
    }
    return ImageGalleryWidget(
      images: _images,
      cache: _cache,
      initialIndex: _index,
      onEscape: _showGrid,
      onIndexChanged: (index) {
        if (_index != index) setState(() => _index = index);
      },
    );
  }
}

/// 仅保存一份排序索引，图片元数据无需再复制。
class _OrderedImages extends ListBase<ImageEntry> {
  final List<ImageEntry> source;
  final List<int> indices;
  _OrderedImages(this.source, this.indices);
  @override
  int get length => indices.length;
  @override
  set length(int value) => throw UnsupportedError('只读图片列表');
  @override
  ImageEntry operator [](int index) => source[indices[index]];
  @override
  void operator []=(int index, ImageEntry value) =>
      throw UnsupportedError('只读图片列表');
}
