import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:birikio/data/backup.dart';
import 'package:birikio/data/store.dart';

void main() {
  test('backup round trip replaces data without duplication', () async {
    final source = FinanceStore(read: () async => null, write: (_) async {});
    source.entries.add(
      Entry(
        id: 'one',
        title: 'Maaş',
        amount: 10000,
        income: true,
        date: DateTime(2026, 9, 1),
        category: 'Maaş',
      ),
    );
    final backup = createBackup(source, createdAt: DateTime.utc(2026, 9, 1));
    final target = FinanceStore(read: () async => null, write: (_) async {});
    await restoreBackup(target, backup);
    await restoreBackup(target, backup);
    expect(target.entries, hasLength(1));
    expect(target.entries.single.amount, 10000);
    expect(target.showWidgetBalance, isFalse);
  });

  test('invalid backup never overwrites live data', () async {
    final store = FinanceStore(read: () async => null, write: (_) async {});
    store.entries.add(
      Entry(
        id: 'keep',
        title: 'Keep',
        amount: 100,
        income: true,
        date: DateTime(2026, 9, 1),
        category: 'Maaş',
      ),
    );
    final root = jsonDecode(createBackup(store)) as Map<String, dynamic>;
    final data = root['data'] as Map<String, dynamic>;
    (data['entries'] as List).add(
      Map<String, dynamic>.from((data['entries'] as List).first),
    );
    expect(() => parseBackup(jsonEncode(root)), throwsFormatException);
    expect(store.entries.single.id, 'keep');
    (data['entries'] as List).removeLast();
    (data['entries'] as List).first['amount'] = -1;
    expect(() => parseBackup(jsonEncode(root)), throwsFormatException);
    root['schemaVersion'] = 999;
    expect(() => parseBackup(jsonEncode(root)), throwsFormatException);
  });

  test('CSV uses Turkish separator and escapes user text', () {
    final store = FinanceStore(read: () async => null, write: (_) async {});
    store.entries.add(
      Entry(
        id: 'one',
        title: 'A;B',
        amount: 12550,
        income: false,
        date: DateTime(2026, 9, 1),
        category: 'Ev',
        note: '"not"',
      ),
    );
    final csv = createCsv(store);
    expect(csv.startsWith('\uFEFF'), isTrue);
    expect(csv, contains('125,50;"Ev";"A;B";"""not"""'));
  });
}
