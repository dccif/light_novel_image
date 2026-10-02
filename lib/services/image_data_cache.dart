import 'dart:io';
import 'dart:typed_data';

import '../models/image_entry.dart';

/// 编码图片的 LRU，与 Flutter 的解码图片缓存分开计量。
class ImageDataCache {
  final int maxBytes;
  final int maxEntries;
  final _entries = <String, Uint8List>{};
  final _pending = <String, Future<Uint8List>>{};
  int _byteCount = 0;
  bool _closed = false;

  ImageDataCache({this.maxBytes = 32 * 1024 * 1024, this.maxEntries = 32});
  int get byteCount => _byteCount;
  int get entryCount => _entries.length;

  Future<Uint8List> read(ImageEntry image) {
    if (_closed) return Future.error(StateError('图片缓存已关闭'));
    if (image.bytes != null) return Future.value(image.bytes);
    final cached = _entries.remove(image.id);
    if (cached != null) {
      _entries[image.id] = cached;
      return Future.value(cached);
    }
    return _pending.putIfAbsent(image.id, () => _load(image));
  }

  Future<Uint8List> _load(ImageEntry image) async {
    try {
      final bytes = await File(image.filePath!).readAsBytes();
      if (!_closed && maxEntries > 0 && bytes.length <= maxBytes) {
        while (_entries.isNotEmpty &&
            (_entries.length >= maxEntries ||
                _byteCount + bytes.length > maxBytes)) {
          _byteCount -= _entries.remove(_entries.keys.first)!.length;
        }
        _entries[image.id] = bytes;
        _byteCount += bytes.length;
      }
      return bytes;
    } finally {
      _pending.remove(image.id);
    }
  }

  void close() {
    _closed = true;
    _entries.clear();
    _pending.clear();
    _byteCount = 0;
  }
}
