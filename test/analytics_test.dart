import 'package:flutter_test/flutter_test.dart';
import 'package:birikio/data/analytics.dart';
import 'package:birikio/data/financial_health.dart';
import 'package:birikio/data/store.dart';

void main() {
  test('period insights separate previous period and goal transfers', () {
    final store = FinanceStore(read: () async => null, write: (_) async {});
    store.entries.addAll([
      Entry(
        id: '1',
        title: 'Maaş',
        amount: 200000,
        income: true,
        date: DateTime(2026, 9, 1),
        category: 'Maaş',
      ),
      Entry(
        id: '2',
        title: 'Market',
        amount: 30000,
        income: false,
        date: DateTime(2026, 9, 3),
        category: 'Market',
      ),
      Entry(
        id: '3',
        title: 'Market',
        amount: 10000,
        income: false,
        date: DateTime(2026, 9, 3),
        category: 'Market',
      ),
      Entry(
        id: '4',
        title: 'Ulaşım',
        amount: 20000,
        income: false,
        date: DateTime(2026, 8, 15),
        category: 'Ulaşım',
      ),
    ]);
    store.transfers.add(
      Transfer(id: 't', goal: 'g', amount: 15000, date: DateTime(2026, 9, 4)),
    );
    final result = calculateInsights(
      store,
      DateTime(2026, 9),
      DateTime(2026, 10),
      previousStart: DateTime(2026, 8),
      now: DateTime(2026, 9, 10),
      monthly: true,
    );
    expect(result.income, 200000);
    expect(result.expense, 40000);
    expect(result.previousExpense, 20000);
    expect(result.goalTransfers, 15000);
    expect(result.topCategory, 'Market');
    expect(result.highestDay, DateTime(2026, 9, 3));
    expect(result.dailyAverage, 4000);
    expect(result.projectedMonthlyExpense, 120000);
  });

  test('empty and short periods do not invent a forecast', () {
    final store = FinanceStore(read: () async => null, write: (_) async {});
    final result = calculateInsights(
      store,
      DateTime(2026, 9),
      DateTime(2026, 10),
      previousStart: DateTime(2026, 8),
      now: DateTime(2026, 9, 2),
      monthly: true,
    );
    expect(result.dailyAverage, 0);
    expect(result.topCategory, isNull);
    expect(result.projectedMonthlyExpense, isNull);
  });

  test('budget factor responds to spending and limits', () {
    final store = FinanceStore(read: () async => null, write: (_) async {});
    final month = DateTime(2026, 9);
    expect(financialHealthReport(store, month).score, isNull);
    store.budgets[store.budgetKey(month)] = 10000;
    final initial = financialHealthReport(store, month);
    expect(initial.factors.single.title, 'Bütçe sınırları');
    store.entries.add(
      Entry(
        id: 'a',
        title: 'Gider',
        amount: 9000,
        income: false,
        date: month,
        category: 'Market',
      ),
    );
    final withExpense = financialHealthReport(store, month);
    expect(
      withExpense.factors.firstWhere((f) => f.title == 'Bütçe sınırları').score,
      lessThan(initial.factors.single.score),
    );
    store.categoryBudgets[store.budgetKey(month)] = {'Market': 5000};
    expect(
      financialHealthReport(
        store,
        month,
      ).factors.firstWhere((f) => f.title == 'Bütçe sınırları').explanation,
      contains('2 limit'),
    );
    store.entries.clear();
    expect(
      financialHealthReport(
        store,
        month,
      ).factors.firstWhere((f) => f.title == 'Bütçe sınırları').score,
      initial.factors.single.score,
    );
  });
}
