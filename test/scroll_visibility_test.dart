import 'package:flutter_test/flutter_test.dart';
import 'package:light_novel_image/utils/scroll_visibility.dart';

void main() {
  group('滚动内容可视范围', () {
    test('完整位于视口内时可见', () {
      expect(
        ScrollVisibility.isFullyVisible(
          itemTop: 120,
          itemBottom: 160,
          viewportTop: 100,
          viewportBottom: 300,
        ),
        isTrue,
      );
    });

    test('超出视口上方或下方时不可见', () {
      expect(
        ScrollVisibility.isFullyVisible(
          itemTop: 80,
          itemBottom: 130,
          viewportTop: 100,
          viewportBottom: 300,
        ),
        isFalse,
      );
      expect(
        ScrollVisibility.isFullyVisible(
          itemTop: 260,
          itemBottom: 320,
          viewportTop: 100,
          viewportBottom: 300,
        ),
        isFalse,
      );
    });
  });
}
