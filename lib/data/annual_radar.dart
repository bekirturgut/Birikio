import 'dart:math' as math;
import 'store.dart';

class RadarExpense {
  final String id, title, category;
  final int amount;
  final DateTime due;
  final bool fromRule;
  final bool scheduled, paid;
  final bool income, recorded;
  final DateTime? plannedDue;
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
    this.income = false,
    this.recorded = false,
    this.plannedDue,
    this.period,
    this.paidAmount,
  });
}

List<RadarExpense> annualRadarItems(FinanceStore store, int year) {
  final entries = {for (final e in store.entries) e.id: e};
  final items = <RadarExpense>[];
  for (final plan in store.scheduledExpenses) {
    if (plan.due.year == year &&
        plan.paidAt == null &&
        !entries.containsKey('scheduled:${plan.id}')) {
      items.add(
        RadarExpense(
          id: plan.id,
          title: plan.title,
          category: plan.category,
          amount: plan.amount,
          due: plan.due,
          fromRule: false,
          scheduled: true,
          income: plan.income,
        ),
      );
    }
  }
  for (final plan in store.annualPlans) {
    final due = plan.dueIn(year);
    if (year >= plan.startYear &&
        (plan.endDate == null || !due.isAfter(day(plan.endDate!))) &&
        !entries.containsKey('annual:${plan.id}:$year')) {
      items.add(
        RadarExpense(
          id: plan.id,
          title: plan.title,
          category: plan.category,
          amount: plan.amount,
          due: due,
          fromRule: false,
        ),
      );
    }
  }
  for (final rule in store.rules.where((r) => r.active)) {
    var period = rule.firstPeriodOnOrAfter(DateTime(year, 1, 1));
    final end = DateTime(year + 1);
    while (rule.occurrence(period).isBefore(end)) {
      final due = rule.occurrence(period);
      if (rule.endDate != null && due.isAfter(day(rule.endDate!))) break;
      if (period >= rule.cursor && !entries.containsKey('${rule.id}:$period')) {
        items.add(
          RadarExpense(
            id: rule.id,
            title: rule.title,
            category: rule.category,
            amount: rule.amount,
            due: due,
            fromRule: true,
            income: rule.income,
            period: period,
          ),
        );
      }
      period++;
    }
  }
  // Completed transactions belong only to their actual payment/receipt date.
  for (final e in store.entries.where((e) => e.date.year == year)) {
    final rule = store.rules.where((r) => r.id == e.rule).firstOrNull;
    final period = rule == null
        ? null
        : int.tryParse(e.id.substring(e.id.lastIndexOf(':') + 1));
    final scheduled = store.scheduledExpenses
        .where((p) => 'scheduled:${p.id}' == e.id)
        .firstOrNull;
    DateTime? plannedDue = scheduled?.due;
    if (rule != null && period != null) plannedDue = rule.occurrence(period);
    if (e.id.startsWith('annual:')) {
      for (final p in store.annualPlans) {
        final dueYear = int.tryParse(e.id.substring(e.id.lastIndexOf(':') + 1));
        if (dueYear != null && e.id == 'annual:${p.id}:$dueYear') {
          plannedDue = p.dueIn(dueYear);
        }
      }
    }
    items.add(
      RadarExpense(
        id: scheduled?.id ?? rule?.id ?? e.id,
        title: e.title,
        category: e.category,
        amount: e.amount,
        due: e.date,
        plannedDue: e.plannedDue ?? plannedDue,
        fromRule: rule != null,
        scheduled: scheduled != null,
        income: e.income,
        recorded: true,
        paid: true,
        paidAmount: e.amount,
        period: period,
      ),
    );
  }
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
    while (store.entries.any((e) => e.id == 'annual:${plan.id}:${due.year}')) {
      due = plan.dueIn(due.year + 1);
    }
    if (plan.endDate != null && due.isAfter(day(plan.endDate!))) continue;
    final months = math.max(1, monthsUntil(now, due));
    result += (plan.amount + months - 1) ~/ months;
  }
  for (final rule in store.rules.where(
    (rule) => rule.active && !rule.income && rule.frequency == 4,
  )) {
    var index = math.max(rule.cursor, rule.firstPeriodOnOrAfter(day(now)));
    var due = rule.occurrence(index);
    while (due.isBefore(day(now)) ||
        store.entries.any((entry) => entry.id == '${rule.id}:$index')) {
      due = rule.occurrence(++index);
    }
    if (rule.endDate != null && due.isAfter(day(rule.endDate!))) continue;
    final months = math.max(1, monthsUntil(now, due));
    result += (rule.amount + months - 1) ~/ months;
  }
  return result;
}
