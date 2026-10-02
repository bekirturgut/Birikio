import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../data/store.dart';
import '../data/payment_reminders.dart';

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
        android: AndroidInitializationSettings('ic_notification'),
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
      if (Platform.isAndroid) {
        final android = plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        if (await android?.areNotificationsEnabled() != true) return;
      }
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
    final reminders = paymentReminders(store, DateTime.now());
    for (final pending in await plugin.pendingNotificationRequests()) {
      await plugin.cancel(id: pending.id);
    }
    final delivered = <String>{};
    final immediate = reminders.where((r) => r.immediate).toList();
    if (immediate.isNotEmpty) {
      await plugin.show(
        id: billNotificationId('immediate-payments'),
        title: immediate.length == 1
            ? immediate.first.title
            : '${immediate.length} ödeme dikkat bekliyor',
        body: immediate.take(4).map((r) => '${r.title}\n${r.body}').join('\n'),
        notificationDetails: details,
      );
      delivered.addAll(immediate.map((r) => r.key));
    }
    var scheduled = 0;
    // Group all payments on the same day. Android gets a rolling year;
    // iOS keeps the nearest 60 reminder dates, refreshed on app activity.
    final limit = Platform.isIOS ? 60 : 366;
    for (final reminder in reminders) {
      if (reminder.immediate) {
        continue;
      } else if (scheduled < limit) {
        await plugin.zonedSchedule(
          id: billNotificationId(reminder.key),
          title: reminder.title,
          body: reminder.body,
          scheduledDate: tz.TZDateTime.from(reminder.at, tz.local),
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
        scheduled++;
      }
    }
    if (delivered.isNotEmpty) {
      await store.change(() => store.sentPaymentAlerts.addAll(delivered));
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
