import 'package:epub_image/router.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart' as flutter_acrylic;
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

const String appTitle = "轻小说图片浏览器";

bool get isDesktop {
  if (kIsWeb) return false;
  return [
    TargetPlatform.windows,
    TargetPlatform.linux,
    TargetPlatform.macOS,
  ].contains(defaultTargetPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (isDesktop) {
    await flutter_acrylic.Window.initialize();
    await WindowManager.instance.ensureInitialized();
    final windowOptions = const WindowOptions(
      size: Size(800, 800),
      backgroundColor: Colors.transparent,
      titleBarStyle: TitleBarStyle.normal,
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      windowManager.setTitle(appTitle);
      await windowManager.show();
    });
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FluentApp.router(
      title: appTitle,
      theme: FluentThemeData(fontFamily: "Microsoft YaHei"),
      supportedLocales: const [Locale('zh', 'CN')],
      routerConfig: router,
    );
  }
}
