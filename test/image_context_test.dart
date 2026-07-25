import 'package:flutter_test/flutter_test.dart';
import 'package:light_novel_image/services/epub_parser_service.dart';

void main() {
  group('EPUB 图片上下文解析', () {
    test('关联图片前后的正文和章节信息', () {
      const content = '''
        <html><body>
          <p>主角推开旧宅的门，发现走廊尽头传来微弱的歌声。</p>
          <img src="../Images/scene.jpg" />
          <p>她循着声音前进，墙上的肖像忽然眨了眨眼。</p>
        </body></html>
      ''';

      final contexts = EpubParserService.extractImageContextsFromContent(
        contentPath: 'OEBPS/Text/chapter_01.xhtml',
        content: content,
        chapterTitle: '第一章 夜访旧宅',
        chapterOrder: 1,
      );

      final imageContext = contexts['OEBPS/Images/scene.jpg'];
      expect(imageContext, isNotNull);
      expect(imageContext!.chapterTitle, '第一章 夜访旧宅');
      expect(imageContext.chapterOrder, 1);
      expect(imageContext.textBeforeImage, contains('走廊尽头传来微弱的歌声'));
      expect(imageContext.textAfterImage, contains('墙上的肖像忽然眨了眨眼'));
    });

    test('保留图片前后的完整章节内容和原文位置', () {
      const content = '''
        <html><body>
          <p>第一段文字，说明故事发生在黄昏的车站。</p>
          <p>第二段文字，角色正在等待迟到的列车。</p>
          <img src="../Images/station.jpg" />
          <p>第三段文字，列车进站时响起了广播。</p>
          <p>第四段文字，角色终于看见了熟悉的身影。</p>
        </body></html>
      ''';

      final context = EpubParserService.extractImageContextsFromContent(
        contentPath: 'OEBPS/Text/chapter_02.xhtml',
        content: content,
        chapterTitle: '第二章 车站',
        chapterOrder: 2,
      )['OEBPS/Images/station.jpg'];

      expect(context, isNotNull);
      expect(context!.textBeforeImage, contains('第一段文字'));
      expect(context.textBeforeImage, contains('第二段文字'));
      expect(context.textAfterImage, contains('第三段文字'));
      expect(context.textAfterImage, contains('第四段文字'));
      expect(context.content, contains('第一段文字'));
      expect(context.content, contains('第四段文字'));
    });

    test('纯图片页不生成上下文', () {
      const content = '''
        <html><body>
          <img src="../Images/cover_01.jpg" />
          <img src="../Images/cover_02.jpg" />
        </body></html>
      ''';

      final contexts = EpubParserService.extractImageContextsFromContent(
        contentPath: 'OEBPS/Text/color_pages.xhtml',
        content: content,
        chapterTitle: '彩页',
        chapterOrder: 1,
      );

      expect(contexts, isEmpty);
    });
  });
}
