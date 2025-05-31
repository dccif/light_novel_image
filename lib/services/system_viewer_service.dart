import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class SystemViewerService {
  static Directory? _tempDir;

  /// 初始化临时目录
  static Future<void> initTempDir() async {
    final tempDir = await getTemporaryDirectory();
    _tempDir = await Directory(
      path.join(tempDir.path, 'epub_viewer'),
    ).create(recursive: true);
  }

  /// 清理临时文件
  static Future<void> cleanupTempFiles() async {
    if (_tempDir != null && await _tempDir!.exists()) {
      try {
        await _tempDir!.delete(recursive: true);
      } catch (e) {
        debugPrint('清理临时文件失败: $e');
      }
    }
  }

  /// 在系统图片查看器中打开图片
  static Future<void> openImageInSystemViewer(
    Uint8List imageData,
    String imageName,
  ) async {
    if (_tempDir == null) {
      await initTempDir();
    }

    try {
      final tempFile = File(path.join(_tempDir!.path, imageName));

      if (!await tempFile.exists()) {
        await tempFile.writeAsBytes(imageData);
      }

      if (Platform.isWindows) {
        await Process.run('explorer.exe', [tempFile.path]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [tempFile.path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [tempFile.path]);
      }
    } catch (e) {
      debugPrint('打开系统图片查看器失败: $e');
    }
  }
}
