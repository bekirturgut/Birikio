import 'package:flutter_test/flutter_test.dart';
import 'package:birikio/data/store.dart';

void main() {
  test('multiple due day changes preserve earlier period dates', () {
    final rule = RepeatRule(
      id: 'due',
      title: 'Kira',
      amount: 1000,
      income: false,
      start: DateTime(2026, 1, 31),
      category: 'Ev & faturalar',
      frequency: 3,
    );
    rule.dueDayChanges[2] = 15;
    rule.dueDayChanges[4] = 20;
    expect(rule.occurrence(0), DateTime(2026, 1, 31));
    expect(rule.occurrence(1), DateTime(2026, 2, 28));
    expect(rule.occurrence(2), DateTime(2026, 3, 15));
    expect(rule.occurrence(3), DateTime(2026, 4, 15));
    expect(rule.occurrence(4), DateTime(2026, 5, 20));
    final reloaded = RepeatRule.read(rule.json());
    expect(reloaded.occurrence(2), DateTime(2026, 3, 15));
    expect(reloaded.occurrence(4), DateTime(2026, 5, 20));
  });
  test(
    'manual bill affects balance only after payment and once per period',
    () async {
      String? disk;
      final store = FinanceStore(
        read: () async => disk,
        write: (value) async => disk = value,
      );
      final bill = RepeatRule(
        id: 'bill',
        title: 'Elektrik',
        amount: 25000,
        income: false,
        start: DateTime(2026, 1, 31),
        category: 'Ev & faturalar',
        frequency: 3,
        isBill: true,
        automaticPayment: false,
      );
      await store.change(() => store.rules.add(bill));
      await store.catchUp(now: DateTime(2026, 2, 28));
      expect(store.expense, 0);
      expect(store.firstUnpaidBillPeriod(bill), 0);
      await store.markBillPaid(bill, 0, paidAt: DateTime(2026, 2, 1));
      expect(store.expense, 25000);
      expect(store.firstUnpaidBillPeriod(bill), 1);
      await expectLater(
        store.markBillPaid(bill, 0, paidAt: DateTime(2026, 2, 1)),
        throwsStateError,
      );
      await store.markBillPaid(bill, 1, paidAt: DateTime(2026, 2, 28));
      expect(store.expense, 50000);
      final reopened = FinanceStore(
        read: () async => disk,
        write: (_) async {},
      );
      await reopened.load();
      expect(reopened.expense, 50000);
      expect(reopened.firstUnpaidBillPeriod(reopened.rules.single), 2);
    },
  );

  test('automatic bill follows recurrence without duplicate periods', () async {
    final store = FinanceStore(read: () async => null, write: (_) async {});
    store.rules.add(
      RepeatRule(
        id: 'auto',
        title: 'Abonelik',
        amount: 10000,
        income: false,
        start: DateTime(2026, 1, 31),
        category: 'Eğlence',
        frequency: 3,
        isBill: true,
      ),
    );
    await store.catchUp(now: DateTime(2026, 3, 31));
    await store.catchUp(now: DateTime(2026, 3, 31));
    expect(store.entries.length, 3);
    expect(store.expense, 30000);
    expect(store.entries.map((e) => e.date.day), [31, 28, 31]);
  });
}
