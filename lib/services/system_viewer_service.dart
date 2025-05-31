import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

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

  /// 获取临时文件路径
  static Future<String> _getTempFilePath(
    String imageName, [
    String? bookIdentifier,
  ]) async {
    if (_tempDir == null) {
      await initTempDir();
    }

    // 如果提供了书籍标识符，添加到文件名前面
    String fileName = imageName;
    if (bookIdentifier != null && bookIdentifier.isNotEmpty) {
      // 清理书籍标识符，移除不合法的文件名字符
      final cleanBookId = bookIdentifier
          .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
          .replaceAll(RegExp(r'\s+'), '_');
      fileName = '${cleanBookId}_$imageName';
    }

    return path.join(_tempDir!.path, fileName);
  }

  /// 确保临时文件存在
  static Future<String> _ensureTempFileExists(
    Uint8List imageData,
    String imageName, [
    String? bookIdentifier,
  ]) async {
    final tempFilePath = await _getTempFilePath(imageName, bookIdentifier);
    final tempFile = File(tempFilePath);

    if (!await tempFile.exists()) {
      await tempFile.writeAsBytes(imageData);
    }

    return tempFilePath;
  }

  /// 复制文件到剪贴板
  static Future<void> copyFileToClipboard(
    Uint8List imageData,
    String imageName, [
    String? bookIdentifier,
  ]) async {
    try {
      final tempFilePath = await _ensureTempFileExists(
        imageData,
        imageName,
        bookIdentifier,
      );

      if (Platform.isWindows) {
        // Windows: 使用 PowerShell 复制文件到剪贴板
        final result = await Process.run('powershell', [
          '-Command',
          'Set-Clipboard -Path "$tempFilePath"',
        ]);

        if (result.exitCode == 0) {
          debugPrint('文件已复制到剪贴板: $imageName');
        } else {
          throw Exception('PowerShell 复制失败: ${result.stderr}');
        }
      } else if (Platform.isMacOS) {
        // macOS: 使用 pbcopy
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
      final tempFilePath = await _ensureTempFileExists(
        imageData,
        imageName,
        bookIdentifier,
      );

      // 在调用外部应用之前，强制让当前窗口后置
      if (!kIsWeb) {
        try {
          // 先确保窗口不在最顶层
          await windowManager.setAlwaysOnTop(false);

          // 让窗口失去焦点并后置
          await windowManager.blur();
        } catch (e) {
          debugPrint('窗口后置失败: $e');
        }
      }

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
      final tempFilePath = await _ensureTempFileExists(
        imageData,
        imageName,
        bookIdentifier,
      );

      // 在调用外部应用之前，强制让当前窗口后置
      if (!kIsWeb) {
        try {
          // 先确保窗口不在最顶层
          await windowManager.setAlwaysOnTop(false);

          // 让窗口失去焦点并后置
          await windowManager.blur();
        } catch (e) {
          debugPrint('窗口后置失败: $e');
        }
      }

      if (Platform.isWindows) {
        // Windows: 使用 rundll32 显示"打开方式"对话框
        await Process.run('rundll32.exe', [
          'shell32.dll,OpenAs_RunDLL',
          tempFilePath,
        ]);
      } else if (Platform.isMacOS) {
        // macOS: 显示选择应用程序对话框
        await Process.run('open', ['-a', 'Finder', tempFilePath]);
        // 或者使用 open 命令的选择器
        // await Process.run('open', ['-R', tempFilePath]);
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
