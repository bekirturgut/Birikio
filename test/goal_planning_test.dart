import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:birikio/data/store.dart';

void main() {
  test('goal plan computes required amount and projected completion', () {
    final now = DateTime(2026, 9, 28);
    final goal = Goal(
      id: 'g',
      title: 'Motor',
      icon: 'Motor',
      target: 100000,
      targetDate: DateTime(2026, 12, 28),
      monthlyContribution: 20000,
    );
    expect(requiredMonthlySaving(goal, 40000, now), 20000);
    expect(projectedGoalDate(goal, 40000, now), DateTime(2026, 12, 28));
    expect(requiredMonthlySaving(goal, 100000, now), isNull);
    expect(projectedGoalDate(goal, 100000, now), isNull);
    goal.targetDate = DateTime(2026, 9, 1);
    expect(requiredMonthlySaving(goal, 40000, now), isNull);
  });

  test('old goals remain without a plan and planned goals persist', () async {
    String? disk;
    final store = FinanceStore(
      read: () async => disk,
      write: (value) async => disk = value,
    );
    store.goals.add(Goal(id: 'old', title: 'Ev', icon: 'Ev', target: 50000));
    await store.change(
      () => store.goals.add(
        Goal(
          id: 'new',
          title: 'Motor',
          icon: 'Motor',
          target: 100000,
          targetDate: DateTime(2027, 3, 1),
          monthlyContribution: 10000,
        ),
      ),
    );
    final reopened = FinanceStore(read: () async => disk, write: (_) async {});
    await reopened.load();
    expect(reopened.goals.first.targetDate, isNull);
    expect(reopened.goals.last.targetDate, DateTime(2027, 3, 1));
    expect(reopened.goals.last.monthlyContribution, 10000);
    expect(jsonDecode(disk!)['schemaVersion'], greaterThanOrEqualTo(4));
  });
}
