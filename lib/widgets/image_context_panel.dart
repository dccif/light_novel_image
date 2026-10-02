import 'package:fluent_ui/fluent_ui.dart';

import '../models/image_context.dart';
import '../utils/scroll_visibility.dart';

/// 以图片标记为滚动原点，前后段落分别懒布局，无须先排版全文才能定位。
class ImageContextPanel extends StatefulWidget {
  final ImageContext imageContext;
  const ImageContextPanel({super.key, required this.imageContext});

  @override
  State<ImageContextPanel> createState() => _ImageContextPanelState();
}

class _ImageContextPanelState extends State<ImageContextPanel> {
  final _scroll = ScrollController();
  final _centerKey = GlobalKey();
  final _markerKey = GlobalKey();
  final _viewportKey = GlobalKey();
  final _outOfView = ValueNotifier(false);
  late final BookText _document;
  late final int _paragraph;
  late final String _before;
  late final String _after;
  bool _restoring = false;

  @override
  void initState() {
    super.initState();
    final context = widget.imageContext;
    _document = context.document ?? BookText(context.content);
    _paragraph = _document.paragraphAt(context.imageOffset);
    if (_document.length == 0) {
      _before = _after = '';
    } else {
      final text = _document.paragraph(_paragraph);
      final offset = (context.imageOffset - _document.starts[_paragraph]).clamp(
        0,
        text.length,
      );
      _before = text.substring(0, offset).trimRight();
      _after = text.substring(offset).trimLeft();
    }
    _scroll.addListener(_scheduleVisibilityCheck);
  }

  bool _checkScheduled = false;
  void _scheduleVisibilityCheck() {
    if (_checkScheduled) return;
    _checkScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScheduled = false;
      if (!mounted || _restoring) return;
      final marker = _markerKey.currentContext?.findRenderObject();
      final viewport = _viewportKey.currentContext?.findRenderObject();
      if (marker is! RenderBox || viewport is! RenderBox || !marker.hasSize) {
        return;
      }
      final top = marker.localToGlobal(Offset.zero).dy;
      final viewportTop = viewport.localToGlobal(Offset.zero).dy;
      _outOfView.value = !ScrollVisibility.isFullyVisible(
        itemTop: top,
        itemBottom: top + marker.size.height,
        viewportTop: viewportTop,
        viewportBottom: viewportTop + viewport.size.height,
      );
    });
  }

  Future<void> _restore() async {
    if (!_scroll.hasClients) return;
    _restoring = true;
    _outOfView.value = false;
    await _scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
    if (!mounted) return;
    _restoring = false;
    _scheduleVisibilityCheck();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _outOfView.dispose();
    super.dispose();
  }

  Widget _text(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Text(text, style: FluentTheme.of(context).typography.body),
  );

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Container(
      width: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.micaBackgroundColor,
        border: Border(
          left: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(FluentIcons.info, size: 16),
              const SizedBox(width: 8),
              Text('图片上下文', style: theme.typography.subtitle),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '第 ${widget.imageContext.chapterOrder} 节 · ${widget.imageContext.chapterTitle}',
            style: theme.typography.caption,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Stack(
              // 隐藏按钮返回 SizedBox.shrink 时，不能让 Stack 的宽度跟着归零。
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: SelectionArea(
                    child: CustomScrollView(
                      key: _viewportKey,
                      controller: _scroll,
                      center: _centerKey,
                      anchor: 0.35,
                      slivers: [
                        SliverList.builder(
                          itemCount: _paragraph + (_before.isEmpty ? 0 : 1),
                          itemBuilder: (context, index) {
                            if (_before.isNotEmpty && index == 0) {
                              return _text(_before);
                            }
                            final paragraph =
                                _paragraph -
                                1 -
                                index +
                                (_before.isEmpty ? 0 : 1);
                            return _text(_document.paragraph(paragraph));
                          },
                        ),
                        SliverToBoxAdapter(
                          key: _centerKey,
                          child: Container(
                            key: _markerKey,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: theme.accentColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: theme.accentColor.withValues(
                                  alpha: 0.45,
                                ),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(FluentIcons.photo2, size: 14),
                                SizedBox(width: 8),
                                Text('图片原文位置'),
                              ],
                            ),
                          ),
                        ),
                        SliverList.builder(
                          itemCount:
                              (_document.length - _paragraph - 1).clamp(
                                0,
                                _document.length,
                              ) +
                              (_after.isEmpty ? 0 : 1),
                          itemBuilder: (context, index) {
                            if (_after.isNotEmpty && index == 0) {
                              return _text(_after);
                            }
                            final paragraph =
                                _paragraph +
                                1 +
                                index -
                                (_after.isEmpty ? 0 : 1);
                            return _text(_document.paragraph(paragraph));
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: _outOfView,
                  builder: (context, show, child) => show
                      ? Positioned(right: 12, bottom: 12, child: child!)
                      : const SizedBox.shrink(),
                  child: Tooltip(
                    message: '回到图片原文位置',
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.accentColor,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(
                          FluentIcons.photo2,
                          color: Colors.white,
                        ),
                        onPressed: _restore,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
