import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/receive_history_entry.dart';

/// Persists the receive history as a JSON list in [SharedPreferences].
///
/// State owns the in-memory list; this store only loads and saves it, mirroring
/// how the rest of the app persists settings.
class ReceiveHistoryStore {
  static const _key = 'receive_history';

  /// Newest [maxEntries] are kept; older ones are dropped on persist.
  static const maxEntries = 200;

  Future<List<ReceiveHistoryEntry>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(ReceiveHistoryEntry.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> persist(List<ReceiveHistoryEntry> entries) async {
    final preferences = await SharedPreferences.getInstance();
    final capped = entries.take(maxEntries).toList();
    await preferences.setString(
      _key,
      jsonEncode(capped.map((entry) => entry.toJson()).toList()),
    );
  }
}
