import 'package:flutter/material.dart';

enum FileKind {
  image,
  pdf,
  archive,
  doc,
  file;

  static FileKind fromExtension(String extension) {
    return switch (extension) {
      '.jpg' ||
      '.jpeg' ||
      '.png' ||
      '.gif' ||
      '.webp' ||
      '.bmp' ||
      '.heic' ||
      '.heif' => FileKind.image,
      '.pdf' => FileKind.pdf,
      '.zip' || '.rar' || '.7z' || '.tar' || '.gz' => FileKind.archive,
      '.doc' ||
      '.docx' ||
      '.txt' ||
      '.md' ||
      '.xls' ||
      '.xlsx' ||
      '.ppt' ||
      '.pptx' => FileKind.doc,
      _ => FileKind.file,
    };
  }

  /// Parses a persisted enum name (see [FileKind.name]).
  static FileKind fromName(Object? value) {
    return FileKind.values.firstWhere(
      (kind) => kind.name == value,
      orElse: () => FileKind.file,
    );
  }

  IconData get icon {
    switch (this) {
      case FileKind.image:
        return Icons.image_rounded;
      case FileKind.pdf:
        return Icons.picture_as_pdf_rounded;
      case FileKind.archive:
        return Icons.folder_zip_rounded;
      case FileKind.doc:
        return Icons.description_rounded;
      case FileKind.file:
        return Icons.insert_drive_file_rounded;
    }
  }
}
