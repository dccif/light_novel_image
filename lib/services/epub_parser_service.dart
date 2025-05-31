import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:xml/xml.dart';
import 'package:epub_image/models/book_info.dart';
import 'package:epub_image/models/epub_parse_result.dart';

class EpubParserService {
  static const Set<String> _imageExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.gif',
    '.bmp',
    '.webp',
  };

  /// 安全地将字节转换为UTF-8字符串
  static String _safeDecodeBytes(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } catch (e) {
      // 如果UTF-8解码失败，尝试使用latin1
      try {
        return latin1.decode(bytes);
      } catch (e2) {
        // 最后的后备方案
        return String.fromCharCodes(bytes);
      }
    }
  }

  /// 从单个epub文件提取标题
  static String _extractTitleFromArchive(Archive archive, String filePath) {
    try {
      // 首先尝试在根目录和META-INF目录下查找container.xml
      final containerFile =
          archive.findFile('container.xml') ??
          archive.findFile('META-INF/container.xml');

      if (containerFile != null) {
        final containerContent = _safeDecodeBytes(
          containerFile.content as List<int>,
        );
        final containerDoc = XmlDocument.parse(containerContent);

        // 获取OPF文件路径
        final rootfileElements = containerDoc.findAllElements('rootfile');
        for (final element in rootfileElements) {
          if (element.getAttribute('media-type') ==
              'application/oebps-package+xml') {
            final opfPath = element.getAttribute('full-path');
            if (opfPath != null) {
              final opfFile = archive.findFile(opfPath);
              if (opfFile != null) {
                final opfContent = _safeDecodeBytes(
                  opfFile.content as List<int>,
                );
                final opfDoc = XmlDocument.parse(opfContent);

                // 尝试获取标题
                final titleElements = opfDoc.findAllElements('dc:title');
                if (titleElements.isNotEmpty) {
                  final extractedTitle = titleElements.first.innerText.trim();
                  if (extractedTitle.isNotEmpty) {
                    return extractedTitle;
                  }
                }
              }
            }
          }
        }
      }

      // 如果上述方法失败，直接搜索所有文件中的.opf文件
      for (final file in archive.files) {
        if (file.name.toLowerCase().endsWith('.opf')) {
          final content = _safeDecodeBytes(file.content as List<int>);
          try {
            final doc = XmlDocument.parse(content);
            final titleElements = doc.findAllElements('dc:title');
            if (titleElements.isNotEmpty) {
              final extractedTitle = titleElements.first.innerText.trim();
              if (extractedTitle.isNotEmpty) {
                return extractedTitle;
              }
            }
          } catch (e) {
            continue;
          }
        }
      }
    } catch (e) {
      debugPrint('提取标题时发生错误: $e');
    }

    return path.basenameWithoutExtension(filePath);
  }

  /// 从Archive中提取图片
  static List<MapEntry<Uint8List, String>> _extractImagesFromArchive(
    Archive archive,
  ) {
    final images = <MapEntry<Uint8List, String>>[];

    for (final file in archive) {
      if (file.isFile) {
        final fileName = file.name.toLowerCase();
        if (_imageExtensions.any((ext) => fileName.endsWith(ext))) {
          final content = file.content as List<int>;
          final imageName = file.name.split('/').last;
          images.add(MapEntry(Uint8List.fromList(content), imageName));
        }
      }
    }

    // 按文件名排序
    images.sort((a, b) => a.value.compareTo(b.value));
    return images;
  }

  /// 解析单个EPUB文件
  static Future<MapEntry<BookInfo, List<MapEntry<Uint8List, String>>>>
  _parseSingleEpub(
    String epubPath,
    int bookIndex,
    int currentImageCount,
  ) async {
    try {
      final bytes = await File(epubPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // 提取标题
      final title = _extractTitleFromArchive(archive, epubPath);

      // 提取图片
      final images = _extractImagesFromArchive(archive);

      final bookInfo = BookInfo(
        title: title,
        filePath: epubPath,
        startImageIndex: currentImageCount,
        endImageIndex: currentImageCount + images.length - 1,
      );

      return MapEntry(bookInfo, images);
    } catch (e) {
      debugPrint('解析epub文件失败: $epubPath, 错误: $e');

      // 返回错误信息的书籍
      final errorBookInfo = BookInfo(
        title: '${path.basenameWithoutExtension(epubPath)} (解析失败)',
        filePath: epubPath,
        startImageIndex: currentImageCount,
        endImageIndex: currentImageCount - 1,
      );

      return MapEntry(errorBookInfo, <MapEntry<Uint8List, String>>[]);
    }
  }

  /// 后台解析函数 - 在isolate中运行
  static Future<EpubParseResult> parseMultipleEpubs(
    List<String> epubPaths,
  ) async {
    final books = <BookInfo>[];
    final allImages = <Uint8List>[];
    final allImageNames = <String>[];
    final imageBookIndexes = <int>[];

    for (int bookIndex = 0; bookIndex < epubPaths.length; bookIndex++) {
      final epubPath = epubPaths[bookIndex];
      final result = await _parseSingleEpub(
        epubPath,
        bookIndex,
        allImages.length,
      );

      final bookInfo = result.key;
      final images = result.value;

      books.add(bookInfo);

      // 添加图片到总列表
      for (final imageEntry in images) {
        allImages.add(imageEntry.key);
        allImageNames.add(imageEntry.value);
        imageBookIndexes.add(bookIndex);
      }
    }

    return EpubParseResult(
      books: books,
      allImages: allImages,
      allImageNames: allImageNames,
      imageBookIndexes: imageBookIndexes,
    );
  }
}
