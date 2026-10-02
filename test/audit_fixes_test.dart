import 'dart:convert';
import 'package:birikio/data/store.dart';
import 'package:birikio/data/annual_radar.dart';
import 'package:birikio/data/payment_reminders.dart';
import 'package:birikio/data/backup.dart';
import 'package:flutter_test/flutter_test.dart';

FinanceStore fresh() =>
    FinanceStore(read: () async => null, write: (_) async {});
RepeatRule monthly({bool income = true, bool manual = false}) => RepeatRule(
  id: 'r',
  title: 'Eski seri',
  amount: 10000,
  income: income,
  start: DateTime(2026, 1, 10),
  category: income ? 'Maaş' : 'Diğer',
  frequency: 3,
  isBill: manual,
  automaticPayment: !manual,
);

void main() {
  test(
    'radar uses actual payment year once and retains original due',
    () async {
      final s = fresh();
      final p = ScheduledExpense(
        id: 'p',
        title: 'Aralık planı',
        category: 'Diğer',
        amount: 10000,
        due: DateTime(2026, 12, 28),
      );
      s.scheduledExpenses.add(p);
      await s.markScheduledExpensePaid(
        p,
        paidAt: DateTime(2027, 1, 3),
        amount: 12000,
      );
      expect(annualRadarItems(s, 2026), isEmpty);
      final item = annualRadarItems(s, 2027).single;
      expect(item.due, DateTime(2027, 1, 3));
      expect(item.plannedDue, DateTime(2026, 12, 28));
      expect(item.paidAmount, 12000);
    },
  );
  test(
    'rule and legacy plan payments stay in payment month with historic labels',
    () async {
      final s = fresh();
      final r = monthly(income: false, manual: true);
      s.rules.add(r);
      await s.markBillPaid(r, 0, paidAt: DateTime(2026, 2, 4));
      r.title = 'Yeni seri';
      r.dueDayChanges[0] = 20;
      expect(
        annualRadarItems(s, 2026).where((p) => p.paid).single.plannedDue,
        DateTime(2026, 1, 10),
      );
      expect(
        annualRadarItems(s, 2026).where((p) => p.paid).single.title,
        'Eski seri',
      );
      expect(
        annualRadarItems(s, 2026).where((p) => p.paid).single.due.month,
        2,
      );
      final p = AnnualPlan(
        id: 'annual',
        title: 'Yıllık',
        category: 'Diğer',
        amount: 10000,
        month: 12,
        dueDay: 10,
        startYear: 2026,
      );
      s.annualPlans.add(p);
      await s.markAnnualPlanPaid(p, 2026, paidAt: DateTime(2027, 1, 2));
      expect(
        annualRadarItems(s, 2026).where((p) => p.title == 'Yıllık'),
        isEmpty,
      );
      expect(
        annualRadarItems(
          s,
          2027,
        ).where((p) => p.paid && p.title == 'Yıllık').length,
        1,
      );
    },
  );
  test(
    'deleted planned income does not return after backup and catch-up',
    () async {
      final s = fresh();
      s.scheduledExpenses.add(
        ScheduledExpense(
          id: 'i',
          title: 'Gelir',
          category: 'Maaş',
          amount: 10000,
          due: DateTime(2026, 1, 1),
          income: true,
        ),
      );
      s.materialize(DateTime(2026, 2, 1));
      s.removeEntry('scheduled:i');
      final reopened = fresh();
      await restoreBackup(reopened, createBackup(s));
      reopened.materialize(DateTime(2026, 3, 1));
      expect(reopened.entries, isEmpty);
      expect(reopened.scheduledExpenses, isEmpty);
    },
  );
  test('resume offers skipping paused periods or catching them up', () {
    for (final catchUp in [false, true]) {
      final s = fresh();
      final r = monthly();
      s.rules.add(r);
      s.materialize(DateTime(2026, 1, 11));
      r.active = false;
      s.resumeRule(r, catchUpMissed: catchUp, now: DateTime(2026, 3, 11));
      expect(s.entries.length, catchUp ? 3 : 1);
      expect(r.cursor, 3);
      s.materialize(DateTime(2026, 4, 11));
      expect(s.entries.length, catchUp ? 4 : 2);
    }
  });
  test(
    'new schedule preserves history and old overdue manual obligations',
    () async {
      final s = fresh();
      final r = monthly(income: false, manual: true);
      s.rules.add(r);
      await s.markBillPaid(r, 0, paidAt: DateTime(2026, 1, 10));
      final revised = s.replaceRuleSchedule(
        r,
        start: DateTime(2026, 3, 20),
        frequency: 2,
        automaticPayment: true,
        now: DateTime(2026, 3, 15),
      );
      revised.title = 'Yeni';
      revised.amount = 20000;
      expect(revised.id, isNot(r.id));
      expect(s.entries.single.amount, 10000);
      expect(s.scheduledExpenses.map((p) => p.due.month), [2, 3]);
      expect(s.scheduledExpenses.every((p) => p.amount == 10000), isTrue);
      s.materialize(DateTime(2026, 3, 28));
      expect(s.entries.where((p) => p.rule == revised.id).length, 2);
      expect(revised.occurrence(1), DateTime(2026, 3, 27));
      final restored = fresh();
      await restoreBackup(restored, createBackup(s));
      expect(restored.rules.single.frequency, 2);
      expect(restored.entries.length, 3);
    },
  );
  test(
    'reminders include automatic, annual and daily payments across a rolling year',
    () {
      final s = fresh();
      final now = DateTime(2026, 1, 1, 12);
      s.rules.add(
        RepeatRule(
          id: 'daily',
          title: 'Günlük ödeme',
          amount: 10000,
          income: false,
          start: DateTime(2026, 1, 2),
          category: 'Diğer',
          frequency: 1,
          isBill: true,
        ),
      );
      s.annualPlans.add(
        AnnualPlan(
          id: 'a',
          title: 'Yıllık masraf',
          category: 'Diğer',
          amount: 10000,
          month: 6,
          dueDay: 10,
          startYear: 2026,
        ),
      );
      s.scheduledExpenses.add(
        ScheduledExpense(
          id: 'near',
          title: 'Yakın ödeme',
          category: 'Diğer',
          amount: 10000,
          due: DateTime(2026, 1, 2),
        ),
      );
      final reminders = paymentReminders(s, now);
      final scheduled = reminders.where((r) => !r.immediate).toList();
      expect(scheduled.length, greaterThan(350));
      expect(scheduled.length, lessThanOrEqualTo(366));
      expect(scheduled.any((r) => r.body.contains('Yıllık masraf')), isTrue);
      expect(
        reminders.any((r) => r.immediate && r.body.contains('2 Ocak')),
        isTrue,
      );
      s.sentPaymentAlerts.addAll(
        reminders.where((r) => r.immediate).map((r) => r.key),
      );
      expect(paymentReminders(s, now).where((r) => r.immediate), isEmpty);
    },
  );
  test(
    'schema migration retains data and validates reminder history',
    () async {
      final s = fresh();
      s.rules.add(monthly());
      s.sentPaymentAlerts.add('payment:seen');
      final reopened = fresh();
      await restoreBackup(reopened, createBackup(s));
      expect(reopened.sentPaymentAlerts, {'payment:seen'});
      final old = jsonDecode(createBackup(s)) as Map<String, dynamic>;
      old['schemaVersion'] = 13;
      old['data']['schemaVersion'] = 13;
      old['data'].remove('sentPaymentAlerts');
      await restoreBackup(reopened, jsonEncode(old));
      expect(reopened.rules.single.id, 'r');
      expect(reopened.sentPaymentAlerts, isEmpty);
      old['schemaVersion'] = 14;
      old['data']['schemaVersion'] = 14;
      old['data']['sentPaymentAlerts'] = [42];
      expect(() => parseBackup(jsonEncode(old)), throwsFormatException);
    },
  );
  test('expired yearly reserve is zero and respects changed due day', () {
    final s = fresh();
    s.rules.add(
      RepeatRule(
        id: 'y',
        title: 'Bitti',
        amount: 120000,
        income: false,
        start: DateTime(2025, 1, 10),
        endDate: DateTime(2025, 1, 10),
        category: 'Diğer',
        frequency: 4,
      ),
    );
    expect(suggestedMonthlyAnnualReserve(s, DateTime(2026, 1, 1)), 0);
    expect(moneyInput(4500000), '45.000,00');
  });
  test(
    'reserve skips early payments and automatic series can become manual',
    () async {
      final s = fresh();
      final y = RepeatRule(
        id: 'y',
        title: 'Yıllık',
        amount: 120000,
        income: false,
        start: DateTime(2026, 2, 10),
        endDate: DateTime(2027, 2, 10),
        category: 'Diğer',
        frequency: 4,
        isBill: true,
        automaticPayment: false,
      );
      s.rules.add(y);
      await s.markBillPaid(y, 0, paidAt: DateTime(2026, 1, 1));
      await s.markBillPaid(y, 1, paidAt: DateTime(2026, 1, 1));
      expect(suggestedMonthlyAnnualReserve(s, DateTime(2026, 1, 1)), 0);
      final auto = monthly(income: false);
      s.rules.add(auto);
      final manual = s.replaceRuleSchedule(
        auto,
        start: DateTime(2026, 3, 20),
        frequency: 1,
        automaticPayment: false,
        now: DateTime(2026, 3, 15),
      );
      s.materialize(DateTime(2026, 3, 22));
      expect(manual.isBill, isTrue);
      expect(manual.automaticPayment, isFalse);
      expect(s.entries.where((e) => e.rule == manual.id), isEmpty);
      expect(
        annualRadarItems(
          s,
          2026,
        ).where((p) => p.id == manual.id && !p.paid).length,
        greaterThan(12),
      );
    },
  );
}
