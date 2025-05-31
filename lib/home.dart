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

  late final List<NavigationPaneItem> originalItems =
      [
        PaneItem(
          key: const ValueKey("/"),
          icon: const Icon(FluentIcons.home),
          title: const Text("Home"),
          body: const SizedBox.shrink(),
        ),
      ].map<NavigationPaneItem>((e) {
        PaneItem buildPaneItem(PaneItem item) {
          return PaneItem(
            key: item.key,
            icon: item.icon,
            title: item.title,
            body: item.body,
            onTap: () {
              final path = (item.key as ValueKey<String>).value;
              if (GoRouterState.of(context).uri.path == path) {
                context.go(path);
              }
              item.onTap?.call();
            },
          );
        }

        if (e is PaneItemExpander) {
          return PaneItemExpander(
            key: e.key,
            icon: e.icon,
            title: e.title,
            body: e.body,
            items: e.items.map((item) {
              if (item is PaneItem) return buildPaneItem(item);
              return item;
            }).toList(),
          );
        }

        return buildPaneItem(e);
      }).toList();

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
    return Container(
      color: FluentTheme.of(context).micaBackgroundColor,
      child: widget.child,
    );
  }
}
