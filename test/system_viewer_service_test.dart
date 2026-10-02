import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:light_novel_image/services/system_viewer_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('导出单飞、不同完整图片 ID 不覆盖，导出不依赖导入目录', () async {
    final root = await Directory.systemTemp.createTemp('epub_export_test_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => root.path);
    try {
      final old = await Directory(
        '${root.path}/epub_viewer_exports/session_old',
      ).create(recursive: true);
      final oldFile = await File('${old.path}/kept.png').writeAsBytes([0]);
      final bytes = Uint8List.fromList([1, 2, 3]);
      final first = SystemViewerService.prepareImageFile(
        bytes,
        'a.png',
        'book/Images/a.png',
      );
      final concurrent = SystemViewerService.prepareImageFile(
        bytes,
        'a.png',
        'book/Images/a.png',
      );
      expect(first, same(concurrent));
      final one = await first;
      final two = await SystemViewerService.prepareImageFile(
        Uint8List.fromList([4]),
        'a.png',
        'book/Other/a.png',
      );
      expect(one, isNot(two));
      expect(await File(one).readAsBytes(), [1, 2, 3]);
      expect(await File(two).readAsBytes(), [4]);
      expect(await oldFile.exists(), isTrue);
      final importDirectory = await Directory('${root.path}/import_session')
          .create();
      await importDirectory.delete();
      expect(await File(one).exists(), isTrue);
    } finally {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      await root.delete(recursive: true);
    }
  });
}
