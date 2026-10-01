import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../data/store.dart';

class LocalNotifications {
  LocalNotifications._();
  static final instance = LocalNotifications._();

  final plugin = FlutterLocalNotificationsPlugin();
  bool initialized = false;
  bool syncing = false;

  bool get supported => Platform.isAndroid || Platform.isIOS;

  Future<void> initialize() async {
    if (!supported || initialized) return;
    tz.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
    }
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    initialized = true;
  }

  Future<bool> requestPermission() async {
    if (!supported) return false;
    await initialize();
    if (Platform.isAndroid) {
      final android = plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (await android?.areNotificationsEnabled() == true) return true;
      await android?.requestNotificationsPermission();
      return await android?.areNotificationsEnabled() == true;
    }
    return await plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true) ??
        false;
  }

  Future<void> cancelAll() async {
    if (!supported) return;
    await initialize();
    await plugin.cancelAll();
  }

  Future<void> openSettings() async {
    if (!supported) return;
    await initialize();
    await plugin.openAppNotificationSettings();
  }

  Future<void> sync(FinanceStore store) async {
    if (!supported || !store.notificationsEnabled || syncing || store.busy) {
      return;
    }
    syncing = true;
    try {
      await initialize();
      await _scheduleBills(store);
      await _showBudgetThresholds(store);
    } finally {
      syncing = false;
    }
  }

  static const details = NotificationDetails(
    android: AndroidNotificationDetails(
      'birikio_finance',
      'Birikio hatırlatmaları',
      channelDescription: 'Bütçe ve ödeme hatırlatmaları',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  int billNotificationId(String id) =>
      100000 +
      id.codeUnits.fold<int>(
            0,
            (hash, code) => (hash * 31 + code) & 0x7fffffff,
          ) %
          1000000000;

  Future<void> _scheduleBills(FinanceStore store) async {
    for (final pending in await plugin.pendingNotificationRequests()) {
      await plugin.cancel(id: pending.id);
    }
    for (final plan in store.scheduledExpenses) {
      if (plan.paidAt != null || plan.income) continue;
      await _scheduleCountdown(plan.id, plan.title, plan.amount, plan.due);
    }
    for (final rule in store.rules.where(
      (r) => r.isBill && !r.automaticPayment,
    )) {
      if (!rule.active) continue;
      var period = store.firstUnpaidBillPeriod(rule);
      var scheduledPeriods = 0;
      // Schedule a rolling year so reminders keep working while the app is closed.
      final horizon = DateTime.now().add(const Duration(days: 365));
      while (scheduledPeriods < 12) {
        final due = rule.occurrence(period);
        if (due.isAfter(horizon) ||
            (rule.endDate != null && due.isAfter(day(rule.endDate!)))) {
          break;
        }
        if (!store.entries.any((e) => e.id == '${rule.id}:$period')) {
          await _scheduleCountdown(
            '${rule.id}:$period',
            rule.title,
            rule.amount,
            due,
          );
          if (!due.isBefore(day(DateTime.now()))) scheduledPeriods++;
        }
        period++;
      }
    }
  }

  Future<void> _scheduleCountdown(
    String id,
    String title,
    int amount,
    DateTime due,
  ) async {
    for (final daysLeft in [3, 2, 1]) {
      final reminder = DateTime(due.year, due.month, due.day - daysLeft, 9);
      if (!reminder.isAfter(DateTime.now())) continue;
      await plugin.zonedSchedule(
        id: billNotificationId('$id:$daysLeft'),
        title: '$title ödemesine $daysLeft gün kaldı',
        body: '${money(amount)} · Son gün ${dateLabel(due)}',
        scheduledDate: tz.TZDateTime.from(reminder, tz.local),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  Future<void> _showBudgetThresholds(FinanceStore store) async {
    final now = DateTime.now();
    final month = store.budgetKey(now);
    final budgets = <(String, String, int)>[
      if ((store.budgets[month] ?? 0) > 0)
        ('general', 'Genel bütçe', store.budgets[month]!),
      for (final item in (store.categoryBudgets[month] ?? {}).entries)
        if (item.value > 0) ('category:${item.key}', item.key, item.value),
    ];
    final newlySent = <String>{};
    for (final budget in budgets) {
      final spent = budget.$1 == 'general'
          ? store.entries
                .where(
                  (e) =>
                      !e.income &&
                      e.date.year == now.year &&
                      e.date.month == now.month,
                )
                .fold<int>(0, (sum, e) => sum + e.amount)
          : store.categorySpent(now, budget.$2);
      final crossed = [
        25,
        50,
        75,
      ].where((percent) => spent * 100 >= budget.$3 * percent).toList();
      if (crossed.isEmpty) continue;
      final percent = crossed.last;
      final key = '$month|${budget.$1}|$percent';
      if (store.sentBudgetAlerts.contains(key)) continue;
      await plugin.show(
        id: key.codeUnits.fold<int>(
          0,
          (hash, code) => (hash * 31 + code) & 0x7fffffff,
        ),
        title: '${budget.$2} limitinin %$percent kadarı kullanıldı',
        body: '${money(spent)} / ${money(budget.$3)}',
        notificationDetails: details,
      );
      newlySent.addAll(crossed.map((p) => '$month|${budget.$1}|$p'));
    }
    if (newlySent.isNotEmpty) {
      await store.change(() => store.sentBudgetAlerts.addAll(newlySent));
    }
  }
}
