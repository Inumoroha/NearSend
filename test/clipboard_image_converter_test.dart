import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:nearsend/services/clipboard_image_converter.dart';

void main() {
  test('converts clipboard DIB bytes to JPEG', () {
    final source = image.Image(width: 3, height: 2)
      ..setPixelRgb(0, 0, 255, 0, 0)
      ..setPixelRgb(1, 0, 0, 255, 0)
      ..setPixelRgb(2, 0, 0, 0, 255);
    final bmp = Uint8List.fromList(image.encodeBmp(source));
    final dib = Uint8List.sublistView(bmp, 14);

    final jpeg = clipboardDibToJpeg(dib);

    expect(jpeg, isNotNull);
    expect(jpeg!.take(2), [0xff, 0xd8]);
    final decoded = image.decodeJpg(jpeg);
    expect(decoded, isNotNull);
    expect(decoded!.width, source.width);
    expect(decoded.height, source.height);
  });

  test('returns null for invalid clipboard bitmap data', () {
    expect(clipboardDibToJpeg(Uint8List.fromList([1, 2, 3])), isNull);
  });
}
