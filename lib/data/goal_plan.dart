import 'dart:math' as math;

import 'store.dart';

class MonthlyGoalStatus {
  final DateTime dueDate;
  final int required, netDeposited, onTimeDeposited, missing;
  final bool duePassed, late, onTimeSatisfied;

  const MonthlyGoalStatus({
    required this.dueDate,
    required this.required,
    required this.netDeposited,
    required this.onTimeDeposited,
    required this.missing,
    required this.duePassed,
    required this.late,
    required this.onTimeSatisfied,
  });
}

MonthlyGoalStatus? monthlyGoalStatus(
  Goal goal,
  Iterable<Transfer> transfers,
  DateTime month, {
  DateTime? now,
}) {
  final required = goal.monthlyContribution;
  final dueDay = goal.monthlyDueDay;
  final planStart = goal.monthlyPlanStart;
  if (required == null ||
      required <= 0 ||
      dueDay == null ||
      planStart == null) {
    return null;
  }
  final first = DateTime(month.year, month.month);
  final next = DateTime(month.year, month.month + 1);
  final due = DateTime(
    month.year,
    month.month,
    math.min(dueDay, DateTime(month.year, month.month + 1, 0).day),
  );
  if (!planStart.isBefore(next) || day(planStart).isAfter(due)) return null;
  final clock = day(now ?? DateTime.now());
  if (clock.isBefore(day(planStart))) return null;
  final savedBefore = transfers
      .where((t) => t.goal == goal.id && t.date.isBefore(first))
      .fold<int>(0, (sum, t) => sum + t.amount);
  if (savedBefore >= goal.target) return null;
  final end = clock.isBefore(next) ? clock.add(const Duration(days: 1)) : next;
  final depositStart = day(planStart).isAfter(first) ? day(planStart) : first;
  final net = transfers
      .where(
        (t) =>
            t.goal == goal.id &&
            !t.date.isBefore(depositStart) &&
            t.date.isBefore(end),
      )
      .fold<int>(0, (sum, t) => sum + t.amount);
  final onTimeEnd = due.add(const Duration(days: 1));
  final onTime = transfers
      .where(
        (t) =>
            t.goal == goal.id &&
            !t.date.isBefore(depositStart) &&
            t.date.isBefore(onTimeEnd) &&
            t.date.isBefore(end),
      )
      .fold<int>(0, (sum, t) => sum + t.amount);
  final reachedTarget = savedBefore + net >= goal.target;
  final onTimeSatisfied =
      onTime >= required || savedBefore + onTime >= goal.target;
  final missing = reachedTarget ? 0 : math.max(0, required - net);
  return MonthlyGoalStatus(
    dueDate: due,
    required: required,
    netDeposited: net,
    onTimeDeposited: onTime,
    missing: missing,
    duePassed: clock.isAfter(due),
    late: clock.isAfter(due) && missing == 0 && !onTimeSatisfied,
    onTimeSatisfied: onTimeSatisfied,
  );
}
