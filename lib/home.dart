import 'package:fluent_ui/fluent_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
    required this.child,
    required this.shellContext,
  });

  final Widget child;
  final BuildContext? shellContext;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WindowListener {
  final viewKey = GlobalKey(debugLabel: 'Navigation View Key');

  final List<NavigationPaneItem> originalItems = [
    PaneItem(
      key: ValueKey("/"),
      icon: Icon(FluentIcons.home),
      title: Text("Home"),
      body: const SizedBox.shrink(),
    ),
    PaneItem(
      key: ValueKey("/epub-viewer"),
      icon: Icon(FluentIcons.fabric_picture_library),
      title: Text("图片浏览器"),
      body: const SizedBox.shrink(),
    ),
  ];

  int _calculateSelectedIndex(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final index = originalItems.indexWhere((item) => item.key == Key(path));
    return index;
  }

  void _onNavigationItemPressed(BuildContext context, int index) {
    if (index < 0 || index >= originalItems.length) return;

    final key = originalItems[index].key;
    if (key is! ValueKey<String>) return;

    final targetPath = key.value;
    final currentPath = GoRouterState.of(context).uri.path;

    if (currentPath != targetPath) {
      context.go(targetPath);
    }
  }

  @override
  void initState() {
    windowManager.addListener(this);
    super.initState();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NavigationView(
      pane: NavigationPane(
        items: originalItems,
        selected: _calculateSelectedIndex(context),
        displayMode: PaneDisplayMode.compact,
        size: NavigationPaneSize(openMaxWidth: 200),
        onItemPressed: (index) => _onNavigationItemPressed(context, index),
      ),
      paneBodyBuilder: (item, child) {
        return widget.child;
      },
    );
  }
}
