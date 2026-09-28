import 'package:birikio/data/financial_health.dart';
import 'package:birikio/data/store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 28);
  FinanceStore store() =>
      FinanceStore(read: () async => null, write: (_) async {});
  Entry entry(
    String id,
    int amount,
    bool income,
    DateTime date, {
    String category = 'Diğer',
    String? rule,
  }) => Entry(
    id: id,
    title: id,
    amount: amount,
    income: income,
    date: date,
    category: category,
    rule: rule,
  );
  HealthFactor factor(FinancialHealthReport report, String title) =>
      report.factors.firstWhere((f) => f.title == title);

  test(
    'missing data has no invented score and current month is not used for completed-month trend',
    () {
      final data = store();
      data.budgets[data.budgetKey(now)] = 100000;
      expect(financialHealthReport(data, now).score, isNull);
      data.entries.add(entry('income', 100000, true, now));
      final report = financialHealthReport(data, now);
      expect(report.score, isNotNull);
      expect(report.dataQuality, 'İlk veriler');
      expect(report.factors.any((f) => f.title == 'Aylık gidişat'), isFalse);
    },
  );

  test(
    'repeated withdrawals lower savings factor and create a specific warning',
    () {
      final data = store();
      data.goals.add(
        Goal(id: 'goal', title: 'Ev', icon: 'Ev', target: 1000000),
      );
      data.entries.add(entry('income', 100000, true, DateTime(2026, 9, 1)));
      data.transfers.add(
        Transfer(
          id: 'deposit',
          goal: 'goal',
          amount: 20000,
          date: DateTime(2026, 9, 2),
        ),
      );
      final before = financialHealthReport(data, now);
      data.transfers.addAll([
        Transfer(
          id: 'out1',
          goal: 'goal',
          amount: -5000,
          date: DateTime(2026, 9, 3),
        ),
        Transfer(
          id: 'out2',
          goal: 'goal',
          amount: -5000,
          date: DateTime(2026, 9, 4),
        ),
      ]);
      final after = financialHealthReport(data, now);
      expect(
        factor(after, 'Birikim hareketleri').score,
        lessThan(factor(before, 'Birikim hareketleri').score),
      );
      expect(after.score, lessThan(before.score!));
      expect(
        after.observations.any((v) => v.contains('2 kez para çektin')),
        isTrue,
      );
    },
  );

  test(
    'late and unpaid manual bills reduce score; due-today unpaid bill waits',
    () {
      final data = store();
      final bill = RepeatRule(
        id: 'bill',
        title: 'Fatura',
        amount: 10000,
        income: false,
        start: DateTime(2026, 7, 10),
        category: 'Ev & faturalar',
        frequency: 3,
        isBill: true,
        automaticPayment: false,
      );
      data.rules.add(bill);
      data.entries.add(
        entry('bill:0', 10000, false, DateTime(2026, 7, 10), rule: 'bill'),
      );
      final unpaid = financialHealthReport(data, now);
      expect(factor(unpaid, 'Fatura düzeni').score, lessThan(100));
      expect(
        unpaid.observations.any((v) => v.contains('vadesi geçti')),
        isTrue,
      );
      data.entries.add(
        entry('bill:1', 10000, false, DateTime(2026, 8, 15), rule: 'bill'),
      );
      data.entries.add(
        entry('bill:2', 10000, false, DateTime(2026, 9, 10), rule: 'bill'),
      );
      final settled = financialHealthReport(data, now);
      expect(
        factor(settled, 'Fatura düzeni').score,
        greaterThan(factor(unpaid, 'Fatura düzeni').score),
      );
      expect(factor(settled, 'Fatura düzeni').score, lessThan(100));

      final dueToday = store();
      dueToday.rules.add(
        RepeatRule(
          id: 'today',
          title: 'Bugün',
          amount: 10000,
          income: false,
          start: now,
          category: 'Ev & faturalar',
          frequency: 3,
          isBill: true,
          automaticPayment: false,
        ),
      );
      expect(
        financialHealthReport(
          dueToday,
          now,
        ).factors.any((f) => f.title == 'Fatura düzeni'),
        isFalse,
      );
    },
  );

  test(
    'old daily rule still counts recent occurrences and category report tracks largest expense',
    () {
      final data = store();
      data.rules.add(
        RepeatRule(
          id: 'old',
          title: 'Günlük',
          amount: 100,
          income: false,
          start: DateTime(2020, 1),
          category: 'Ev & faturalar',
          frequency: 1,
          isBill: true,
          automaticPayment: false,
        ),
      );
      data.entries.addAll([
        entry('market', 7000, false, DateTime(2026, 9, 1), category: 'Market'),
        entry('other', 3000, false, DateTime(2026, 9, 2), category: 'Ulaşım'),
      ]);
      final report = financialHealthReport(data, now);
      expect(report.topCategory, 'Market');
      expect(report.topCategoryShare, 70);
      expect(factor(report, 'Fatura düzeni').score, 0);
    },
  );

  test(
    'monthly savings promise changes score and highlights the missing amount',
    () {
      final data = store();
      data.entries.add(entry('income', 100000, true, DateTime(2026, 9, 1)));
      data.goals.add(
        Goal(
          id: 'goal',
          title: 'Birikim',
          icon: 'Birikim',
          target: 500000,
          monthlyContribution: 20000,
          monthlyDueDay: 15,
          monthlyPlanStart: DateTime(2026, 9, 1),
        ),
      );
      data.transfers.add(
        Transfer(
          id: 'early',
          goal: 'goal',
          amount: 5000,
          date: DateTime(2026, 9, 5),
        ),
      );
      final missing = financialHealthReport(data, now);
      expect(missing.attention, contains('150,00 ₺ eksik'));
      expect(factor(missing, 'Aylık birikim sözü').score, 25);
      data.transfers.add(
        Transfer(
          id: 'late',
          goal: 'goal',
          amount: 15000,
          date: DateTime(2026, 9, 20),
        ),
      );
      final caughtUp = financialHealthReport(data, now);
      expect(caughtUp.attention, contains('vade gününden sonra'));
      expect(factor(caughtUp, 'Aylık birikim sözü').score, greaterThan(25));
      expect(factor(caughtUp, 'Aylık birikim sözü').score, lessThan(100));
    },
  );
}
