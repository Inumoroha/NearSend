/// One received file recorded in the receive history.
///
/// File type/icon are not stored — they are derived from [fileName]'s
/// extension at render time, so this stays a thin, JSON-friendly record.
class ReceiveHistoryEntry {
  const ReceiveHistoryEntry({
    required this.id,
    required this.fileName,
    required this.size,
    required this.senderAlias,
    required this.path,
    required this.autoSaved,
    required this.receivedAt,
  });

  factory ReceiveHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ReceiveHistoryEntry(
      id: json['id'] is String && (json['id'] as String).isNotEmpty
          ? json['id'] as String
          : 'history-${DateTime.now().microsecondsSinceEpoch}',
      fileName: json['fileName'] is String ? json['fileName'] as String : '',
      size: json['size'] is int ? json['size'] as int : 0,
      senderAlias: json['senderAlias'] is String
          ? json['senderAlias'] as String
          : '',
      path: json['path'] is String ? json['path'] as String : '',
      autoSaved: json['autoSaved'] is bool ? json['autoSaved'] as bool : false,
      receivedAt:
          DateTime.tryParse(
            json['receivedAt'] is String ? json['receivedAt'] as String : '',
          ) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final String id;
  final String fileName;
  final int size;
  final String senderAlias;

  /// Absolute path to the received file (auto-save dir or a temp dir).
  final String path;

  /// Whether the file landed in the user's auto-save directory (vs a temp dir).
  final bool autoSaved;
  final DateTime receivedAt;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'fileName': fileName,
      'size': size,
      'senderAlias': senderAlias,
      'path': path,
      'autoSaved': autoSaved,
      'receivedAt': receivedAt.toIso8601String(),
    };
  }
}
