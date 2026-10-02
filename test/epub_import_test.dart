import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:light_novel_image/models/epub_parse_result.dart';
import 'package:light_novel_image/services/epub_parser_service.dart';

void main() {
  late Directory directory;
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL8mQAAAABJRU5ErkJggg==',
  );
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('epub_import_test_');
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });

  Future<String> createBook(String name) async {
    final archive = Archive();
    void text(String path, String content) {
      final bytes = utf8.encode(content);
      archive.addFile(ArchiveFile(path, bytes.length, bytes));
    }

    text(
      'META-INF/container.xml',
      '<container><rootfiles><rootfile full-path="OEBPS/book.opf"/></rootfiles></container>',
    );
    text(
      'OEBPS/book.opf',
      '''<package><metadata><title>同名书籍</title></metadata><manifest>
      <item id="cover" href="cover.xhtml"/><item id="first" href="first.xhtml"/><item id="last" href="last.xhtml"/>
      </manifest><spine><itemref idref="cover"/><itemref idref="first"/><itemref idref="last"/></spine></package>''',
    );
    text(
      'OEBPS/cover.xhtml',
      '<html><head><title>封面标题不会成为正文</title></head><body><img src="Images/cover.png"/></body></html>',
    );
    text(
      'OEBPS/first.xhtml',
      '<html><head><title>第一章</title></head><body><p>之前的正文足够长，人物到达故事现场。</p><img src="Images/a.png"/><p>中间的正文，人物抬头看到第二幅图。</p><img src="Other/a.png"/><p>图片之后的正文。</p></body></html>',
    );
    text(
      'OEBPS/last.xhtml',
      '<html><head><title>最后一章</title></head><body><p>末章文字，可以从图片的位置一直阅读到本书的结尾。</p></body></html>',
    );
    for (final path in [
      'OEBPS/Images/cover.png',
      'OEBPS/Images/a.png',
      'OEBPS/Other/a.png',
    ]) {
      archive.addFile(ArchiveFile(path, png.length, png));
    }
    final file = File('${directory.path}/$name.epub');
    await file.writeAsBytes(ZipEncoder().encode(archive));
    return file.path;
  }

  for (final budget in [0, 1024 * 1024]) {
    test('流式多书导入、尺寸与全文上下文，内存预算 $budget', () async {
      final paths = [await createBook('one'), await createBook('two')];
      final cache = await Directory('${directory.path}/cache').create();
      final result = await EpubParserService.parseMultipleEpubs(
        EpubImportRequest(paths, cache.path, memoryBudget: budget),
      );
      expect(result.books, hasLength(2));
      expect(result.books.map((b) => b.title), everyElement('同名书籍'));
      expect(result.images, hasLength(6));
      expect(result.images.map((i) => i.id).toSet(), hasLength(6));
      expect(result.resolutionStatistics.maxWidth, 1);
      expect(result.resolutionStatistics.maxHeight, 1);
      for (final image in result.images) {
        expect(image.bytes != null, budget > 0);
        if (image.filePath != null) {
          expect(await File(image.filePath!).readAsBytes(), png);
        }
        if (image.name == 'cover.png') {
          expect(image.context, isNull);
        } else {
          expect(image.context!.content, contains('末章文字'));
          expect(image.context!.content, isNot(contains('封面标题不会成为正文')));
          expect(image.context!.imageOffset, greaterThan(0));
        }
      }
      final contexts = result.images
          .where((i) => i.bookIndex == 0 && i.context != null)
          .map((i) => i.context!)
          .toList();
      expect(contexts[0].document, same(contexts[1].document));
      expect(contexts[0].content, same(contexts[1].content));
      expect(contexts[0].imageOffset, lessThan(contexts[1].imageOffset));
    });
  }
  test('多书共享内存总预算，不是每本书各保留一份预算', () async {
    final paths = [await createBook('one'), await createBook('two')];
    final cache = await Directory('${directory.path}/cache').create();
    final result = await EpubParserService.parseMultipleEpubs(
      EpubImportRequest(paths, cache.path, memoryBudget: png.length * 3),
    );
    expect(result.images.where((image) => image.bytes != null), hasLength(3));
    expect(
      result.images.where((image) => image.filePath != null),
      hasLength(3),
    );
    expect(
      result.images
          .where((image) => image.bookIndex == 0)
          .every((image) => image.bytes != null),
      isTrue,
    );
  });
}
