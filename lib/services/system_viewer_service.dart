import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

class SystemViewerService {
  static Future<Directory>? _directory;
  static final _exports = <String, Future<String>>{};
  static final _exporting = <String>{};
  static int _nextFile = 0;

  /// 导出会话与导入缓存隔离。离开页面不删除剪贴板或外部应用仍在引用的文件。
  static Future<Directory> _exportDirectory() =>
      _directory ??= _createExportDirectory();

  static Future<Directory> _createExportDirectory() async {
    final temp = await getTemporaryDirectory();
    final root = await Directory(path.join(temp.path, 'epub_viewer_exports'))
        .create(recursive: true);
    // 只清理应用自建目录下、七天前的会话；不跟随符号链接。
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    await for (final entity in root.list(followLinks: false)) {
      if (entity is! Directory ||
          !path.basename(entity.path).startsWith('session_')) {
        continue;
      }
      if (!path.isWithin(root.path, entity.path)) continue;
      try {
        if ((await entity.stat()).modified.isBefore(cutoff)) {
          await entity.delete(recursive: true);
        }
      } catch (error) {
        debugPrint('过期导出文件清理失败: $error');
      }
    }
    return root.createTemp('session_');
  }

  static Future<String> prepareImageFile(
    Uint8List imageData,
    String imageName, [
    String? bookIdentifier,
  ]) {
    final key = bookIdentifier ?? imageName;
    final existing = _exports.remove(key);
    if (existing != null) {
      _exports[key] = existing;
      return existing;
    }
    // 只保留最近的路径映射；落盘导出仍按七天保留，避免破坏剪贴板引用。
    _pruneExportPaths();
    _exporting.add(key);
    return _exports.putIfAbsent(
      key,
      () => _writeExport(imageData, imageName, key),
    );
  }

  static void _pruneExportPaths() {
    for (final key in _exports.keys.toList()) {
      if (_exports.length < 128) break;
      if (!_exporting.contains(key)) _exports.remove(key);
    }
  }

  static Future<String> _writeExport(
    Uint8List data,
    String imageName,
    String key,
  ) async {
    try {
      final directory = await _exportDirectory();
      final safeName = path
          .basename(imageName)
          .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final file = File(path.join(directory.path, '${_nextFile++}_$safeName'));
      await file.writeAsBytes(data, flush: true);
      return file.path;
    } catch (_) {
      _exports.remove(key);
      _directory = null;
      rethrow;
    } finally {
      _exporting.remove(key);
      _pruneExportPaths();
    }
  }

  static Future<void> _backgroundWindow() async {
    if (kIsWeb) return;
    try {
      await windowManager.setAlwaysOnTop(false);
      await windowManager.blur();
    } catch (error) {
      debugPrint('窗口后置失败: $error');
    }
  }

  /// 复制文件到剪贴板
  static Future<void> copyFileToClipboard(
    Uint8List imageData,
    String imageName, [
    String? bookIdentifier,
  ]) async {
    try {
      final tempFilePath = await prepareImageFile(
        imageData,
        imageName,
        bookIdentifier,
      );

      if (Platform.isWindows) {
        // Windows: 使用 PowerShell 复制文件到剪贴板
        final result = await Process.run('powershell', [
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          "Set-Clipboard -LiteralPath '${tempFilePath.replaceAll("'", "''")}'",
        ]);

        if (result.exitCode == 0) {
          debugPrint('文件已复制到剪贴板: $imageName');
        } else {
          throw Exception('PowerShell 复制失败: ${result.stderr}');
        }
      } else if (Platform.isMacOS) {
        // macOS: 使用 osascript 复制图片到剪贴板
        final result = await Process.run('osascript', [
          '-e',
          'set the clipboard to (read (POSIX file "$tempFilePath") as JPEG picture)',
        ]);

        if (result.exitCode == 0) {
          debugPrint('文件已复制到剪贴板: $imageName');
        } else {
          throw Exception('macOS 复制失败: ${result.stderr}');
        }
      } else if (Platform.isLinux) {
        // Linux: 使用 xclip (需要安装)
        final result = await Process.run('xclip', [
          '-selection',
          'clipboard',
          '-t',
          'image/png',
          '-i',
          tempFilePath,
        ]);

        if (result.exitCode == 0) {
          debugPrint('文件已复制到剪贴板: $imageName');
        } else {
          throw Exception('Linux 复制失败: ${result.stderr}');
        }
      }
    } catch (e) {
      debugPrint('复制文件到剪贴板失败: $e');
      rethrow;
    }
  }

  /// 在系统图片查看器中打开图片（默认应用）
  static Future<void> openImageInSystemViewer(
    Uint8List imageData,
    String imageName, [
    String? bookIdentifier,
  ]) async {
    try {
      final tempFilePath = await prepareImageFile(
        imageData,
        imageName,
        bookIdentifier,
      );

      await _backgroundWindow();

      if (Platform.isWindows) {
        await Process.run('explorer.exe', [tempFilePath]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [tempFilePath]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [tempFilePath]);
      }

      debugPrint('已在系统查看器中打开: $imageName');
    } catch (e) {
      debugPrint('打开系统图片查看器失败: $e');
      rethrow;
    }
  }

  /// 显示"打开方式"对话框
  static Future<void> openImageWithDialog(
    Uint8List imageData,
    String imageName, [
    String? bookIdentifier,
  ]) async {
    try {
      final tempFilePath = await prepareImageFile(
        imageData,
        imageName,
        bookIdentifier,
      );

      await _backgroundWindow();

      if (Platform.isWindows) {
        // Windows: 使用 rundll32 显示"打开方式"对话框
        await Process.run('rundll32.exe', [
          'shell32.dll,OpenAs_RunDLL',
          tempFilePath,
        ]);
      } else if (Platform.isMacOS) {
        // macOS: 使用AppleScript显示应用程序选择器对话框
        final script =
            '''
          tell application "Finder"
            activate
            open POSIX file "$tempFilePath" with prompt
          end tell
        ''';
        await Process.run('osascript', ['-e', script]);
      } else if (Platform.isLinux) {
        // Linux: 尝试不同的方法
        try {
          // 首先尝试使用 mimeopen
          await Process.run('mimeopen', ['-a', tempFilePath]);
        } catch (e) {
          // 如果失败，回退到默认打开
          await Process.run('xdg-open', [tempFilePath]);
        }
      }

      debugPrint('已显示打开方式对话框: $imageName');
    } catch (e) {
      debugPrint('显示打开方式对话框失败: $e');
      // 如果失败，回退到默认打开方式
      await openImageInSystemViewer(imageData, imageName, bookIdentifier);
    }
  }
}
