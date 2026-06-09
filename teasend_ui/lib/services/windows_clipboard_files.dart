import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

class WindowsClipboardFiles {
  Future<List<String>> readImagePaths() async {
    if (!Platform.isWindows) return const [];
    final paths = readFilePaths();
    final imagePaths = paths.where(_isImagePath).toList(growable: false);
    if (imagePaths.isNotEmpty) return imagePaths;

    final bitmapPath = await _readBitmapPath();
    return bitmapPath == null ? const [] : [bitmapPath];
  }

  List<String> readFilePaths() {
    if (!Platform.isWindows) return const [];
    if (OpenClipboard(NULL) == FALSE) return const [];

    try {
      if (IsClipboardFormatAvailable(CF_HDROP) == FALSE) {
        return const [];
      }

      final handle = GetClipboardData(CF_HDROP);
      if (handle == NULL) return const [];

      final count = DragQueryFile(handle, 0xFFFFFFFF, nullptr, 0);
      final paths = <String>[];
      for (var index = 0; index < count; index++) {
        final length = DragQueryFile(handle, index, nullptr, 0);
        if (length == 0) continue;

        final buffer = wsalloc(length + 1);
        try {
          DragQueryFile(handle, index, buffer, length + 1);
          paths.add(buffer.toDartString());
        } finally {
          calloc.free(buffer);
        }
      }
      return paths;
    } finally {
      CloseClipboard();
    }
  }

  bool writeFilePaths(List<String> paths) {
    if (!Platform.isWindows) return false;
    final normalized = paths
        .where((path) => path.trim().isNotEmpty)
        .map((path) => path.trim())
        .toList(growable: false);
    if (normalized.isEmpty) return false;
    if (OpenClipboard(NULL) == FALSE) return false;

    final dropFilesSize = sizeOf<DROPFILES>();
    final encodedPaths =
        normalized.expand((path) => '$path\u0000'.codeUnits).toList()..add(0);
    final byteLength = dropFilesSize + encodedPaths.length * sizeOf<Uint16>();
    final handle = GlobalAlloc(GMEM_MOVEABLE | GMEM_ZEROINIT, byteLength);
    if (handle == nullptr) {
      CloseClipboard();
      return false;
    }

    try {
      final pointer = GlobalLock(handle);
      if (pointer == nullptr) return false;

      try {
        final dropFiles = pointer.cast<DROPFILES>().ref;
        dropFiles.pFiles = dropFilesSize;
        dropFiles.fWide = TRUE;

        final pathPointer = (pointer.cast<Uint8>() + dropFilesSize)
            .cast<Uint16>();
        for (var index = 0; index < encodedPaths.length; index++) {
          pathPointer[index] = encodedPaths[index];
        }
      } finally {
        GlobalUnlock(handle);
      }

      EmptyClipboard();
      if (SetClipboardData(CF_HDROP, handle.address) == NULL) return false;
      return true;
    } finally {
      CloseClipboard();
    }
  }

  Future<String?> _readBitmapPath() async {
    if (OpenClipboard(NULL) == FALSE) return null;

    try {
      final format = IsClipboardFormatAvailable(CF_DIBV5) != FALSE
          ? CF_DIBV5
          : IsClipboardFormatAvailable(CF_DIB) != FALSE
          ? CF_DIB
          : 0;
      if (format == 0) return null;

      final handle = GetClipboardData(format);
      if (handle == NULL) return null;

      final pointer = GlobalLock(Pointer.fromAddress(handle));
      if (pointer == nullptr) return null;

      try {
        final size = GlobalSize(Pointer.fromAddress(handle));
        if (size <= 0) return null;

        final dibBytes = pointer.cast<Uint8>().asTypedList(size);
        final bmpBytes = _bmpBytesFromDib(Uint8List.fromList(dibBytes));
        final directory = await Directory.systemTemp.createTemp(
          'nearsend_clipboard_',
        );
        final file = File(
          '${directory.path}${Platform.pathSeparator}'
          'clipboard-${DateTime.now().millisecondsSinceEpoch}.bmp',
        );
        await file.writeAsBytes(bmpBytes, flush: true);
        return file.path;
      } finally {
        GlobalUnlock(Pointer.fromAddress(handle));
      }
    } finally {
      CloseClipboard();
    }
  }

  Uint8List _bmpBytesFromDib(Uint8List dibBytes) {
    final pixelOffset = _bitmapFileHeaderSize + _dibPixelOffset(dibBytes);
    final fileSize = _bitmapFileHeaderSize + dibBytes.length;
    final bytes = Uint8List(fileSize);
    final data = ByteData.sublistView(bytes);

    bytes[0] = 0x42; // B
    bytes[1] = 0x4D; // M
    data.setUint32(2, fileSize, Endian.little);
    data.setUint32(10, pixelOffset, Endian.little);
    bytes.setRange(_bitmapFileHeaderSize, fileSize, dibBytes);
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

  bool _isImagePath(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.bmp');
  }

  static const _bitmapFileHeaderSize = 14;
}
