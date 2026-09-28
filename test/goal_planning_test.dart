import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:birikio/data/store.dart';
import 'package:birikio/data/goal_plan.dart';

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

  test(
    'monthly deadline handles short months, late funding and pre-plan transfers',
    () {
      final goal = Goal(
        id: 'g',
        title: 'Ev',
        icon: 'Ev',
        target: 1000000,
        monthlyContribution: 10000,
        monthlyDueDay: 31,
        monthlyPlanStart: DateTime(2026, 2, 10),
      );
      final transfers = <Transfer>[
        Transfer(
          id: 'before',
          goal: 'g',
          amount: 4000,
          date: DateTime(2026, 2, 1),
        ),
        Transfer(
          id: 'on-time',
          goal: 'g',
          amount: 3000,
          date: DateTime(2026, 2, 20),
        ),
      ];
      final status = monthlyGoalStatus(
        goal,
        transfers,
        DateTime(2026, 2),
        now: DateTime(2026, 3, 1),
      )!;
      expect(status.dueDate, DateTime(2026, 2, 28));
      expect(status.netDeposited, 3000);
      expect(status.missing, 7000);
      transfers.add(
        Transfer(
          id: 'late',
          goal: 'g',
          amount: 7000,
          date: DateTime(2026, 3, 1),
        ),
      );
      expect(
        monthlyGoalStatus(
          goal,
          transfers,
          DateTime(2026, 2),
          now: DateTime(2026, 3, 1),
        )!.missing,
        7000,
      );
      goal.monthlyDueDay = 10;
      goal.monthlyPlanStart = DateTime(2026, 2, 20);
      expect(
        monthlyGoalStatus(
          goal,
          transfers,
          DateTime(2026, 2),
          now: DateTime(2026, 2, 28),
        ),
        isNull,
      );
      expect(
        monthlyGoalStatus(
          goal,
          transfers,
          DateTime(2026, 3),
          now: DateTime(2026, 3, 11),
        )!.duePassed,
        isTrue,
      );
    },
  );

  test(
    'monthly plan persists and old projection-only goals are not overdue',
    () async {
      String? disk;
      final store = FinanceStore(
        read: () async => disk,
        write: (value) async => disk = value,
      );
      await store.change(() {
        store.goals.add(
          Goal(
            id: 'new',
            title: 'Birikim',
            icon: 'Birikim',
            target: 100000,
            monthlyContribution: 10000,
            monthlyDueDay: 15,
            monthlyPlanStart: DateTime(2026, 9, 1),
          ),
        );
      });
      final loaded = FinanceStore(read: () async => disk, write: (_) async {});
      await loaded.load();
      expect(loaded.goals.single.monthlyDueDay, 15);
      expect(
        monthlyGoalStatus(
          loaded.goals.single,
          loaded.transfers,
          DateTime(2026, 9),
          now: DateTime(2026, 9, 16),
        )!.missing,
        10000,
      );
      loaded.goals.single.monthlyDueDay = null;
      expect(
        monthlyGoalStatus(
          loaded.goals.single,
          loaded.transfers,
          DateTime(2026, 9),
          now: DateTime(2026, 9, 16),
        ),
        isNull,
      );
    },
  );
}
