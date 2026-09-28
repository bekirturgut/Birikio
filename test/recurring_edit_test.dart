import 'package:flutter_test/flutter_test.dart';
import 'package:birikio/data/store.dart';

void main() {
  test(
    'single, future and whole-series edits keep the intended periods',
    () async {
      final store = FinanceStore(read: () async => null, write: (_) async {});
      store.rules.add(
        RepeatRule(
          id: 'r',
          title: 'Fatura',
          amount: 1000,
          income: false,
          start: DateTime(2026, 1, 31),
          category: 'Ev & faturalar',
          frequency: 3,
        ),
      );
      await store.catchUp(now: DateTime(2026, 3, 31));
      final january = store.entries.firstWhere((e) => e.date.month == 1);
      final february = store.entries.firstWhere((e) => e.date.month == 2);
      final march = store.entries.firstWhere((e) => e.date.month == 3);
      Entry edited(Entry entry, int amount) => Entry(
        id: entry.id,
        title: 'Yeni fatura',
        amount: amount,
        income: false,
        date: entry.date,
        category: 'Ev & faturalar',
        rule: 'r',
      );

      await store.change(
        () => store.updateRecurringEntry(february, edited(february, 2000), 0),
      );
      expect(store.entries.firstWhere((e) => e.id == february.id).amount, 2000);
      expect(store.rules.single.amount, 1000);
      await store.change(
        () => store.updateRecurringEntry(march, edited(march, 3000), 1),
      );
      expect(store.entries.firstWhere((e) => e.id == january.id).amount, 1000);
      expect(store.entries.firstWhere((e) => e.id == february.id).amount, 2000);
      expect(store.entries.firstWhere((e) => e.id == march.id).amount, 3000);
      expect(store.rules.single.amount, 3000);
      await store.catchUp(now: DateTime(2026, 4, 30));
      expect(store.entries.firstWhere((e) => e.date.month == 4).amount, 3000);
      await store.change(
        () => store.updateRecurringEntry(january, edited(january, 4000), 2),
      );
      expect(store.entries.every((e) => e.amount == 4000), true);
      expect(store.rules.single.amount, 4000);
      expect(
        store.entries.map((e) => e.id).toSet().length,
        store.entries.length,
      );
    },
  );

  test(
    'stopped series and deleted period stay stable after reopening',
    () async {
      String? disk;
      FinanceStore createStore() => FinanceStore(
        read: () async => disk,
        write: (value) async => disk = value,
      );
      final store = createStore();
      store.rules.add(
        RepeatRule(
          id: 'series',
          title: 'Abonelik',
          amount: 500,
          income: false,
          start: DateTime(2024, 2, 29),
          category: 'Ev & faturalar',
          frequency: 4,
        ),
      );
      await store.catchUp(now: DateTime(2026, 2, 28));
      expect(store.entries.map((e) => e.date.day), [29, 28, 28]);
      await store.change(() {
        store.entries.removeWhere((e) => e.id == 'series:1');
        store.rules.single.active = false;
      });
      final reopened = createStore();
      await reopened.load();
      await reopened.catchUp(now: DateTime(2027, 3, 1));
      expect(reopened.entries.map((e) => e.id), ['series:0', 'series:2']);
      expect(reopened.rules.single.active, isFalse);
    },
  );
}
