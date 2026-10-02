// Development emulator only. Does not use synthetic data in the real data key.
// flutter run -d emulator-5554 -t tools/notification_smoke.dart --no-resident
//   --dart-define=BIRIKIO_EMULATOR_SMOKE=true
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:birikio/data/store.dart';
import 'package:birikio/services/local_notifications.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!Platform.isAndroid ||
      !const bool.fromEnvironment('BIRIKIO_EMULATOR_SMOKE')) {
    throw StateError('Run explicitly on a development Android emulator.');
  }
  final notifications = LocalNotifications.instance;
  final preserved = FinanceStore();
  await preserved.load();
  final s = FinanceStore(read: () async => null, write: (_) async {})
    ..notificationsEnabled = true;
  final now = DateTime.now();
  final future = DateTime(now.year, now.month + 2, 20);
  s.scheduledExpenses.add(
    ScheduledExpense(
      id: 'smoke-near',
      title: 'Smoke yakın ödeme',
      category: 'Diğer',
      amount: 10000,
      due: day(now).add(const Duration(days: 1)),
    ),
  );
  s.rules.addAll([
    RepeatRule(
      id: 'smoke-daily',
      title: 'Smoke günlük',
      amount: 10000,
      income: false,
      start: day(now).add(const Duration(days: 4)),
      category: 'Diğer',
      frequency: 1,
      isBill: true,
    ),
    RepeatRule(
      id: 'smoke-manual',
      title: 'Smoke manuel',
      amount: 10000,
      income: false,
      start: future,
      category: 'Diğer',
      frequency: 3,
      isBill: true,
      automaticPayment: false,
    ),
  ]);
  s.annualPlans.add(
    AnnualPlan(
      id: 'smoke-annual',
      title: 'Smoke yıllık',
      category: 'Diğer',
      amount: 10000,
      month: future.month,
      dueDay: future.day,
      startYear: future.year,
    ),
  );
  try {
    if (!await notifications.requestPermission()) {
      throw StateError('Emulator notification permission missing.');
    }
    await notifications.sync(s);
    final pending = await notifications.plugin.pendingNotificationRequests();
    final active = await notifications.plugin.getActiveNotifications();
    if (pending.length < 350 ||
        !pending.any((p) => p.body?.contains('Smoke manuel') == true) ||
        !pending.any((p) => p.body?.contains('Smoke yıllık') == true)) {
      throw StateError('Incomplete schedule: ${pending.length}');
    }
    if (!active.any((p) => p.body?.contains('Smoke yakın') == true)) {
      throw StateError('Immediate native notification missing.');
    }
    debugPrint(
      'BIRIKIO_NOTIFICATION_SMOKE_PASS pending=${pending.length} immediate=true',
    );
    runApp(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('Bildirim testi geçti'))),
      ),
    );
  } catch (error) {
    debugPrint('BIRIKIO_NOTIFICATION_SMOKE_FAIL $error');
    rethrow;
  } finally {
    await notifications.cancelAll();
    await notifications.sync(preserved);
    debugPrint('BIRIKIO_NOTIFICATION_SMOKE_CLEANUP');
  }
}
