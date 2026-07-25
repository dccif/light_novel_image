import 'dart:convert';
import 'dart:io';

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
    if (value.startsWith('/') || value.contains('://')) {
      return _normalizeArchivePath(value);
    }
    return _normalizeArchivePath(
      path.posix.join(path.posix.dirname(basePath), value),
    );
  }

  static ArchiveFile? _findArchiveFile(Archive archive, String archivePath) {
    final normalizedPath = _normalizeArchivePath(archivePath).toLowerCase();
    for (final file in archive.files) {
      if (_normalizeArchivePath(file.name).toLowerCase() == normalizedPath) {
        return file;
      }
    }
    return null;
  }

  static XmlDocument? _parseXmlFile(ArchiveFile? file) {
    if (file == null) return null;
    try {
      return XmlDocument.parse(_safeDecodeBytes(file.content as List<int>));
    } catch (_) {
      return null;
    }
  }

  static String? _locateOpfPath(Archive archive) {
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

    for (final file in archive.files) {
      if (file.isFile && file.name.toLowerCase().endsWith('.opf')) {
        return _normalizeArchivePath(file.name);
      }
    }
    return null;
  }

  static String _extractTitleFromArchive(Archive archive, String filePath) {
    final opfPath = _locateOpfPath(archive);
    final opf = opfPath == null
        ? null
        : _parseXmlFile(_findArchiveFile(archive, opfPath));
    final title = opf?.findAllElements('title').firstOrNull?.innerText.trim();
    return title == null || title.isEmpty
        ? path.basenameWithoutExtension(filePath)
        : title;
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
    Archive archive,
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

  static String _htmlToText(String markup) {
    var text = markup
        .replaceAll(
          RegExp(r'<(script|style)\b[^>]*>[\s\S]*?</\1>', caseSensitive: false),
          '',
        )
        .replaceAll(
          RegExp(
            r'<\s*/?\s*(p|div|br|li|h[1-6]|blockquote|section)\b[^>]*>',
            caseSensitive: false,
          ),
          '\n',
        )
        .replaceAll(RegExp(r'<[^>]+>'), '');
    const entities = {
      '&nbsp;': ' ',
      '&amp;': '&',
      '&lt;': '<',
      '&gt;': '>',
      '&quot;': '"',
      '&#39;': "'",
    };
    for (final entry in entities.entries) {
      text = text.replaceAll(entry.key, entry.value);
    }
    return text
        .split(RegExp(r'\r?\n'))
        .map(
          (line) => line
              .split(RegExp(r'\s+'))
              .where((part) => part.isNotEmpty)
              .join(' '),
        )
        .where((line) => line.isNotEmpty)
        .join('\n\n')
        .trim();
  }

  static _ImagePositionedText? _fullTextWithImagePosition(
    String markup,
    String imageReference,
  ) {
    final index = markup.indexOf(imageReference);
    if (index < 0) return null;

    final tagStart = markup.lastIndexOf('<', index);
    final tagEnd = markup.indexOf('>', index + imageReference.length);
    if (tagStart < 0 || tagEnd < 0) return null;

    // 与完整章节使用同一份纯文本转换，确保在整本书正文中定位时偏移量
    // 不会因图片占位符额外引入的换行而漂移。
    final content = _htmlToText(markup);
    final imageOffset = _htmlToText(markup.substring(0, tagStart)).length;
    return _ImagePositionedText(
      content: content,
      imageOffset: imageOffset.clamp(0, content.length),
    );
  }

  /// 从一个 XHTML 内容文件中提取图片旁的正文。
  ///
  /// 返回键为 EPUB 内的规范化图片路径；纯图片页会返回空映射。
  @visibleForTesting
  static Map<String, ImageContext> extractImageContextsFromContent({
    required String contentPath,
    required String content,
    required String chapterTitle,
    required int chapterOrder,
  }) {
    XmlDocument document;
    try {
      document = XmlDocument.parse(content);
    } catch (_) {
      return const {};
    }

    final contexts = <String, ImageContext>{};
    for (final tagName in ['img', 'image']) {
      for (final image in document.findAllElements(tagName)) {
        final source = image.getAttribute('src') ?? image.getAttribute('href');
        if (source == null || source.isEmpty || source.startsWith('data:')) {
          continue;
        }
        final positionedText = _fullTextWithImagePosition(content, source);
        // 过滤只有装饰性标题或空白的图片页，避免连续彩图显示面板。
        if (positionedText == null || positionedText.content.length < 12) {
          continue;
        }
        contexts.putIfAbsent(
          _resolveArchivePath(source, contentPath),
          () => ImageContext(
            chapterTitle: chapterTitle,
            chapterOrder: chapterOrder,
            content: positionedText.content,
            imageOffset: positionedText.imageOffset,
          ),
        );
      }
    }
    return contexts;
  }

  static Map<String, ImageContext> _extractImageContexts(
    Archive archive,
    String? opfPath,
  ) {
    if (opfPath == null) return const {};
    final opf = _parseXmlFile(_findArchiveFile(archive, opfPath));
    if (opf == null) return const {};

    final manifest = _extractManifest(opf, opfPath);
    final tocTitles = _extractTocTitles(archive, opf, opfPath, manifest);
    final imageLocations = <String, _ImageLocation>{};
    final bookContent = StringBuffer();
    final spine = _extractSpine(opf, manifest);

    for (var index = 0; index < spine.length; index++) {
      final contentPath = spine[index];
      if (!_contentExtensions.contains(
        path.posix.extension(contentPath).toLowerCase(),
      )) {
        continue;
      }
      final contentFile = _findArchiveFile(archive, contentPath);
      final content = contentFile == null
          ? null
          : _safeDecodeBytes(contentFile.content as List<int>);
      if (content == null) continue;
      final document = _parseXmlFile(contentFile);
      if (document == null) continue;

      final chapterTitle = _chapterTitle(
        document,
        contentPath,
        tocTitles,
        index + 1,
      );
      final chapterContexts = extractImageContextsFromContent(
        contentPath: contentPath,
        content: content,
        chapterTitle: chapterTitle,
        chapterOrder: index + 1,
      );

      // 保存完整 spine 正文。打开图片后，用户可从当前位置继续上下阅读整本书。
      final chapterText = _htmlToText(content);
      if (chapterText.isEmpty) continue;
      if (bookContent.isNotEmpty) bookContent.write('\n\n\n');
      bookContent.write(chapterTitle);
      bookContent.write('\n\n');
      final chapterTextOffset = bookContent.length;
      bookContent.write(chapterText);

      for (final entry in chapterContexts.entries) {
        imageLocations.putIfAbsent(
          entry.key,
          () => _ImageLocation(
            chapterTitle: entry.value.chapterTitle,
            chapterOrder: entry.value.chapterOrder,
            imageOffset: chapterTextOffset + entry.value.imageOffset,
          ),
        );
      }
    }

    final fullBookContent = bookContent.toString().trim();
    if (fullBookContent.isEmpty) return const {};
    return imageLocations.map(
      (imagePath, location) => MapEntry(
        imagePath,
        ImageContext(
          chapterTitle: location.chapterTitle,
          chapterOrder: location.chapterOrder,
          content: fullBookContent,
          imageOffset: location.imageOffset.clamp(0, fullBookContent.length),
        ),
      ),
    );
  }

  static List<_ExtractedImage> _extractImagesFromArchive(Archive archive) {
    final images = <_ExtractedImage>[];
    for (final file in archive.files) {
      final fileName = file.name.toLowerCase();
      if (file.isFile && _imageExtensions.any(fileName.endsWith)) {
        images.add(
          _ExtractedImage(
            bytes: Uint8List.fromList(file.content as List<int>),
            archivePath: _normalizeArchivePath(file.name),
            displayName: path.posix.basename(file.name),
          ),
        );
      }
    }
    images.sort((a, b) => a.archivePath.compareTo(b.archivePath));
    return images;
  }

  static Future<_ParsedBook> _parseSingleEpub(
    String epubPath,
    int currentImageCount,
  ) async {
    try {
      final archive = ZipDecoder().decodeBytes(
        await File(epubPath).readAsBytes(),
      );
      final opfPath = _locateOpfPath(archive);
      final images = _extractImagesFromArchive(archive);
      final contextByImagePath = _extractImageContexts(archive, opfPath);
      final bookInfo = BookInfo(
        title: _extractTitleFromArchive(archive, epubPath),
        filePath: epubPath,
        startImageIndex: currentImageCount,
        endImageIndex: currentImageCount + images.length - 1,
      );
      return _ParsedBook(
        bookInfo: bookInfo,
        images: images,
        imageContexts: images
            .map((image) => contextByImagePath[image.archivePath])
            .toList(),
      );
    } catch (error) {
      debugPrint('解析epub文件失败: $epubPath, 错误: $error');
      return _ParsedBook(
        bookInfo: BookInfo(
          title: '${path.basenameWithoutExtension(epubPath)} (解析失败)',
          filePath: epubPath,
          startImageIndex: currentImageCount,
          endImageIndex: currentImageCount - 1,
        ),
        images: const [],
        imageContexts: const [],
      );
    }
  }

  /// 后台解析多个 EPUB，包括图片所属章节的文本上下文。
  static Future<EpubParseResult> parseMultipleEpubs(
    List<String> epubPaths,
  ) async {
    final books = <BookInfo>[];
    final allImages = <Uint8List>[];
    final allImageNames = <String>[];
    final imageBookIndexes = <int>[];
    final imageContexts = <ImageContext?>[];

    for (var bookIndex = 0; bookIndex < epubPaths.length; bookIndex++) {
      final parsedBook = await _parseSingleEpub(
        epubPaths[bookIndex],
        allImages.length,
      );
      books.add(parsedBook.bookInfo);
      for (var index = 0; index < parsedBook.images.length; index++) {
        final image = parsedBook.images[index];
        allImages.add(image.bytes);
        allImageNames.add(image.displayName);
        imageBookIndexes.add(bookIndex);
        imageContexts.add(parsedBook.imageContexts[index]);
      }
    }

    return EpubParseResult(
      books: books,
      allImages: allImages,
      allImageNames: allImageNames,
      imageBookIndexes: imageBookIndexes,
      imageContexts: imageContexts,
      imageResolutions: const [],
      resolutionStatistics: const ResolutionStatistics(
        resolutionCounts: {},
        mostCommonResolution: null,
        mostCommonResolutionCount: 0,
        maxWidth: 0,
        maxHeight: 0,
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

class _ExtractedImage {
  final Uint8List bytes;
  final String archivePath;
  final String displayName;

  const _ExtractedImage({
    required this.bytes,
    required this.archivePath,
    required this.displayName,
  });
}

class _ParsedBook {
  final BookInfo bookInfo;
  final List<_ExtractedImage> images;
  final List<ImageContext?> imageContexts;

  const _ParsedBook({
    required this.bookInfo,
    required this.images,
    required this.imageContexts,
  });
}

class _ImagePositionedText {
  final String content;
  final int imageOffset;

  const _ImagePositionedText({
    required this.content,
    required this.imageOffset,
  });
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
