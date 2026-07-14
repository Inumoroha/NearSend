import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import 'clipboard_image_converter.dart';

class WindowsClipboardFiles {
  /// A monotonically increasing counter Windows bumps on every clipboard
  /// change. Lets us cheaply detect "the clipboard changed" while polling,
  /// without opening the clipboard or materializing its contents each tick.
  int clipboardSequence() {
    if (!Platform.isWindows) return 0;
    return GetClipboardSequenceNumber();
  }

  /// Whether the clipboard currently holds a bitmap (e.g. a screenshot).
  /// `IsClipboardFormatAvailable` does not require `OpenClipboard`, so this is
  /// safe to call frequently.
  bool hasClipboardBitmap() {
    if (!Platform.isWindows) return false;
    return IsClipboardFormatAvailable(CF_DIBV5) != FALSE ||
        IsClipboardFormatAvailable(CF_DIB) != FALSE;
  }

  /// Reads only the clipboard bitmap (ignores copied image files), writing it
  /// to a temp `.jpg`. Returns null when no bitmap is present or decodable.
  Future<String?> readBitmapImagePath() async {
    if (!Platform.isWindows) return null;
    return _readBitmapPath();
  }

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
    final dibBytes = _readBitmapBytes();
    if (dibBytes == null) return null;

    final jpegBytes = await Isolate.run(() => clipboardDibToJpeg(dibBytes));
    if (jpegBytes == null) return null;
    final directory = await Directory.systemTemp.createTemp(
      'nearsend_clipboard_',
    );
    final file = File(
      '${directory.path}${Platform.pathSeparator}'
      'clipboard-${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(jpegBytes, flush: true);
    return file.path;
  }

  Uint8List? _readBitmapBytes() {
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

        return Uint8List.fromList(pointer.cast<Uint8>().asTypedList(size));
      } finally {
        GlobalUnlock(Pointer.fromAddress(handle));
      }
    } finally {
      CloseClipboard();
    }
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
}
