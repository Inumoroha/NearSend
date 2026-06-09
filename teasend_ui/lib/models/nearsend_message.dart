import 'dart:io';

import 'package:path/path.dart' as p;

enum NearSendPayloadType { text, image, file }

class NearSendAttachment {
  const NearSendAttachment({
    required this.path,
    required this.name,
    required this.size,
    required this.type,
  });

  factory NearSendAttachment.fromPath(String path) {
    final file = File(path);
    return NearSendAttachment(
      path: path,
      name: p.basename(path),
      size: file.existsSync() ? file.lengthSync() : 0,
      type: NearSendPayloadTypeX.fromFileName(path),
    );
  }

  final String path;
  final String name;
  final int size;
  final NearSendPayloadType type;

  bool get isImage => type == NearSendPayloadType.image;
}

class NearSendMessage {
  const NearSendMessage({
    required this.senderFingerprint,
    required this.senderAlias,
    required this.text,
    required this.receivedAt,
    this.attachment,
  });

  final String senderFingerprint;
  final String senderAlias;
  final String text;
  final DateTime receivedAt;
  final NearSendAttachment? attachment;
}

extension NearSendPayloadTypeX on NearSendPayloadType {
  static NearSendPayloadType fromFileName(String fileName) {
    final extension = p.extension(fileName).toLowerCase();
    return switch (extension) {
      '.jpg' ||
      '.jpeg' ||
      '.png' ||
      '.gif' ||
      '.webp' ||
      '.bmp' => NearSendPayloadType.image,
      _ => NearSendPayloadType.file,
    };
  }

  String get wireValue {
    return switch (this) {
      NearSendPayloadType.text => 'text',
      NearSendPayloadType.image => 'image',
      NearSendPayloadType.file => 'file',
    };
  }
}
