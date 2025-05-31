import 'package:desktop_drop/desktop_drop.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:go_router/go_router.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<DropItem> _list = [];
  bool _dragging = false;

  bool _isEpubFile(String fileName) {
    return fileName.toLowerCase().endsWith('.epub');
  }

  void _handleFileDrop(List<DropItem> files) {
    // 检查是否包含epub文件
    final epubFiles = files.where((file) => _isEpubFile(file.name)).toList();

    if (epubFiles.isNotEmpty) {
      // 如果有epub文件，直接传递所有epub文件路径
      final epubPaths = epubFiles.map((file) => file.path).toList();
      context.go('/epub-viewer', extra: epubPaths);
    } else {
      // 如果没有epub文件，按原来的逻辑添加到列表
      setState(() {
        _list.addAll(files);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Epub image viewer', style: TextStyle(fontSize: 20)),
              if (_list.isNotEmpty)
                Button(
                  onPressed: () {
                    setState(() {
                      _list.clear();
                    });
                  },
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(FluentIcons.clear),
                      SizedBox(width: 8),
                      Text('清空文件', style: TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
            ],
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
              child: Container(
                decoration: BoxDecoration(
                  color: _dragging
                      ? FluentTheme.of(
                          context,
                        ).accentColor.withValues(alpha: 0.1)
                      : FluentTheme.of(context).cardColor,
                  border: Border.all(
                    color: _dragging
                        ? FluentTheme.of(context).accentColor
                        : Colors.grey.withValues(alpha: 0.3),
                    width: _dragging ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: _list.isEmpty
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(FluentIcons.cloud_upload, size: 48),
                            const SizedBox(height: 16),
                            const Text(
                              '拖拽文件到此处',
                              style: TextStyle(fontSize: 18),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '支持 .epub 文件自动打开图片浏览器',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[100],
                              ),
                            ),
                          ],
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '已添加的文件:',
                                style: FluentTheme.of(
                                  context,
                                ).typography.bodyStrong,
                              ),
                              const SizedBox(height: 12),
                              ...(_list.map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _isEpubFile(item.name)
                                            ? FluentIcons.reading_mode_solid
                                            : FluentIcons.document,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          item.name,
                                          style: FluentTheme.of(
                                            context,
                                          ).typography.body,
                                        ),
                                      ),
                                      if (_isEpubFile(item.name))
                                        Button(
                                          onPressed: () {
                                            context.go(
                                              '/epub-viewer',
                                              extra: [item.path],
                                            );
                                          },
                                          child: const Text('打开'),
                                        ),
                                    ],
                                  ),
                                ),
                              )),
                            ],
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
