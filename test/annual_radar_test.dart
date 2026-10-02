import 'dart:convert';
import 'package:birikio/data/annual_radar.dart';
import 'package:birikio/data/backup.dart';
import 'package:birikio/data/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:birikio/ui/app.dart';

void main() {
  testWidgets('expense page opens radar with a future expense', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime.now();
    final due = DateTime(now.year, now.month + 1, 10);
    final store = FinanceStore(read: () async => null, write: (_) async {})
      ..motion = false;
    store.scheduledExpenses.add(
      ScheduledExpense(
        id: 'future',
        title: 'Muayene',
        category: 'Sağlık',
        amount: 45000,
        due: due,
      ),
    );
    await tester.pumpWidget(BirikioApp(store: store));
    await tester.tap(find.text('Gelir & Gider').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Giderler'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Yıllık radar'));
    await tester.tap(find.text('Yıllık radar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Gerçekleşen ve bekleyen'), findsOneWidget);
    expect(store.balance, 0);
    expect(tester.takeException(), isNull);
  });

  test(
    'future expense stays out of balance until paid and appears in radar',
    () async {
      String? disk;
      final store = FinanceStore(
        read: () async => disk,
        write: (value) async => disk = value,
      );
      final expense = ScheduledExpense(
        id: 'future',
        title: 'Muayene',
        category: 'Sağlık',
        amount: 45000,
        due: DateTime(2027, 2, 10),
      );
      await store.change(() => store.scheduledExpenses.add(expense));
      expect(store.balance, 0);
      expect(annualRadarItems(store, 2027).single.id, 'future');
      await store.markScheduledExpensePaid(
        expense,
        paidAt: DateTime(2027, 2, 1),
        amount: 47000,
      );
      expect(store.expense, 47000);
      expect(annualRadarItems(store, 2027).single.paid, isTrue);
      expect(annualRadarItems(store, 2027).single.paidAmount, 47000);
      final reopened = FinanceStore(
        read: () async => disk,
        write: (_) async {},
      );
      await reopened.load();
      expect(reopened.scheduledExpenses.single.paidAt, DateTime(2027, 2, 1));
      expect(reopened.expense, 47000);
    },
  );

  test(
    'monthly rule ends on chosen date and radar shows each due date',
    () async {
      final store = FinanceStore(read: () async => null, write: (_) async {});
      store.rules.add(
        RepeatRule(
          id: 'rent',
          title: 'Kira',
          amount: 100000,
          income: false,
          start: DateTime(2027, 1, 5),
          category: 'Ev & faturalar',
          frequency: 3,
          endDate: DateTime(2027, 3, 5),
        ),
      );
      expect(annualRadarItems(store, 2027).map((e) => e.due.month), [1, 2, 3]);
      await store.catchUp(now: DateTime(2027, 5, 1));
      expect(store.entries.length, 3);
      expect(store.expense, 300000);
    },
  );

  test('backup rejects an invalid recurring end date', () {
    final store = FinanceStore(read: () async => null, write: (_) async {});
    store.rules.add(
      RepeatRule(
        id: 'r',
        title: 'Kira',
        amount: 10000,
        income: false,
        start: DateTime(2027, 1, 1),
        category: 'Ev & faturalar',
        frequency: 3,
      ),
    );
    final backup = jsonDecode(createBackup(store)) as Map<String, dynamic>;
    final data = backup['data'] as Map<String, dynamic>;
    (data['rules'] as List).first['endDate'] = '2026-12-31T00:00:00.000';
    expect(() => parseBackup(jsonEncode(backup)), throwsFormatException);
    expect(store.rules.single.endDate, isNull);
  });

  test('annual plan stops at its optional end date', () {
    final store = FinanceStore(read: () async => null, write: (_) async {});
    store.annualPlans.add(
      AnnualPlan(
        id: 'plan',
        title: 'Sigorta',
        category: 'Ulaşım',
        amount: 10000,
        month: 4,
        dueDay: 12,
        startYear: 2027,
        endDate: DateTime(2028, 12, 31),
      ),
    );
    expect(annualRadarItems(store, 2028).single.id, 'plan');
    expect(annualRadarItems(store, 2029), isEmpty);
    expect(suggestedMonthlyAnnualReserve(store, DateTime(2029, 1, 1)), 0);
  });

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
