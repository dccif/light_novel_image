import 'package:epub_image/home.dart';
import 'package:epub_image/widgets/home_page.dart';
import 'package:epub_image/widgets/epub_viewer_page.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:go_router/go_router.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final router = GoRouter(
  navigatorKey: rootNavigatorKey,
  routes: [
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return MyHomePage(shellContext: context, child: child);
      },
      routes: <GoRoute>[
        GoRoute(path: '/', builder: (context, state) => const HomePage()),
        GoRoute(
          path: '/epub-viewer',
          builder: (context, state) {
            // 安全地转换类型：先获取dynamic列表，然后转换为String列表
            final extraData = state.extra;
            List<String>? epubPaths;

            if (extraData is List) {
              epubPaths = extraData.map((e) => e.toString()).toList();
            }

            if (epubPaths == null || epubPaths.isEmpty) {
              return const Center(child: Text('缺少epub文件路径'));
            }

            return EpubViewerPage(epubPaths: epubPaths);
          },
        ),
      ],
    ),
  ],
);
