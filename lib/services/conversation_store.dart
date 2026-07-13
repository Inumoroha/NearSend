import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists the per-device conversations (devices + chat history) as a JSON
/// object in [SharedPreferences], keyed by device fingerprint.
///
/// This is a thin persistence layer: it stores and returns already-decoded
/// JSON maps. The owning state converts to/from its Conversation model,
/// mirroring how the rest of the app persists settings (see
/// ReceiveHistoryStore).
class ConversationStore {
  static const _key = 'device_conversations';

  /// Returns a map of fingerprint -> conversation JSON, or empty if nothing was
  /// persisted or the stored value is unreadable.
  Future<Map<String, Map<String, dynamic>>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key);
    if (raw == null || raw.isEmpty) return {};

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final result = <String, Map<String, dynamic>>{};
      decoded.forEach((key, value) {
        if (key is String && value is Map<String, dynamic>) {
          result[key] = value;
        }
      });
      return result;
    } catch (_) {
      return {};
    }
  }

  Future<void> persist(Map<String, Map<String, dynamic>> conversations) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_key, jsonEncode(conversations));
  }
}
