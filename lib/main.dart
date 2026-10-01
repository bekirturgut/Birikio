import 'package:flutter/material.dart';
import 'dart:io';
import 'package:workmanager/workmanager.dart';
import 'data/store.dart';
import 'ui/app.dart';
import 'services/local_notifications.dart';

const backgroundTask = 'birikio_daily_finance';

@pragma('vm:entry-point')
void backgroundDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final store = FinanceStore();
      await store.load();
      if (store.notificationsEnabled) {
        await LocalNotifications.instance.sync(store);
      }
      return true;
    } catch (_) {
      return false;
    }
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid) {
    await Workmanager().initialize(backgroundDispatcher);
    await Workmanager().registerPeriodicTask(
      backgroundTask,
      backgroundTask,
      frequency: const Duration(hours: 6),
    );
  }
  runApp(BirikioApp(store: FinanceStore(), initialize: true));
}
