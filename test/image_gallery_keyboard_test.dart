import 'dart:convert';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:light_novel_image/models/image_context.dart';
import 'package:light_novel_image/widgets/image_gallery_widget.dart';

void main() {
  testWidgets('左右键在图片和上下文区域都能切换图片', (tester) async {
    final image = Uint8List.fromList(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL8mQAAAABJRU5ErkJggg==',
      ),
    );
    final changedIndexes = <int>[];
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
            images: [image, image],
            imageNames: const ['first.png', 'second.png'],
            imageContexts: const [imageContext, imageContext],
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
