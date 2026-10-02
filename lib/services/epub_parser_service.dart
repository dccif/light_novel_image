import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:light_novel_image/models/image_entry.dart';
import 'package:light_novel_image/services/image_resolution_service.dart';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:light_novel_image/models/book_info.dart';
import 'package:light_novel_image/models/epub_parse_result.dart';
import 'package:light_novel_image/models/image_context.dart';
import 'package:light_novel_image/models/image_resolution.dart';
import 'package:path/path.dart' as path;
import 'package:xml/xml.dart';

class EpubParserService {
  static const Set<String> _imageExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.gif',
    '.bmp',
    '.webp',
  };

  static const Set<String> _contentExtensions = {'.xhtml', '.html', '.htm'};

  /// 安全地将 EPUB 中可能使用不同编码的文本转换为字符串。
  static String _safeDecodeBytes(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      try {
        return latin1.decode(bytes);
      } catch (_) {
        return String.fromCharCodes(bytes);
      }
    }
  }

  static String _normalizeArchivePath(String value) {
    final withoutFragment = value.split('#').first.split('?').first;
    return path.posix.normalize(withoutFragment.replaceAll('\\', '/'));
  }

  static String _resolveArchivePath(String value, String basePath) {
    value = value.split('#').first.split('?').first;
    try {
      value = Uri.decodeComponent(value);
    } on FormatException {
      /* 保留非 URI 的路径 */
    }
    if (value.startsWith('/')) return _normalizeArchivePath(value.substring(1));
    if (value.startsWith('/') || value.contains('://')) {
      return _normalizeArchivePath(value);
    }
    return _normalizeArchivePath(
      path.posix.join(path.posix.dirname(basePath), value),
    );
  }

  static ArchiveFile? _findArchiveFile(
    Map<String, ArchiveFile> archive,
    String archivePath,
  ) => archive[_normalizeArchivePath(archivePath).toLowerCase()];

  static XmlDocument? _parseXmlFile(ArchiveFile? file) {
    if (file == null) return null;
    try {
      return XmlDocument.parse(_safeDecodeBytes(file.content as List<int>));
    } catch (_) {
      return null;
    }
  }

  static String? _locateOpfPath(Map<String, ArchiveFile> archive) {
    final container = _parseXmlFile(
      _findArchiveFile(archive, 'META-INF/container.xml'),
    );
    if (container != null) {
      final rootFile = container.findAllElements('rootfile').firstOrNull;
      final fullPath = rootFile?.getAttribute('full-path');
      if (fullPath != null && fullPath.isNotEmpty) {
        return _normalizeArchivePath(fullPath);
      }
    }

    for (final file in archive.values) {
      if (file.isFile && file.name.toLowerCase().endsWith('.opf')) {
        return _normalizeArchivePath(file.name);
      }
    }
    return null;
  }

  static Map<String, String> _extractManifest(XmlDocument opf, String opfPath) {
    final manifest = <String, String>{};
    for (final item in opf.findAllElements('item')) {
      final id = item.getAttribute('id');
      final href = item.getAttribute('href');
      if (id != null && id.isNotEmpty && href != null && href.isNotEmpty) {
        manifest[id] = _resolveArchivePath(href, opfPath);
      }
    }
    return manifest;
  }

  static Map<String, String> _extractTocTitles(
    Map<String, ArchiveFile> archive,
    XmlDocument opf,
    String opfPath,
    Map<String, String> manifest,
  ) {
    final titles = <String, String>{};
    final spineTocId = opf
        .findAllElements('spine')
        .firstOrNull
        ?.getAttribute('toc');
    String? tocPath = spineTocId == null ? null : manifest[spineTocId];
    tocPath ??= _findNavigationPath(opf, manifest);
    if (tocPath == null) return titles;

    final toc = _parseXmlFile(_findArchiveFile(archive, tocPath));
    if (toc == null) return titles;

    for (final navPoint in toc.findAllElements('navPoint')) {
      final source = navPoint
          .findAllElements('content')
          .firstOrNull
          ?.getAttribute('src');
      final title = navPoint
          .findAllElements('text')
          .firstOrNull
          ?.innerText
          .trim();
      if (source != null && title != null && title.isNotEmpty) {
        titles.putIfAbsent(_resolveArchivePath(source, tocPath), () => title);
      }
    }

    // EPUB 3 的导航文件使用 <a> 元素而不是 NCX navPoint。
    for (final link in toc.findAllElements('a')) {
      final href = link.getAttribute('href');
      final title = link.innerText.trim();
      if (href != null && title.isNotEmpty) {
        titles.putIfAbsent(_resolveArchivePath(href, tocPath), () => title);
      }
    }
    return titles;
  }

  static String? _findNavigationPath(
    XmlDocument opf,
    Map<String, String> manifest,
  ) {
    for (final item in opf.findAllElements('item')) {
      final id = item.getAttribute('id');
      final properties = item.getAttribute('properties') ?? '';
      final mediaType = item.getAttribute('media-type') ?? '';
      if (properties.split(RegExp(r'\s+')).contains('nav') ||
          mediaType == 'application/x-dtbncx+xml' ||
          (id?.toLowerCase().contains('ncx') ?? false)) {
        return id == null ? null : manifest[id];
      }
    }
    return null;
  }

  static List<String> _extractSpine(
    XmlDocument opf,
    Map<String, String> manifest,
  ) {
    final spine = <String>[];
    for (final itemRef in opf.findAllElements('itemref')) {
      final path = manifest[itemRef.getAttribute('idref')];
      if (path != null) spine.add(path);
    }
    return spine;
  }

  static String _chapterTitle(
    XmlDocument document,
    String contentPath,
    Map<String, String> tocTitles,
    int chapterOrder,
  ) {
    final tocTitle = tocTitles[_normalizeArchivePath(contentPath)];
    if (tocTitle != null && tocTitle.isNotEmpty) return tocTitle;

    final title = document
        .findAllElements('title')
        .firstOrNull
        ?.innerText
        .trim();
    if (title != null && title.isNotEmpty) return title;

    for (final heading in ['h1', 'h2', 'h3']) {
      final text = document
          .findAllElements(heading)
          .firstOrNull
          ?.innerText
          .trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return '第 $chapterOrder 章';
  }

  /// 每个文档只遍历一次，同时生成纯文本和全部图片的精确偏移。
  static _ChapterText _readChapter(XmlDocument document, String contentPath) {
    final text = _TextBuilder();
    final positions = <String, int>{};
    void visit(XmlNode node) {
      if (node is XmlText) {
        text.write(node.value);
      } else if (node is XmlElement) {
        final tag = node.name.local.toLowerCase();
        if (const {'head', 'script', 'style'}.contains(tag)) return;
        final block = const {
          'p',
          'div',
          'br',
          'li',
          'blockquote',
          'section',
          'h1',
          'h2',
          'h3',
          'h4',
          'h5',
          'h6',
          'tr',
        }.contains(tag);
        if (block) text.breakParagraph();
        if (tag == 'img' || tag == 'image') {
          final source =
              node.getAttribute('src') ??
              node.attributes
                  .where((a) => a.name.local == 'href')
                  .firstOrNull
                  ?.value;
          if (source != null &&
              source.isNotEmpty &&
              !source.startsWith('data:')) {
            positions.putIfAbsent(
              _resolveArchivePath(source, contentPath),
              () => text.length,
            );
          }
        }
        for (final child in node.children) {
          visit(child);
        }
        if (block) text.breakParagraph();
      } else {
        for (final child in node.children) {
          visit(child);
        }
      }
    }

    visit(document);
    return _ChapterText(text.toString(), positions);
  }

  @visibleForTesting
  static Map<String, ImageContext> extractImageContextsFromContent({
    required String contentPath,
    required String content,
    required String chapterTitle,
    required int chapterOrder,
  }) {
    try {
      final chapter = _readChapter(XmlDocument.parse(content), contentPath);
      if (chapter.content.length < 12) return const {};
      final document = BookText(chapter.content);
      return chapter.positions.map(
        (key, offset) => MapEntry(
          key,
          ImageContext(
            chapterTitle: chapterTitle,
            chapterOrder: chapterOrder,
            content: chapter.content,
            imageOffset: offset,
            document: document,
          ),
        ),
      );
    } catch (_) {
      return const {};
    }
  }

  static Map<String, ImageContext> _extractImageContexts(
    Map<String, ArchiveFile> archive,
    XmlDocument? opf,
    String? opfPath,
  ) {
    if (opf == null || opfPath == null) return const {};
    final manifest = _extractManifest(opf, opfPath);
    final titles = _extractTocTitles(archive, opf, opfPath, manifest);
    final spine = _extractSpine(opf, manifest);
    final locations = <String, _ImageLocation>{};
    final content = StringBuffer();
    for (var i = 0; i < spine.length; i++) {
      final contentPath = spine[i];
      if (!_contentExtensions.contains(
        path.posix.extension(contentPath).toLowerCase(),
      )) {
        continue;
      }
      final file = _findArchiveFile(archive, contentPath);
      final xml = _parseXmlFile(file);
      if (xml == null) continue;
      final chapter = _readChapter(xml, contentPath);
      file?.clear();
      if (chapter.content.isEmpty) continue;
      final title = _chapterTitle(xml, contentPath, titles, i + 1);
      if (content.isNotEmpty) content.write('\n\n');
      content.write(title);
      content.write('\n\n');
      final base = content.length;
      content.write(chapter.content);
      if (chapter.content.length >= 12) {
        for (final entry in chapter.positions.entries) {
          locations.putIfAbsent(
            entry.key,
            () => _ImageLocation(
              chapterTitle: title,
              chapterOrder: i + 1,
              imageOffset: base + entry.value,
            ),
          );
        }
      }
    }
    final fullText = content.toString();
    final document = BookText(fullText);
    return locations.map(
      (key, location) => MapEntry(
        key,
        ImageContext(
          chapterTitle: location.chapterTitle,
          chapterOrder: location.chapterOrder,
          content: fullText,
          imageOffset: location.imageOffset,
          document: document,
        ),
      ),
    );
  }

  /// 在同一个 isolate 内流式解包、读取正文和图片尺寸。
  static Future<EpubParseResult> parseMultipleEpubs(
    EpubImportRequest request,
  ) async {
    final books = <BookInfo>[];
    final images = <ImageEntry>[];
    var remainingMemory = request.memoryBudget;
    for (var bookIndex = 0; bookIndex < request.paths.length; bookIndex++) {
      final epubPath = request.paths[bookIndex];
      final start = images.length;
      InputFileStream? input;
      var title = path.basenameWithoutExtension(epubPath);
      try {
        input = InputFileStream(epubPath);
        final zip = ZipDecoder().decodeStream(input);
        final archive = {
          for (final file in zip.files)
            _normalizeArchivePath(file.name).toLowerCase(): file,
        };
        final opfPath = _locateOpfPath(archive);
        final opf = opfPath == null
            ? null
            : _parseXmlFile(_findArchiveFile(archive, opfPath));
        final opfTitle = opf
            ?.findAllElements('title')
            .firstOrNull
            ?.innerText
            .trim();
        if (opfTitle != null && opfTitle.isNotEmpty) title = opfTitle;
        final contexts = _extractImageContexts(archive, opf, opfPath);
        final fallbackContexts = {
          for (final entry in contexts.entries)
            entry.key.toLowerCase(): entry.value,
        };
        final files =
            zip.files
                .where(
                  (file) =>
                      file.isFile &&
                      _imageExtensions.contains(
                        path.posix.extension(file.name).toLowerCase(),
                      ),
                )
                .toList()
              ..sort((a, b) => a.name.compareTo(b.name));
        // 小书保留原始 Uint8List；总内存预算不足时，整本书落盘。
        final keepInMemory =
            files.fold<int>(0, (sum, f) => sum + f.size) <= remainingMemory;
        final bookImages = <ImageEntry>[];
        for (var i = 0; i < files.length; i++) {
          final file = files[i];
          final archivePath = _normalizeArchivePath(file.name);
          Uint8List? bytes;
          String? filePath;
          ImageResolution resolution;
          if (keepInMemory) {
            bytes = file.content;
            resolution = ImageResolutionService.getImageResolution(bytes);
          } else {
            // 文件名不采用 EPUB 路径，防止 Zip Slip 和同名图片覆盖。
            filePath = path.join(
              request.cacheDirectory,
              '${bookIndex}_$i${path.posix.extension(archivePath)}',
            );
            final output = OutputFileStream(filePath);
            try {
              file.writeContent(output);
            } finally {
              output.closeSync();
            }
            resolution = ImageResolutionService.getFileResolution(
              File(filePath),
            );
          }
          file.clear();
          bookImages.add(
            ImageEntry(
              id: '${request.cacheDirectory}|$bookIndex|$archivePath',
              archivePath: archivePath,
              name: path.posix.basename(archivePath),
              bookIndex: bookIndex,
              resolution: resolution,
              context:
                  contexts[archivePath] ??
                  fallbackContexts[archivePath.toLowerCase()],
              bytes: bytes,
              filePath: filePath,
            ),
          );
        }
        images.addAll(bookImages);
        if (keepInMemory) {
          remainingMemory -= bookImages.fold<int>(
            0,
            (sum, image) => sum + image.bytes!.length,
          );
        }
      } catch (error) {
        debugPrint('解析 EPUB 失败: $epubPath: $error');
        title = '$title (解析失败)';
      } finally {
        input?.closeSync();
      }
      books.add(
        BookInfo(
          title: title,
          filePath: epubPath,
          startImageIndex: start,
          endImageIndex: images.length - 1,
        ),
      );
    }
    return EpubParseResult(
      books: books,
      images: images,
      resolutionStatistics: calculateResolutionStatistics(
        images.map((e) => e.resolution).toList(),
      ),
    );
  }

  /// 统计分辨率信息（在主线程中调用）。
  static ResolutionStatistics calculateResolutionStatistics(
    List<ImageResolution> resolutions,
  ) {
    final resolutionCounts = <ImageResolution, int>{};
    var maxWidth = 0;
    var maxHeight = 0;
    for (final resolution in resolutions) {
      resolutionCounts[resolution] = (resolutionCounts[resolution] ?? 0) + 1;
      maxWidth = maxWidth < resolution.width ? resolution.width : maxWidth;
      maxHeight = maxHeight < resolution.height ? resolution.height : maxHeight;
    }
    if (resolutionCounts.isEmpty) {
      return const ResolutionStatistics(
        resolutionCounts: {},
        mostCommonResolution: null,
        mostCommonResolutionCount: 0,
        maxWidth: 800,
        maxHeight: 600,
      );
    }
    final mostCommon = resolutionCounts.entries.reduce(
      (current, next) => current.value >= next.value ? current : next,
    );
    return ResolutionStatistics(
      resolutionCounts: resolutionCounts,
      mostCommonResolution: mostCommon.key,
      mostCommonResolutionCount: mostCommon.value,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
  }
}

class _ChapterText {
  final String content;
  final Map<String, int> positions;
  const _ChapterText(this.content, this.positions);
}

/// 段落分隔和空白延迟写入，图片偏移始终对应已写入的正文。
class _TextBuilder {
  static final _whitespace = RegExp(r'\s+');
  final _buffer = StringBuffer();
  String _pending = '';
  int get length => _buffer.length;
  void breakParagraph() {
    if (_buffer.isNotEmpty) _pending = '\n\n';
  }

  void write(String value) {
    final normalized = value.replaceAll(_whitespace, ' ');
    final text = normalized.trim();
    if (text.isEmpty) {
      if (_buffer.isNotEmpty && _pending.isEmpty) _pending = ' ';
      return;
    }
    if (_buffer.isNotEmpty) {
      if (_pending.isEmpty && normalized.startsWith(' ')) _pending = ' ';
      _buffer.write(_pending);
    }
    _pending = normalized.endsWith(' ') ? ' ' : '';
    _buffer.write(text);
  }

  @override
  String toString() => _buffer.toString();
}

class _ImageLocation {
  final String chapterTitle;
  final int chapterOrder;
  final int imageOffset;
  const _ImageLocation({
    required this.chapterTitle,
    required this.chapterOrder,
    required this.imageOffset,
  });
}
