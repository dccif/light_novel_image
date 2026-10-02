import 'dart:ui' as ui;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:light_novel_image/models/image_context.dart';
import 'package:light_novel_image/models/image_entry.dart';
import 'package:light_novel_image/models/image_resolution.dart';
import 'package:light_novel_image/services/image_data_cache.dart';
import 'package:light_novel_image/widgets/image_gallery_widget.dart';
import 'package:light_novel_image/widgets/epub_image.dart';

Future<Uint8List> createTestImage(WidgetTester tester) async {
  return (await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(
      const ui.Rect.fromLTWH(0, 0, 2, 2),
      ui.Paint()..color = const ui.Color(0xFFFF0000),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(2, 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    return data!.buffer.asUint8List();
  }))!;
}

void main() {
  testWidgets('上下文已滚离标记后连续左右切图不闪回按钮', (tester) async {
    final image = await createTestImage(tester);
    final text = List.generate(
      1000,
      (i) => '第 $i 段剧情，角色正在前往远方的小镇。',
    ).join('\n\n');
    final document = BookText(text);
    final cache = ImageDataCache();
    final indices = <int>[];
    final entries = List.generate(
      4,
      (i) => ImageEntry(
        id: '$i',
        archivePath: '$i.png',
        name: '$i.png',
        bookIndex: 0,
        resolution: const ImageResolution(width: 1, height: 1),
        bytes: image,
        context: ImageContext(
          chapterTitle: '章节 $i',
          chapterOrder: i + 1,
          content: text,
          imageOffset: document.starts[400 + i * 100],
          document: document,
        ),
      ),
    );
    await tester.pumpWidget(
      FluentApp(
        home: ImageGalleryWidget(
          images: entries,
          cache: cache,
          initialIndex: 0,
          onIndexChanged: indices.add,
        ),
      ),
    );
    // 图片解码运行在真实异步任务中，避免 fake clock 在加载动画期间空转。
    await tester.runAsync(
      () => precacheImage(
        EpubImage.buildImage(image, entries.first).image,
        tester.element(find.byType(ImageGalleryWidget)),
      ),
    );
    await tester.pumpAndSettle();
    final scroll = tester
        .widget<CustomScrollView>(find.byType(CustomScrollView))
        .controller!;
    scroll.jumpTo(1400);
    await tester.pumpAndSettle();
    expect(find.byTooltip('回到图片原文位置'), findsOneWidget);
    for (var i = 1; i < 4; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(find.byTooltip('回到图片原文位置'), findsNothing);
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.byTooltip('回到图片原文位置'), findsNothing);
      expect(indices.last, i);
    }
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(indices.last, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    cache.close();
  });
  testWidgets('左右键在图片和上下文区域都能切换图片', (tester) async {
    final image = await createTestImage(tester);
    final changedIndexes = <int>[];
    final cache = ImageDataCache();
    addTearDown(cache.close);
    const imageContext = ImageContext(
      chapterTitle: '测试章节',
      chapterOrder: 1,
      content: '图片之前的正文。图片之后的正文。',
      imageOffset: 7,
    );

    await tester.pumpWidget(
      FluentApp(
        home: SizedBox(
          width: 900,
          height: 600,
          child: ImageGalleryWidget(
            images: [
              for (final id in ['first.png', 'second.png'])
                ImageEntry(
                  id: id,
                  archivePath: id,
                  name: id,
                  bookIndex: 0,
                  resolution: const ImageResolution(width: 1, height: 1),
                  bytes: image,
                  context: imageContext,
                ),
            ],
            cache: cache,
            initialIndex: 0,
            onIndexChanged: changedIndexes.add,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    await tester.tap(find.text('图片上下文'));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 120));
    expect(changedIndexes, contains(1));

    await tester.tapAt(const Offset(200, 250));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump(const Duration(milliseconds: 120));
    expect(changedIndexes.last, 0);
  });
}
