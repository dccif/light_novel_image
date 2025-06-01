import 'package:desktop_drop/desktop_drop.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cross_file/cross_file.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _dragging = false;
  bool _hovering = false;

  bool _isEpubFile(String fileName) {
    return fileName.toLowerCase().endsWith('.epub');
  }

  void _handleFileDrop(List<XFile> files) {
    // 只处理epub文件
    final epubFiles = files.where((file) => _isEpubFile(file.name)).toList();

    if (epubFiles.isNotEmpty) {
      // 传递所有epub文件路径到阅读器
      final epubPaths = epubFiles.map((file) => file.path).toList();
      context.go('/epub-viewer', extra: epubPaths);
    }
    // 如果没有epub文件，不做任何处理
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['epub'],
      allowMultiple: true,
    );

    if (result != null) {
      final files = result.files.map((file) => XFile(file.path!)).toList();
      _handleFileDrop(files);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [Text('轻小说图片浏览器', style: TextStyle(fontSize: 20))],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: DropTarget(
              onDragDone: (details) {
                _handleFileDrop(details.files);
              },
              onDragEntered: (details) {
                setState(() {
                  _dragging = true;
                });
              },
              onDragExited: (details) {
                setState(() {
                  _dragging = false;
                });
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) {
                  setState(() {
                    _hovering = true;
                  });
                },
                onExit: (_) {
                  setState(() {
                    _hovering = false;
                  });
                },
                child: Listener(
                  onPointerDown: (_) => _pickFiles(),
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: _dragging
                          ? FluentTheme.of(
                              context,
                            ).accentColor.withValues(alpha: 0.1)
                          : _hovering
                          ? FluentTheme.of(
                              context,
                            ).cardColor.withValues(alpha: 0.8)
                          : FluentTheme.of(context).cardColor,
                      border: Border.all(
                        color: _dragging
                            ? FluentTheme.of(context).accentColor
                            : _hovering
                            ? FluentTheme.of(
                                context,
                              ).accentColor.withValues(alpha: 0.6)
                            : Colors.grey.withValues(alpha: 0.3),
                        width: _dragging || _hovering ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            FluentIcons.reading_mode_solid,
                            size: 64,
                            color: _hovering || _dragging
                                ? FluentTheme.of(context).accentColor
                                : Colors.grey[120],
                          ),
                          const SizedBox(height: 24),
                          Text(
                            '拖拽 EPUB 文件到此处',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: _hovering || _dragging
                                  ? FluentTheme.of(context).accentColor
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '或点击选择文件',
                            style: TextStyle(
                              fontSize: 16,
                              color: _hovering || _dragging
                                  ? FluentTheme.of(context).accentColor
                                  : Colors.grey[100],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: FluentTheme.of(
                                context,
                              ).accentColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: FluentTheme.of(
                                  context,
                                ).accentColor.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              '仅支持 .epub 格式',
                              style: TextStyle(
                                fontSize: 14,
                                color: FluentTheme.of(context).accentColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
