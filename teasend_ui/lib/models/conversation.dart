import 'chat_message.dart';
import 'discovered_device.dart';
import 'transfer_file.dart';

class Conversation {
  Conversation({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.time,
    required this.initials,
    required this.messages,
    required this.files,
    this.unread = 0,
    this.device,
    this.ephemeral = false,
  });

  final String title;
  final String subtitle;
  final String status;
  final String time;
  final String initials;
  final int unread;
  final List<ChatMessage> messages;
  final List<TransferFile> files;
  final DiscoveredDevice? device;

  /// True for a placeholder created purely from LAN discovery (no real message
  /// exchanged yet). Ephemeral conversations are not persisted to disk, so a
  /// device merely seen on the network does not accumulate as a ghost chat.
  final bool ephemeral;

  Conversation copyWith({
    String? title,
    String? subtitle,
    String? status,
    String? time,
    String? initials,
    int? unread,
    List<ChatMessage>? messages,
    List<TransferFile>? files,
    DiscoveredDevice? device,
  }) {
    return Conversation(
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      status: status ?? this.status,
      time: time ?? this.time,
      initials: initials ?? this.initials,
      unread: unread ?? this.unread,
      messages: messages ?? this.messages,
      files: files ?? this.files,
      device: device ?? this.device,
      ephemeral: ephemeral,
    );
  }

  Conversation removeMessages(Set<String> messageIds) {
    final nextMessages = messages
        .where((message) => !messageIds.contains(message.id))
        .toList();
    if (nextMessages.length == messages.length) return this;

    final lastMessage = nextMessages.isEmpty ? null : nextMessages.last;
    return Conversation(
      title: title,
      subtitle: lastMessage == null ? '暂无聊天记录' : _subtitleFor(lastMessage),
      status: status,
      time: lastMessage == null ? time : '刚刚',
      initials: initials,
      unread: unread,
      messages: nextMessages,
      files: files,
      device: device,
      ephemeral: ephemeral,
    );
  }

  Conversation appendMessage(
    ChatMessage message, {
    required String subtitle,
    required int unread,
  }) {
    return Conversation(
      title: title,
      subtitle: subtitle,
      status: status,
      time: '刚刚',
      initials: initials,
      unread: unread,
      messages: [...messages, message],
      files: files,
      device: device,
      // A real message exchange promotes the conversation out of the
      // discovery-only placeholder state, so it is now worth persisting.
      ephemeral: false,
    );
  }

  Conversation updateMessageStatus(String messageId, MessageSendStatus status) {
    var changed = false;
    final nextMessages = messages.map((message) {
      if (message.id != messageId) return message;
      changed = true;
      return message.copyWith(status: status);
    }).toList();
    if (!changed) return this;

    return Conversation(
      title: title,
      subtitle: subtitle,
      status: this.status,
      time: time,
      initials: initials,
      unread: unread,
      messages: nextMessages,
      files: files,
      device: device,
      ephemeral: ephemeral,
    );
  }

  Conversation updateMessageProgress(String messageId, double progress) {
    var changed = false;
    final nextMessages = messages.map((message) {
      if (message.id != messageId) return message;
      changed = true;
      return message.copyWith(progress: progress);
    }).toList();
    if (!changed) return this;

    return Conversation(
      title: title,
      subtitle: subtitle,
      status: status,
      time: time,
      initials: initials,
      unread: unread,
      messages: nextMessages,
      files: files,
      device: device,
      ephemeral: ephemeral,
    );
  }

  String _subtitleFor(ChatMessage message) {
    final attachment = message.attachment;
    if (attachment != null) {
      return attachment.isImage
          ? '[图片] ${attachment.name}'
          : '[文件] ${attachment.name}';
    }
    return message.text;
  }

  /// Serializes the conversation (including chat history and the associated
  /// device) for local persistence across restarts.
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'subtitle': subtitle,
      'status': status,
      'time': time,
      'initials': initials,
      'unread': unread,
      'ephemeral': ephemeral,
      'messages': messages.map((message) => message.toJson()).toList(),
      'files': files.map((file) => file.toJson()).toList(),
      'device': device?.toJson(),
    };
  }

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final device = json['device'];
    return Conversation(
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      status: json['status'] as String? ?? '',
      time: json['time'] as String? ?? '',
      initials: json['initials'] as String? ?? '?',
      unread: json['unread'] is int ? json['unread'] as int : 0,
      ephemeral: json['ephemeral'] is bool ? json['ephemeral'] as bool : false,
      messages:
          (json['messages'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(ChatMessage.fromJson)
              .toList() ??
          [],
      files:
          (json['files'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(TransferFile.fromJson)
              .toList() ??
          [],
      device: device is Map<String, dynamic>
          ? DiscoveredDevice.fromJson(device)
          : null,
    );
  }
}
