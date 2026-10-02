import 'annual_radar.dart';
import 'store.dart';

class PaymentReminder {
  final String key, title, body;
  final DateTime at;
  final bool immediate;
  const PaymentReminder({
    required this.key,
    required this.title,
    required this.body,
    required this.at,
    this.immediate = false,
  });
}

List<PaymentReminder> paymentReminders(FinanceStore store, DateTime now) {
  final today = day(now);
  final horizon = today.add(const Duration(days: 365));
  final dates = <DateTime, List<String>>{};
  final result = <PaymentReminder>[];
  final years = <int>{
    for (
      var year = today.year;
      year <= horizon.add(const Duration(days: 3)).year;
      year++
    )
      year,
    ...store.scheduledExpenses
        .where((p) => !p.income && p.paidAt == null && p.due.isBefore(today))
        .map((p) => p.due.year),
    ...store.rules
        .where((r) => r.active && r.isBill && !r.automaticPayment)
        .map((r) => r.occurrence(store.firstUnpaidBillPeriod(r)).year),
  };
  for (final plan in store.annualPlans) {
    var year = plan.startYear;
    final paidIds = store.entries.map((e) => e.id).toSet();
    while (paidIds.contains('annual:${plan.id}:$year')) {
      year++;
    }
    if (plan.dueIn(year).isBefore(today)) years.add(year);
  }
  for (final year in years) {
    for (final p in annualRadarItems(
      store,
      year,
    ).where((p) => !p.paid && !p.income)) {
      if (p.due.isAfter(horizon.add(const Duration(days: 3)))) continue;
      final left = day(p.due).difference(today).inDays;
      final immediateKey =
          'payment:${p.id}:${p.period}:${p.due.toIso8601String()}';
      if (left <= 3 && !store.sentPaymentAlerts.contains(immediateKey)) {
        result.add(
          PaymentReminder(
            key: immediateKey,
            title: left < 0
                ? '${p.title} ödemesi gecikti'
                : left == 0
                ? '${p.title} ödemesi bugün'
                : '${p.title} ödemesine $left gün kaldı',
            body: '${money(p.amount)} · Vade ${dateLabel(p.due)}',
            at: now,
            immediate: true,
          ),
        );
      }
      for (final daysLeft in [3, 2, 1]) {
        final at = DateTime(p.due.year, p.due.month, p.due.day - daysLeft, 9);
        if (!at.isAfter(now) || day(at).isAfter(horizon)) continue;
        dates
            .putIfAbsent(at, () => [])
            .add('${p.title}: ${money(p.amount)} · $daysLeft gün');
      }
    }
  }
  for (final entry in dates.entries) {
    final lines = entry.value;
    result.add(
      PaymentReminder(
        key: 'countdown:${entry.key.toIso8601String()}',
        title: lines.length == 1
            ? 'Yaklaşan ödeme'
            : '${lines.length} yaklaşan ödeme',
        body:
            '${lines.take(4).join('\n')}${lines.length > 4 ? '\n+${lines.length - 4} ödeme daha' : ''}',
        at: entry.key,
      ),
    );
  }
  result.sort((a, b) => a.at.compareTo(b.at));
  return result;
}
