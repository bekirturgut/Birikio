import 'dart:math' as math;
import 'store.dart';

class RadarExpense {
  final String id, title, category;
  final int amount;
  final DateTime due;
  final bool fromRule;
  const RadarExpense({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.due,
    required this.fromRule,
  });
}

List<RadarExpense> annualRadarItems(FinanceStore store, int year) {
  final items = <RadarExpense>[
    for (final plan in store.annualPlans)
      if (year >= plan.startYear)
        RadarExpense(
          id: plan.id,
          title: plan.title,
          category: plan.category,
          amount: plan.amount,
          due: plan.dueIn(year),
          fromRule: false,
        ),
    for (final rule in store.rules.where(
      (rule) => rule.active && !rule.income && rule.frequency == 4,
    ))
      if (rule.start.year <= year)
        RadarExpense(
          id: rule.id,
          title: rule.title,
          category: rule.category,
          amount: rule.amount,
          due: rule.occurrence(year - rule.start.year),
          fromRule: true,
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
    final months = math.max(1, monthsUntil(now, nextAnnualPlanDue(plan, now)));
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
