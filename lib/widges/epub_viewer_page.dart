import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:xml/xml.dart';

// 后台处理的数据结构
class EpubParseResult {
  final List<BookInfo> books;
  final List<Uint8List> allImages;
  final List<String> allImageNames;
  final List<int> imageBookIndexes; // 每张图片属于哪本书

  EpubParseResult({
    required this.books,
    required this.allImages,
    required this.allImageNames,
    required this.imageBookIndexes,
  });
}

class BookInfo {
  final String title;
  final String filePath;
  final int startImageIndex;
  final int endImageIndex;

  BookInfo({
    required this.title,
    required this.filePath,
    required this.startImageIndex,
    required this.endImageIndex,
  });
}

// 安全地将字节转换为UTF-8字符串
String _safeDecodeBytes(List<int> bytes) {
  try {
    return utf8.decode(bytes);
  } catch (e) {
    // 如果UTF-8解码失败，尝试使用latin1
    try {
      return latin1.decode(bytes);
    } catch (e2) {
      // 最后的后备方案
      return String.fromCharCodes(bytes);
    }
  }
}

// 从单个epub文件提取标题
String _extractTitleFromArchive(Archive archive, String filePath) {
  try {
    // 首先尝试在根目录和META-INF目录下查找container.xml
    final containerFile =
        archive.findFile('container.xml') ??
        archive.findFile('META-INF/container.xml');

    if (containerFile != null) {
      final containerContent = _safeDecodeBytes(
        containerFile.content as List<int>,
      );
      final containerDoc = XmlDocument.parse(containerContent);

      // 获取OPF文件路径
      final rootfileElements = containerDoc.findAllElements('rootfile');
      for (final element in rootfileElements) {
        if (element.getAttribute('media-type') ==
            'application/oebps-package+xml') {
          final opfPath = element.getAttribute('full-path');
          if (opfPath != null) {
            final opfFile = archive.findFile(opfPath);
            if (opfFile != null) {
              final opfContent = _safeDecodeBytes(opfFile.content as List<int>);
              final opfDoc = XmlDocument.parse(opfContent);

              // 尝试获取标题
              final titleElements = opfDoc.findAllElements('dc:title');
              if (titleElements.isNotEmpty) {
                final extractedTitle = titleElements.first.innerText.trim();
                if (extractedTitle.isNotEmpty) {
                  return extractedTitle;
                }
              }
            }
          }
        }
      }
    }

    // 如果上述方法失败，直接搜索所有文件中的.opf文件
    for (final file in archive.files) {
      if (file.name.toLowerCase().endsWith('.opf')) {
        final content = _safeDecodeBytes(file.content as List<int>);
        try {
          final doc = XmlDocument.parse(content);
          final titleElements = doc.findAllElements('dc:title');
          if (titleElements.isNotEmpty) {
            final extractedTitle = titleElements.first.innerText.trim();
            if (extractedTitle.isNotEmpty) {
              return extractedTitle;
            }
          }
        } catch (e) {
          continue;
        }
      }
    }
  } catch (e) {
    debugPrint('提取标题时发生错误: $e');
  }

  return path.basenameWithoutExtension(filePath);
}

// 后台解析函数 - 在isolate中运行
Future<EpubParseResult> _parseMultipleEpubsInBackground(
  List<String> epubPaths,
) async {
  List<BookInfo> books = [];
  List<Uint8List> allImages = [];
  List<String> allImageNames = [];
  List<int> imageBookIndexes = [];

  // 常见的图片文件扩展名
  final imageExtensions = {'.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'};

  for (int bookIndex = 0; bookIndex < epubPaths.length; bookIndex++) {
    final epubPath = epubPaths[bookIndex];

    try {
      final bytes = await File(epubPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // 提取标题
      final title = _extractTitleFromArchive(archive, epubPath);

      // 记录这本书的图片开始索引
      final startImageIndex = allImages.length;

      // 提取图片
      List<Uint8List> bookImages = [];
      List<String> bookImageNames = [];

      for (final file in archive) {
        if (file.isFile) {
          final fileName = file.name.toLowerCase();
          if (imageExtensions.any((ext) => fileName.endsWith(ext))) {
            final content = file.content as List<int>;
            bookImages.add(Uint8List.fromList(content));
            bookImageNames.add(file.name.split('/').last);
          }
        }
      }

      // 按文件名排序
      final indexed = List.generate(bookImages.length, (i) => i);
      indexed.sort((a, b) => bookImageNames[a].compareTo(bookImageNames[b]));

      final sortedImages = indexed.map((i) => bookImages[i]).toList();
      final sortedImageNames = indexed.map((i) => bookImageNames[i]).toList();

      // 添加到总的图片列表
      allImages.addAll(sortedImages);
      allImageNames.addAll(sortedImageNames);

      // 记录每张图片属于哪本书
      for (int i = 0; i < sortedImages.length; i++) {
        imageBookIndexes.add(bookIndex);
      }

      // 记录这本书的图片结束索引
      final endImageIndex = allImages.length - 1;

      books.add(
        BookInfo(
          title: title,
          filePath: epubPath,
          startImageIndex: startImageIndex,
          endImageIndex: endImageIndex,
        ),
      );
    } catch (e) {
      debugPrint('解析epub文件失败: $epubPath, 错误: $e');
      // 如果某个文件解析失败，添加一个错误记录
      books.add(
        BookInfo(
          title: '${path.basenameWithoutExtension(epubPath)} (解析失败)',
          filePath: epubPath,
          startImageIndex: allImages.length,
          endImageIndex: allImages.length - 1,
        ),
      );
    }
  }

  return EpubParseResult(
    books: books,
    allImages: allImages,
    allImageNames: allImageNames,
    imageBookIndexes: imageBookIndexes,
  );
}

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
  Directory? _tempDir;

  @override
  void initState() {
    super.initState();
    _initTempDir();
    _loadEpubImages();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _cleanupTempFiles();
    super.dispose();
  }

  Future<void> _initTempDir() async {
    final tempDir = await getTemporaryDirectory();
    _tempDir = await Directory(
      path.join(tempDir.path, 'epub_viewer'),
    ).create(recursive: true);
  }

  Future<void> _cleanupTempFiles() async {
    if (_tempDir != null && await _tempDir!.exists()) {
      await _tempDir!.delete(recursive: true);
    }
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
    if (_tempDir == null || _currentIndex >= _images.length) return;

    final imageName = _imageNames[_currentIndex];
    final tempFile = File(path.join(_tempDir!.path, imageName));

    if (!await tempFile.exists()) {
      await tempFile.writeAsBytes(_images[_currentIndex]);
    }

    try {
      if (Platform.isWindows) {
        await Process.run('explorer.exe', [tempFile.path]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [tempFile.path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [tempFile.path]);
      }
    } catch (e) {
      debugPrint('打开系统图片查看器失败: $e');
    }
  }

  Future<void> _loadEpubImages() async {
    try {
      // 在后台线程中解析所有EPUB文件
      final result = await compute(
        _parseMultipleEpubsInBackground,
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // 头部工具栏
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
            Text('所选epub文件中没有找到图片'),
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
        child: Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent) {
              if (event.logicalKey == LogicalKeyboardKey.enter) {
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
          child: GestureDetector(
            onDoubleTap: _openInSystemViewer,
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
                _updateCurrentBook();
              },
            ),
          ),
        ),
      ),
    );
  }
}
