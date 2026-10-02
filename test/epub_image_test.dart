import 'dart:typed_data';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:light_novel_image/models/image_entry.dart';
import 'package:light_novel_image/models/image_resolution.dart';
import 'package:light_novel_image/widgets/epub_image.dart';

void main() {
  ImageEntry image(int width, int height) => ImageEntry(
    id: 'test',
    archivePath: 'test.png',
    name: 'test.png',
    bookIndex: 0,
    resolution: ImageResolution(width: width, height: height),
    bytes: Uint8List(0),
  );

  test('缩略图仅指定短边像素以保留比例，并禁止小图片放大解码', () {
    final portrait = image(3000, 4000);
    final portraitProvider =
        EpubImage.buildImage(
              portrait.bytes!,
              portrait,
              thumbnailPixels: 400,
            ).image
            as ExtendedResizeImage;
    expect(portraitProvider.width, 400);
    expect(portraitProvider.height, isNull);
    final landscape = image(4000, 3000);
    final landscapeProvider =
        EpubImage.buildImage(
              landscape.bytes!,
              landscape,
              thumbnailPixels: 400,
            ).image
            as ExtendedResizeImage;
    expect(landscapeProvider.width, isNull);
    expect(landscapeProvider.height, 400);
    final small = image(100, 200);
    final smallProvider =
        EpubImage.buildImage(small.bytes!, small, thumbnailPixels: 400).image
            as ExtendedResizeImage;
    expect(smallProvider.width, 100);
  });

  test('查看器保留原始分辨率，显示和预加载使用同一 provider key', () async {
    final entry = image(3000, 4000);
    final shown = EpubImage.buildImage(entry.bytes!, entry).image;
    final preloaded = EpubImage.buildImage(entry.bytes!, entry).image;
    expect(shown, isNot(isA<ExtendedResizeImage>()));
    expect(
      await shown.obtainKey(ImageConfiguration.empty),
      await preloaded.obtainKey(ImageConfiguration.empty),
    );
  });
}
