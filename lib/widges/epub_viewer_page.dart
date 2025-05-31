import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

class EpubViewerPage extends StatefulWidget {
  final String epubPath;

  const EpubViewerPage({super.key, required this.epubPath});

  @override
  State<EpubViewerPage> createState() => _EpubViewerPageState();
}

class _EpubViewerPageState extends State<EpubViewerPage> {
  List<Uint8List> _images = [];
  List<String> _imageNames = [];
  bool _isLoading = true;
  String? _error;
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _loadEpubImages();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadEpubImages() async {
    try {
      final bytes = await File(widget.epubPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      List<Uint8List> images = [];
      List<String> imageNames = [];

      // 常见的图片文件扩展名
      final imageExtensions = {
        '.jpg',
        '.jpeg',
        '.png',
        '.gif',
        '.bmp',
        '.webp',
      };

      for (final file in archive) {
        if (file.isFile) {
          final fileName = file.name.toLowerCase();
          if (imageExtensions.any((ext) => fileName.endsWith(ext))) {
            final content = file.content as List<int>;
            images.add(Uint8List.fromList(content));
            imageNames.add(file.name.split('/').last);
          }
        }
      }

      // 按文件名排序
      final indexed = List.generate(images.length, (i) => i);
      indexed.sort((a, b) => imageNames[a].compareTo(imageNames[b]));

      setState(() {
        _images = indexed.map((i) => images[i]).toList();
        _imageNames = indexed.map((i) => imageNames[i]).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '加载失败: $e';
        _isLoading = false;
      });
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // 头部工具栏
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Button(
                    onPressed: () => context.go('/'),
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
                  Text(
                    'Epub 图片浏览器',
                    style: FluentTheme.of(context).typography.subtitle,
                  ),
                ],
              ),
              if (!_isLoading && _images.isNotEmpty)
                Text(
                  '${_currentIndex + 1} / ${_images.length}',
                  style: FluentTheme.of(context).typography.body,
                ),
            ],
          ),
          const SizedBox(height: 16),

          // 主要内容区域
          Expanded(child: _buildContent()),

          // 底部导航栏
          if (!_isLoading && _images.isNotEmpty)
            Padding(
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
                    onPressed: _currentIndex < _images.length - 1
                        ? _nextImage
                        : null,
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
            ),
        ],
      ),
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
            Text('此epub文件中没有找到图片'),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: FluentTheme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: PhotoViewGallery.builder(
          scrollPhysics: const BouncingScrollPhysics(),
          builder: (BuildContext context, int index) {
            return PhotoViewGalleryPageOptions(
              imageProvider: MemoryImage(_images[index]),
              initialScale: PhotoViewComputedScale.contained,
              minScale: PhotoViewComputedScale.contained * 0.5,
              maxScale: PhotoViewComputedScale.covered * 2.0,
              heroAttributes: PhotoViewHeroAttributes(tag: index),
            );
          },
          itemCount: _images.length,
          loadingBuilder: (context, event) =>
              const Center(child: ProgressRing()),
          pageController: _pageController,
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
        ),
      ),
    );
  }
}
