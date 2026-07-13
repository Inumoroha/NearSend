import 'package:flutter/material.dart';

import 'file_kind.dart';

class TransferFile {
  TransferFile(this.name, this.size, this.progress, this.kind);

  final String name;
  final String size;
  final int progress;
  final FileKind kind;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'size': size,
      'progress': progress,
      'kind': kind.name,
    };
  }

  factory TransferFile.fromJson(Map<String, dynamic> json) {
    return TransferFile(
      json['name'] as String? ?? '',
      json['size'] as String? ?? '',
      json['progress'] is int ? json['progress'] as int : 0,
      FileKind.fromName(json['kind']),
    );
  }

  IconData get icon {
    switch (kind) {
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
