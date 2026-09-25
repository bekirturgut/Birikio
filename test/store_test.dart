import 'package:flutter_test/flutter_test.dart';
import 'package:gelir_gider/data/store.dart';

void main() {
  FinanceStore memory() =>
      FinanceStore(read: () async => null, write: (_) async {});
  RepeatRule rule(DateTime date, int frequency) => RepeatRule(
    id: 'r',
    title: 'Maaş',
    amount: 10000,
    income: true,
    start: date,
    category: 'Maaş',
    frequency: frequency,
  );
  test('Turkish amounts keep exact cents and reject malformed input', () {
    expect(parseMoney('1.250,50'), 125050);
    expect(parseMoney('12,01'), 1201);
    expect(parseMoney('0'), isNull);
    expect(parseMoney('-25'), isNull);
    expect(parseMoney('NaN'), isNull);
    expect(parseMoney('1.2345'), isNull);
    expect(money(125050), '1.250,50 ₺');
  });
  test('Month end stays anchored and leap years recover', () {
    final monthly = rule(DateTime(2024, 1, 31), 3);
    expect(monthly.occurrence(1), DateTime(2024, 2, 29));
    expect(monthly.occurrence(2), DateTime(2024, 3, 31));
    final yearly = rule(DateTime(2024, 2, 29), 4);
    expect(yearly.occurrence(1), DateTime(2025, 2, 28));
    expect(yearly.occurrence(4), DateTime(2028, 2, 29));
  });
  test(
    'Catch-up is idempotent, preserves deleted occurrences, skips future',
    () async {
      final s = memory()..rules.add(rule(DateTime(2026, 1, 1), 1));
      await s.catchUp(now: DateTime(2026, 1, 5));
      expect(s.entries.length, 5);
      await s.catchUp(now: DateTime(2026, 1, 5));
      expect(s.entries.length, 5);
      s.entries.removeAt(0);
      await s.catchUp(now: DateTime(2026, 1, 6));
      expect(s.entries.length, 5);
      expect(s.entries.any((e) => e.date == DateTime(2026, 1, 1)), false);
      s.rules.first.active = false;
      await s.catchUp(now: DateTime(2026, 2, 1));
      expect(s.entries.length, 5);
    },
  );
  test('Weekly recurrence crosses years correctly', () {
    final s = memory()..rules.add(rule(DateTime(2025, 12, 29), 2));
    s.materialize(DateTime(2026, 1, 12));
    expect(s.entries.map((e) => e.date).toList(), [
      DateTime(2025, 12, 29),
      DateTime(2026, 1, 5),
      DateTime(2026, 1, 12),
    ]);
  });
  test(
    'Savings transfers conserve wealth and enforce available funds',
    () async {
      final s = memory();
      final g = Goal(id: 'g', title: 'Motor', icon: 'Motor', target: 500000);
      s.goals.add(g);
      s.entries.add(
        Entry(
          id: 'e',
          title: 'Maaş',
          amount: 100000,
          income: true,
          date: DateTime.now(),
          category: 'Maaş',
        ),
      );
      await s.move(g, 25000);
      expect(s.balance, 75000);
      expect(s.savings, 25000);
      expect(s.income, 100000);
      expect(s.expense, 0);
      await s.move(g, -10000);
      expect(s.balance, 85000);
      expect(s.saved(g), 15000);
      await expectLater(s.move(g, 100000), throwsStateError);
      await expectLater(s.move(g, -20000), throwsStateError);
      expect(s.balance + s.savings, 100000);
    },
  );
  test(
    'Writes persist across a new store; all financial data can be cleared',
    () async {
      String? disk;
      final s = FinanceStore(
        read: () async => disk,
        write: (value) async => disk = value,
      );
      await s.change(() {
        s.goals.add(Goal(id: 'g', title: 'Ev', icon: 'Ev', target: 100000));
        s.budgets['2026-9'] = 10000;
        s.dark = false;
      });
      final restored = FinanceStore(
        read: () async => disk,
        write: (value) async => disk = value,
      );
      await restored.load();
      expect(restored.goals.single.title, 'Ev');
      expect(restored.budgets['2026-9'], 10000);
      expect(restored.dark, false);
      await restored.clear();
      await s.load();
      expect(s.goals, isEmpty);
      expect(s.budgets, isEmpty);
      expect(s.balance, 0);
    },
  );
  test('Failed persistence rolls mutations back', () async {
    final s = FinanceStore(
      read: () async => null,
      write: (_) async => throw Exception('disk full'),
    );
    await expectLater(
      s.change(() => s.budgets['2026-9'] = 10000),
      throwsException,
    );
    expect(s.budgets, isEmpty);
    expect(s.busy, false);
  });
}
