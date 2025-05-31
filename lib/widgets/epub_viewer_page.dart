import 'package:fluent_ui/fluent_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import 'package:epub_image/models/book_info.dart';
import 'package:epub_image/services/epub_parser_service.dart';
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
  bool _isLoading = true;
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
      return '${_books[_currentBookIndex].title} (${_currentBookIndex + 1}/$totalBooks)';
    }
    return _books[_currentBookIndex].title;
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
          const SizedBox(height: 16),
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
        if (!_isLoading && _images.isNotEmpty)
          Text(
            '${_currentIndex + 1} / ${_images.length}',
            style: FluentTheme.of(context).typography.body,
          ),
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
      padding: const EdgeInsets.only(top: 16),
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
