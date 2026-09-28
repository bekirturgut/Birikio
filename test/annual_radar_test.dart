import 'dart:convert';
import 'package:birikio/data/annual_radar.dart';
import 'package:birikio/data/backup.dart';
import 'package:birikio/data/store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'annual plans and yearly repeat rules appear without changing balance',
    () async {
      String? saved;
      final store = FinanceStore(
        read: () async => saved,
        write: (raw) async => saved = raw,
      );
      await store.change(() {
        store.annualPlans.add(
          AnnualPlan(
            id: 'insurance',
            title: 'Sigorta',
            category: 'Ulaşım',
            amount: 120000,
            month: 2,
            dueDay: 29,
            startYear: 2026,
          ),
        );
        store.rules.add(
          RepeatRule(
            id: 'school',
            title: 'Okul',
            category: 'Eğitim',
            amount: 60000,
            income: false,
            start: DateTime(2025, 9, 15),
            frequency: 4,
            isBill: true,
            automaticPayment: false,
          ),
        );
      });
      expect(store.balance, 0);
      final items = annualRadarItems(store, 2026);
      expect(
        annualRadarItems(store, 2025).where((item) => item.id == 'insurance'),
        isEmpty,
      );
      expect(
        nextAnnualPlanDue(store.annualPlans.single, DateTime(2025, 9, 1)),
        DateTime(2026, 2, 28),
      );
      expect(items.map((item) => item.title), ['Sigorta', 'Okul']);
      expect(items.first.due, DateTime(2026, 2, 28));
      expect(annualRadarItems(store, 2028).first.due, DateTime(2028, 2, 29));
      expect(
        suggestedMonthlyAnnualReserve(store, DateTime(2026, 1, 1)),
        greaterThan(0),
      );
      await store.change(() {
        store.renameCategory(false, 'Ulaşım', 'Ulaşım ve araç');
        store.removeCategory(false, 'Ulaşım ve araç');
      });
      expect(store.annualPlans.single.category, 'Ulaşım ve araç');
      final restored = FinanceStore(
        read: () async => saved,
        write: (_) async {},
      );
      await restored.load();
      expect(restored.annualPlans.single.title, 'Sigorta');
      expect(restored.annualPlans.single.category, 'Ulaşım ve araç');
      expect(restored.balance, 0);
    },
  );

  test(
    'old backup gains an empty radar and invalid new plans never replace data',
    () {
      final store = FinanceStore(read: () async => null, write: (_) async {});
      store.annualPlans.add(
        AnnualPlan(
          id: 'a',
          title: 'Bakım',
          category: 'Ulaşım',
          amount: 10000,
          month: 6,
          dueDay: 15,
          startYear: 2026,
        ),
      );
      final old = jsonDecode(createBackup(store)) as Map<String, dynamic>;
      old['schemaVersion'] = 11;
      final oldData = old['data'] as Map<String, dynamic>;
      oldData['schemaVersion'] = 11;
      oldData.remove('annualPlans');
      expect(parseBackup(jsonEncode(old))['annualPlans'], isEmpty);
      final corrupted = jsonDecode(createBackup(store)) as Map<String, dynamic>;
      ((corrupted['data'] as Map)['annualPlans'] as List).first['month'] = 13;
      expect(() => parseBackup(jsonEncode(corrupted)), throwsFormatException);
      expect(store.annualPlans.single.month, 6);
    },
  );

  test('monthly suggestion moves past a paid yearly occurrence', () {
    final store = FinanceStore(read: () async => null, write: (_) async {});
    store.rules.add(
      RepeatRule(
        id: 'r',
        title: 'Sigorta',
        category: 'Ulaşım',
        amount: 120000,
        income: false,
        start: DateTime(2025, 9, 28),
        frequency: 4,
      ),
    );
    final before = suggestedMonthlyAnnualReserve(store, DateTime(2026, 9, 28));
    store.entries.add(
      Entry(
        id: 'r:1',
        title: 'Sigorta',
        amount: 120000,
        income: false,
        date: DateTime(2026, 9, 28),
        category: 'Ulaşım',
      ),
    );
    final after = suggestedMonthlyAnnualReserve(store, DateTime(2026, 9, 28));
    expect(before, 120000);
    expect(after, lessThan(before));
  });
}
