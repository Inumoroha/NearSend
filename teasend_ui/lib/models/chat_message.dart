import 'message_attachment.dart';

enum MessageSendStatus { none, sending, sent, failed, cancelled }

class ChatMessage {
  ChatMessage(
    this.text, {
    String? id,
    this.sender = 'T',
    this.isMe = false,
    this.system = false,
    this.attachment,
    this.status = MessageSendStatus.none,
    this.progress,
    DateTime? createdAt,
  }) : id =
           id ??
           'msg-${(createdAt ?? DateTime.now()).microsecondsSinceEpoch}-${_nextSequence++}',
       createdAt = createdAt ?? DateTime.now();

  static int _nextSequence = 0;

  final String id;
  final String text;
  final String sender;
  final bool isMe;
  final bool system;
  final MessageAttachment? attachment;
  final MessageSendStatus status;
  final DateTime createdAt;

  /// Upload progress in 0.0–1.0 while [status] is sending; null when unknown.
  final double? progress;

  ChatMessage copyWith({MessageSendStatus? status, double? progress}) {
    return ChatMessage(
      text,
      id: id,
      sender: sender,
      isMe: isMe,
      system: system,
      attachment: attachment,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'sender': sender,
      'isMe': isMe,
      'system': system,
      'attachment': attachment?.toJson(),
      'status': status.name,
      'progress': progress,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    var status = MessageSendStatus.values.firstWhere(
      (value) => value.name == json['status'],
      orElse: () => MessageSendStatus.none,
    );
    // No live transfer survives a restart, so a persisted "sending" message is
    // stuck — surface it as failed so the user can retry.
    if (status == MessageSendStatus.sending) {
      status = MessageSendStatus.failed;
    }
    final attachment = json['attachment'];
    return ChatMessage(
      json['text'] as String? ?? '',
      id: json['id'] as String?,
      sender: json['sender'] as String? ?? 'T',
      isMe: json['isMe'] as bool? ?? false,
      system: json['system'] as bool? ?? false,
      attachment: attachment is Map<String, dynamic>
          ? MessageAttachment.fromJson(attachment)
          : null,
      status: status,
      progress: status == MessageSendStatus.failed
          ? null
          : (json['progress'] as num?)?.toDouble(),
      createdAt: _parseMessageCreatedAt(json),
    );
  }

  static DateTime _parseMessageCreatedAt(Map<String, dynamic> json) {
    final stored = DateTime.tryParse(json['createdAt'] as String? ?? '');
    if (stored != null) return stored;
    final id = json['id'] as String? ?? '';
    final match = RegExp(r'^msg-(\d+)').firstMatch(id);
    final micros = match == null ? null : int.tryParse(match.group(1)!);
    if (micros != null) {
      return DateTime.fromMicrosecondsSinceEpoch(micros);
    }
    return DateTime.now();
  }
}
