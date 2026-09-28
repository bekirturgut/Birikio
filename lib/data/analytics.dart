import 'store.dart';

class PeriodInsights {
  final int income, expense, previousIncome, previousExpense;
  final int dailyAverage, goalTransfers;
  final String? topCategory;
  final DateTime? highestDay;
  final int? projectedMonthlyExpense;

  const PeriodInsights({
    required this.income,
    required this.expense,
    required this.previousIncome,
    required this.previousExpense,
    required this.dailyAverage,
    required this.goalTransfers,
    required this.topCategory,
    required this.highestDay,
    required this.projectedMonthlyExpense,
  });
}

PeriodInsights calculateInsights(
  FinanceStore store,
  DateTime start,
  DateTime end, {
  required DateTime previousStart,
  required DateTime now,
  bool monthly = false,
}) {
  final current = store.entries.where(
    (e) => !e.date.isBefore(start) && e.date.isBefore(end),
  );
  final previous = store.entries.where(
    (e) => !e.date.isBefore(previousStart) && e.date.isBefore(start),
  );
  int total(Iterable<Entry> entries, bool income) => entries
      .where((e) => e.income == income)
      .fold(0, (sum, e) => sum + e.amount);
  final expenses = current.where((e) => !e.income).toList();
  final byCategory = <String, int>{};
  final byDay = <DateTime, int>{};
  for (final e in expenses) {
    byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
    final date = day(e.date);
    byDay[date] = (byDay[date] ?? 0) + e.amount;
  }
  final sortedCategories = byCategory.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final sortedDays = byDay.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final expense = total(current, false);
  final elapsedEnd = now.isBefore(end)
      ? now
      : end.subtract(const Duration(days: 1));
  final elapsedDays = day(elapsedEnd).difference(day(start)).inDays + 1;
  final days = elapsedDays.clamp(1, end.difference(start).inDays);
  final monthlyProjection =
      monthly &&
          !now.isBefore(start) &&
          now.isBefore(end) &&
          days >= 7 &&
          expenses.isNotEmpty
      ? (expense * end.difference(start).inDays / days).round()
      : null;
  return PeriodInsights(
    income: total(current, true),
    expense: expense,
    previousIncome: total(previous, true),
    previousExpense: total(previous, false),
    dailyAverage: (expense / days).round(),
    goalTransfers: store.transfers
        .where((t) => !t.date.isBefore(start) && t.date.isBefore(end))
        .fold(0, (sum, t) => sum + t.amount),
    topCategory: sortedCategories.isEmpty ? null : sortedCategories.first.key,
    highestDay: sortedDays.isEmpty ? null : sortedDays.first.key,
    projectedMonthlyExpense: monthlyProjection,
  );
}
