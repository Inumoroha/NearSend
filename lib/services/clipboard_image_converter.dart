import 'dart:typed_data';

import 'package:image/image.dart' as image;

Uint8List? clipboardDibToJpeg(Uint8List dibBytes, {int quality = 92}) {
  final bitmap = image.decodeBmp(_bmpBytesFromDib(dibBytes));
  if (bitmap == null) return null;
  return Uint8List.fromList(image.encodeJpg(bitmap, quality: quality));
}

Uint8List _bmpBytesFromDib(Uint8List dibBytes) {
  const bitmapFileHeaderSize = 14;
  final pixelOffset = bitmapFileHeaderSize + _dibPixelOffset(dibBytes);
  final fileSize = bitmapFileHeaderSize + dibBytes.length;
  final bytes = Uint8List(fileSize);
  final data = ByteData.sublistView(bytes);

  bytes[0] = 0x42; // B
  bytes[1] = 0x4D; // M
  data.setUint32(2, fileSize, Endian.little);
  data.setUint32(10, pixelOffset, Endian.little);
  bytes.setRange(bitmapFileHeaderSize, fileSize, dibBytes);
  return bytes;
}

int _dibPixelOffset(Uint8List dibBytes) {
  if (dibBytes.length < 40) return 40;
  final data = ByteData.sublistView(dibBytes);
  final headerSize = data.getUint32(0, Endian.little);
  final bitCount = data.getUint16(14, Endian.little);
  final colorsUsed = data.getUint32(32, Endian.little);
  final paletteEntries = colorsUsed != 0
      ? colorsUsed
      : bitCount <= 8
      ? 1 << bitCount
      : 0;
  return headerSize + paletteEntries * 4;
}
