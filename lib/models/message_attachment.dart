import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'file_kind.dart';
import 'nearsend_message.dart';

class MessageAttachment {
  MessageAttachment({
    required this.path,
    required this.name,
    required this.size,
    required this.kind,
    this.savedPath,
  });

  factory MessageAttachment.fromPath(String path) {
    final file = File(path);
    final name = p.basename(path);
    final extension = p.extension(path).toLowerCase();
    final size = file.existsSync() ? file.lengthSync() : 0;

    return MessageAttachment(
      path: path,
      name: name,
      size: size,
      kind: FileKind.fromExtension(extension),
    );
  }

  factory MessageAttachment.fromNearSend(
    NearSendAttachment attachment, {
    String? savedPath,
  }) {
    return MessageAttachment(
      path: attachment.path,
      name: attachment.name,
      size: attachment.size,
      kind: attachment.isImage ? FileKind.image : FileKind.file,
      savedPath: savedPath,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'name': name,
      'size': size,
      'kind': kind.name,
      'savedPath': savedPath,
    };
  }

  factory MessageAttachment.fromJson(Map<String, dynamic> json) {
    return MessageAttachment(
      path: json['path'] as String? ?? '',
      name: json['name'] as String? ?? '',
      size: json['size'] is int ? json['size'] as int : 0,
      kind: FileKind.fromName(json['kind']),
      savedPath: json['savedPath'] as String?,
    );
  }

  final String path;
  final String name;
  final int size;
  final FileKind kind;
  final String? savedPath;

  bool get isImage => kind == FileKind.image;

  String get sizeLabel {
    if (size <= 0) return '未知大小';
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = size.toDouble();
    var index = 0;
    while (value >= 1024 && index < units.length - 1) {
      value /= 1024;
      index++;
    }

    final digits = index == 0 || value >= 10 ? 0 : 1;
    return '${value.toStringAsFixed(digits)} ${units[index]}';
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

  NearSendAttachment toNearSend() {
    return NearSendAttachment(
      path: path,
      name: name,
      size: size,
      type: isImage ? NearSendPayloadType.image : NearSendPayloadType.file,
    );
  }
}
