import 'package:flutter_test/flutter_test.dart';
import 'package:nearsend/models/receive_history_entry.dart';
import 'package:nearsend/services/receive_history_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

ReceiveHistoryEntry _entry(String id, {String name = 'file.bin'}) {
  return ReceiveHistoryEntry(
    id: id,
    fileName: name,
    size: 1024,
    senderAlias: 'Tester',
    path: 'C:\\tmp\\$name',
    autoSaved: true,
    receivedAt: DateTime(2026, 6, 10, 14, 30),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('persists and loads entries round-trip', () async {
    final store = ReceiveHistoryStore();
    final entries = [_entry('a', name: 'photo.png'), _entry('b')];

    await store.persist(entries);
    final loaded = await store.load();

    expect(loaded.length, 2);
    expect(loaded.first.id, 'a');
    expect(loaded.first.fileName, 'photo.png');
    expect(loaded.first.autoSaved, isTrue);
    expect(loaded.first.receivedAt, DateTime(2026, 6, 10, 14, 30));
  });

  test('caps persisted entries to maxEntries (keeps the newest first)', () async {
    final store = ReceiveHistoryStore();
    final entries = List.generate(
      ReceiveHistoryStore.maxEntries + 25,
      (index) => _entry('id-$index'),
    );

    await store.persist(entries);
    final loaded = await store.load();

    expect(loaded.length, ReceiveHistoryStore.maxEntries);
    expect(loaded.first.id, 'id-0');
  });

  test('returns empty list when nothing stored', () async {
    final loaded = await ReceiveHistoryStore().load();
    expect(loaded, isEmpty);
  });

  test('returns empty list on corrupt json', () async {
    SharedPreferences.setMockInitialValues({'receive_history': 'not-json{'});
    final loaded = await ReceiveHistoryStore().load();
    expect(loaded, isEmpty);
  });
}
