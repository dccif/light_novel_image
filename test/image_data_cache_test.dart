import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:light_novel_image/models/image_entry.dart';
import 'package:light_novel_image/models/image_resolution.dart';
import 'package:light_novel_image/services/image_data_cache.dart';

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('epub_cache_test_');
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });

  Future<ImageEntry> entry(String id, int size) async {
    final file = File('${directory.path}/$id');
    await file.writeAsBytes(List.filled(size, 1));
    return ImageEntry(
      id: id,
      archivePath: id,
      name: id,
      bookIndex: 0,
      resolution: const ImageResolution(width: 1, height: 1),
      filePath: file.path,
    );
  }

  test('LRU 同时限制总字节和条目，命中会更新使用顺序', () async {
    final cache = ImageDataCache(maxBytes: 8, maxEntries: 2);
    addTearDown(cache.close);
    final a = await entry('a', 4);
    final b = await entry('b', 4);
    final c = await entry('c', 4);
    final first = await cache.read(a);
    final second = await cache.read(b);
    expect(await cache.read(a), same(first));
    await cache.read(c);
    expect(cache.byteCount, 8);
    expect(cache.entryCount, 2);
    expect(await cache.read(a), same(first));
    expect(await cache.read(b), isNot(same(second)));
  });

  test('并发读取共享一个 future，超大图片不保留', () async {
    final cache = ImageDataCache(maxBytes: 4);
    final image = await entry('large', 8);
    final one = cache.read(image);
    final two = cache.read(image);
    expect(one, same(two));
    expect(await one, hasLength(8));
    expect(cache.byteCount, 0);
    cache.close();
    await expectLater(cache.read(image), throwsStateError);
  });

  test('关闭后未完成的读取不能重新填充缓存', () async {
    final cache = ImageDataCache();
    final pending = cache.read(await entry('pending', 8));
    cache.close();
    await pending;
    expect(cache.byteCount, 0);
    expect(cache.entryCount, 0);
  });

  test('内存图片不复制、不计入文件 LRU', () async {
    final bytes = Uint8List(8);
    final cache = ImageDataCache();
    addTearDown(cache.close);
    expect(
      await cache.read(
        ImageEntry(
          id: 'memory',
          archivePath: 'memory',
          name: 'memory',
          bookIndex: 0,
          resolution: const ImageResolution(width: 1, height: 1),
          bytes: bytes,
        ),
      ),
      same(bytes),
    );
    expect(cache.byteCount, 0);
  });
}
