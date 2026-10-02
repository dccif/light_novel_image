import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:light_novel_image/widgets/home_page.dart';

class _Picker extends FilePickerPlatform {
  List<PlatformFile> files = [];
  int calls = 0;

  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    calls++;
    expect(type, FileType.custom);
    expect(allowedExtensions, ['epub']);
    return files;
  }
}

final class _PickedFile extends PlatformFile {
  _PickedFile(this.name);

  @override
  final String name;

  @override
  Uri get uri => Uri.file('C:/books/$name');

  @override
  XFile get xFile => XFile(path!);

  @override
  int lengthSync() => 0;

  @override
  Future<int?> length() async => 0;

  @override
  Future<Uint8List> readAsBytes() async => Uint8List(0);

  @override
  Stream<Uint8List> readAsByteStream() => const Stream.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FilePickerPlatform originalPicker;
  late _Picker picker;
  late GoRouter router;
  Object? openedFiles;

  setUp(() {
    originalPicker = FilePickerPlatform.instance;
    picker = _Picker();
    FilePickerPlatform.instance = picker;
    openedFiles = null;
    router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const HomePage()),
        GoRoute(
          path: '/epub-viewer',
          builder: (_, state) {
            openedFiles = state.extra;
            return const Text('阅读器');
          },
        ),
      ],
    );
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('window_manager'),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('desktop_drop'),
      (_) async => true,
    );
  });

  tearDown(() {
    router.dispose();
    FilePickerPlatform.instance = originalPicker;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('window_manager'),
      null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('desktop_drop'),
      null,
    );
  });

  testWidgets('取消文件选择时保留首页', (tester) async {
    await tester.pumpWidget(FluentApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('或点击选择文件'));
    await tester.pumpAndSettle();

    expect(picker.calls, 1);
    expect(openedFiles, isNull);
    expect(find.byType(HomePage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('多选 EPUB 后将所有路径传给阅读器', (tester) async {
    picker.files = [_PickedFile('first.epub'), _PickedFile('second.EPUB')];
    await tester.pumpWidget(FluentApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('或点击选择文件'));
    await tester.pumpAndSettle();

    expect(picker.calls, 1);
    expect(openedFiles, picker.files.map((file) => file.path).toList());
    expect(find.text('阅读器'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
