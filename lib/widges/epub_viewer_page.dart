import 'dart:io';
import 'dart:convert';
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
  final String title;
  final List<Uint8List> images;
  final List<String> imageNames;

  EpubParseResult({
    required this.title,
    required this.images,
    required this.imageNames,
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

// 后台解析函数 - 在isolate中运行
Future<EpubParseResult> _parseEpubInBackground(String epubPath) async {
  final bytes = await File(epubPath).readAsBytes();
  final archive = ZipDecoder().decodeBytes(bytes);

  // 提取标题
  String title = path.basenameWithoutExtension(epubPath); // 默认标题

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
                  title = extractedTitle;
                  break;
                }
              }
            }
          }
        }
      }
    }

    // 如果上述方法失败，直接搜索所有文件中的.opf文件
    if (title == path.basenameWithoutExtension(epubPath)) {
      for (final file in archive.files) {
        if (file.name.toLowerCase().endsWith('.opf')) {
          final content = _safeDecodeBytes(file.content as List<int>);
          try {
            final doc = XmlDocument.parse(content);
            final titleElements = doc.findAllElements('dc:title');
            if (titleElements.isNotEmpty) {
              final extractedTitle = titleElements.first.innerText.trim();
              if (extractedTitle.isNotEmpty) {
                title = extractedTitle;
                break;
              }
            }
          } catch (e) {
            // 忽略解析错误，继续查找其他文件
            continue;
          }
        }
      }
    }
  } catch (e) {
    // 如果发生任何错误，保持默认标题
    debugPrint('提取标题时发生错误: $e');
  }

  // 提取图片
  List<Uint8List> images = [];
  List<String> imageNames = [];

  // 常见的图片文件扩展名
  final imageExtensions = {'.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'};

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

  return EpubParseResult(
    title: title,
    images: indexed.map((i) => images[i]).toList(),
    imageNames: indexed.map((i) => imageNames[i]).toList(),
  );
}

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
  Directory? _tempDir;
  String _bookTitle = '';

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

  Future<void> _openInSystemViewer() async {
    if (_tempDir == null || _currentIndex >= _images.length) return;

    final imageName = _imageNames[_currentIndex];
    final tempFile = File(path.join(_tempDir!.path, imageName));

    if (!await tempFile.exists()) {
      await tempFile.writeAsBytes(_images[_currentIndex]);
    }

    // 使用Process.run来打开系统默认的图片查看器
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
      // 在后台线程中解析EPUB文件
      final result = await compute(_parseEpubInBackground, widget.epubPath);

      if (mounted) {
        setState(() {
          _bookTitle = result.title;
          _images = result.images;
          _imageNames = result.imageNames;
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
                  _bookTitle,
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
              },
            ),
          ),
        ),
      ),
    );
  }
}
