import 'dart:math' as math;
import 'store.dart';

class RadarExpense {
  final String id, title, category;
  final int amount;
  final DateTime due;
  final bool fromRule;
  final bool scheduled, paid;
  final int? period;
  final int? paidAmount;
  const RadarExpense({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.due,
    required this.fromRule,
    this.scheduled = false,
    this.paid = false,
    this.period,
    this.paidAmount,
  });
}

List<RadarExpense> annualRadarItems(FinanceStore store, int year) {
  int firstPeriod(RepeatRule rule) {
    final start = DateTime(year, 1, 1);
    if (!rule.start.isBefore(start)) return 0;
    return switch (rule.frequency) {
      1 => start.difference(rule.start).inDays,
      2 => start.difference(rule.start).inDays ~/ 7,
      3 => (year - rule.start.year) * 12 + 1 - rule.start.month,
      _ => year - rule.start.year,
    };
  }

  final items = <RadarExpense>[
    for (final expense in store.scheduledExpenses)
      if (!expense.income && expense.due.year == year)
        RadarExpense(
          id: expense.id,
          title: expense.title,
          category: expense.category,
          amount: expense.amount,
          due: expense.due,
          fromRule: false,
          scheduled: true,
          paid: expense.paidAt != null,
          paidAmount: store.entries
              .where((e) => e.id == 'scheduled:${expense.id}')
              .firstOrNull
              ?.amount,
        ),
    for (final plan in store.annualPlans)
      if (year >= plan.startYear &&
          (plan.endDate == null ||
              !plan.dueIn(year).isAfter(day(plan.endDate!))))
        RadarExpense(
          id: plan.id,
          title: plan.title,
          category: plan.category,
          amount: plan.amount,
          due: plan.dueIn(year),
          fromRule: false,
          paid: store.entries.any((e) => e.id == 'annual:${plan.id}:$year'),
          paidAmount: store.entries
              .where((e) => e.id == 'annual:${plan.id}:$year')
              .firstOrNull
              ?.amount,
        ),
    for (final rule in store.rules.where((r) => !r.income))
      for (
        var period = firstPeriod(rule);
        period < firstPeriod(rule) + 370 &&
            !rule.occurrence(period).isAfter(DateTime(year, 12, 31));
        period++
      )
        if (rule.occurrence(period).year == year &&
            (rule.active ||
                store.entries.any((e) => e.id == '${rule.id}:$period')) &&
            (rule.endDate == null ||
                !rule.occurrence(period).isAfter(day(rule.endDate!))))
          RadarExpense(
            id: rule.id,
            title: rule.title,
            category: rule.category,
            amount: rule.amount,
            due: rule.occurrence(period),
            fromRule: true,
            period: period,
            paid: store.entries.any((e) => e.id == '${rule.id}:$period'),
            paidAmount: store.entries
                .where((e) => e.id == '${rule.id}:$period')
                .firstOrNull
                ?.amount,
          ),
  ];
  items.sort((a, b) => a.due.compareTo(b.due));
  return items;
}

DateTime nextAnnualPlanDue(AnnualPlan plan, DateTime now) {
  final year = math.max(now.year, plan.startYear);
  final next = plan.dueIn(year);
  return next.isBefore(day(now)) ? plan.dueIn(year + 1) : next;
}

int suggestedMonthlyAnnualReserve(FinanceStore store, DateTime now) {
  var result = 0;
  for (final plan in store.annualPlans) {
    var due = nextAnnualPlanDue(plan, now);
    if (store.entries.any((e) => e.id == 'annual:${plan.id}:${due.year}')) {
      due = plan.dueIn(due.year + 1);
    }
    if (plan.endDate != null && due.isAfter(day(plan.endDate!))) continue;
    final months = math.max(1, monthsUntil(now, due));
    result += (plan.amount + months - 1) ~/ months;
  }
  for (final rule in store.rules.where(
    (rule) => rule.active && !rule.income && rule.frequency == 4,
  )) {
    var index = math.max(0, now.year - rule.start.year);
    var due = rule.occurrence(index);
    if (due.isBefore(day(now)) ||
        (due == day(now) &&
            store.entries.any((entry) => entry.id == '${rule.id}:$index'))) {
      due = rule.occurrence(++index);
    }
    final months = math.max(1, monthsUntil(now, due));
    result += (rule.amount + months - 1) ~/ months;
  }
  return result;
}
