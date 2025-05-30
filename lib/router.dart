import 'package:epub_image/home.dart';
import 'package:epub_image/widges/home_page.dart';
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
      ],
    ),
  ],
);
