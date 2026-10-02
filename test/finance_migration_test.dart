import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:birikio/data/finance_document.dart';
import 'package:birikio/data/store.dart';

void main() {
  final legacy = jsonEncode({
    'entries': [
      {
        'id': 'income',
        'title': 'Maaş',
        'amount': 100000,
        'income': true,
        'date': '2026-09-01T00:00:00.000',
        'category': 'Maaş',
        'note': '',
        'rule': null,
      },
      {
        'id': 'expense',
        'title': 'Kira',
        'amount': 20000,
        'income': false,
        'date': '2026-09-02T00:00:00.000',
        'category': 'Ev & faturalar',
        'note': '',
        'rule': 'rent',
      },
    ],
    'rules': [
      {
        'id': 'rent',
        'title': 'Kira',
        'amount': 20000,
        'income': false,
        'start': '2026-09-02T00:00:00.000',
        'category': 'Ev & faturalar',
        'frequency': 3,
        'note': '',
        'cursor': 1,
        'active': true,
        'endDate': '2026-09-02T00:00:00.000',
      },
    ],
    'goals': [
      {'id': 'goal', 'title': 'Motor', 'icon': 'Motor', 'target': 500000},
    ],
    'transfers': [
      {
        'id': 'transfer',
        'goal': 'goal',
        'amount': 10000,
        'date': '2026-09-03T00:00:00.000',
      },
    ],
    'budgets': {'2026-9': 30000},
    'dark': false,
    'followSystem': false,
    'motion': true,
    'pinned': 'goal',
  });

  test('legacy data opens unchanged and next write gains a version', () async {
    var disk = legacy;
    final store = FinanceStore(
      read: () async => disk,
      write: (value) async => disk = value,
    );
    await store.load();
    expect(store.entries.map((e) => e.id), ['income', 'expense']);
    expect(store.income, 100000);
    expect(store.expense, 20000);
    expect(store.savings, 10000);
    expect(store.balance, 70000);
    expect(store.rules.single.cursor, 1);
    expect(store.featured?.id, 'goal');
    expect(store.budgets['2026-9'], 30000);
    expect(store.dark, false);
    expect(store.followSystem, false);
    expect(store.motion, true);
    expect(disk, legacy); // Reading does not rewrite the user's data.

    await store.change(() => store.budgets['2026-10'] = 40000);
    expect(jsonDecode(disk)['schemaVersion'], financeSchemaVersion);
    final reopened = FinanceStore(read: () async => disk, write: (_) async {});
    await reopened.load();
    expect(reopened.balance, 70000);
    expect(reopened.entries.map((e) => e.id), ['income', 'expense']);
  });

  test(
    'invalid and newer documents leave live state and disk untouched',
    () async {
      var disk = legacy;
      final store = FinanceStore(
        read: () async => disk,
        write: (v) async => disk = v,
      );
      await store.load();
      final originalBalance = store.balance;
      final originalEntries = store.entries.map((e) => e.id).toList();
      for (final invalid in [
        '{broken',
        '[]',
        jsonEncode({
          ...jsonDecode(legacy),
          'schemaVersion': financeSchemaVersion + 1,
        }),
        jsonEncode({
          ...jsonDecode(legacy),
          'goals': [null],
        }),
      ]) {
        disk = invalid;
        await expectLater(store.load(), throwsA(isA<Object>()));
        expect(store.balance, originalBalance);
        expect(store.entries.map((e) => e.id), originalEntries);
        expect(disk, invalid);
      }
    },
  );
}
