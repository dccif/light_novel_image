import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:light_novel_image/models/image_context.dart';
import 'package:light_novel_image/widgets/image_context_panel.dart';

void main() {
  testWidgets('长书从图片位置懒布局、前后滚动并可返回标记', (tester) async {
    final text = List.generate(
      10000,
      (i) => '第 $i 段：角色向前走去，故事仍在继续。',
    ).join('\n\n');
    final document = BookText(text);
    final offset = document.starts[5000];
    await tester.pumpWidget(
      FluentApp(
        home: Center(
          child: SizedBox(
            width: 300,
            height: 600,
            child: ImageContextPanel(
              imageContext: ImageContext(
                chapterTitle: '测试',
                chapterOrder: 1,
                content: text,
                imageOffset: offset,
                document: document,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // 文字存在于 widget 树中不代表实际可见，正文视口必须填满面板。
    const contentWidth = 300 - 16 * 2 - 1.0; // 面板宽度减去内边距和左边框。
    final viewportSize = tester.getSize(find.byType(CustomScrollView));
    expect(viewportSize.width, contentWidth);
    expect(viewportSize.height, greaterThan(0));
    expect(tester.getSize(find.text('图片原文位置')).width, greaterThan(0));
    expect(
      tester
          .getRect(find.byType(CustomScrollView))
          .contains(tester.getRect(find.text('图片原文位置')).center),
      isTrue,
    );
    expect(find.text('图片原文位置'), findsOneWidget);
    expect(find.textContaining('第 5000 段'), findsOneWidget);
    expect(find.textContaining('第 9999 段'), findsNothing);
    expect(find.byType(Text).evaluate().length, lessThan(60));
    final scroll = tester
        .widget<CustomScrollView>(find.byType(CustomScrollView))
        .controller!;
    final paragraphBefore = tester
        .getTopLeft(find.textContaining('第 4999 段'))
        .dy;
    final markerTop = tester.getTopLeft(find.text('图片原文位置')).dy;
    expect(paragraphBefore, lessThan(markerTop));
    scroll.jumpTo(1400);
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(CustomScrollView)).width, contentWidth);
    expect(find.byTooltip('回到图片原文位置'), findsOneWidget);
    await tester.tap(find.byTooltip('回到图片原文位置'));
    await tester.pumpAndSettle();
    expect(scroll.offset, closeTo(0, 0.01));
    expect(tester.getSize(find.byType(CustomScrollView)).width, contentWidth);
    expect(find.byTooltip('回到图片原文位置'), findsNothing);
    scroll.jumpTo(-1400);
    await tester.pumpAndSettle();
    expect(find.byTooltip('回到图片原文位置'), findsOneWidget);
    expect(find.byType(Text).evaluate().length, lessThan(60));
  });

  test('超长段落分块，二分定位边界不丢失字符', () {
    final content = '${List.filled(2047, '字').join()}😀结尾\n\n第二段';
    final document = BookText(content);
    expect(document.paragraph(0).length, 2047);
    expect(document.paragraph(1), '😀结尾');
    expect(document.paragraphAt(content.indexOf('第二段')), 2);
    expect(document.paragraphAt(content.length + 10), 2);
    expect(BookText('').paragraphAt(0), 0);
  });
}
