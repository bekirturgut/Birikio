import 'package:birikio/data/store.dart';
import 'package:birikio/data/annual_radar.dart';
import 'package:birikio/ui/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('monthly records include future recurring income and expense', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime.now();
    final store = FinanceStore(read: () async => null, write: (_) async {})
      ..motion = false;
    for (final income in [true, false]) {
      store.rules.add(
        RepeatRule(
          id: '$income',
          title: income ? 'Düzenli maaş' : 'Düzenli kira',
          amount: 10000,
          income: income,
          start: DateTime(now.year, now.month, 28),
          category: income ? 'Maaş' : 'Kira',
          frequency: 3,
        ),
      );
    }
    await tester.pumpWidget(BirikioApp(store: store));
    await tester.tap(find.text('Gelir & Gider').last);
    await tester.pumpAndSettle();
    expect(find.text('0 gerçekleşmiş · 2 bekleyen kayıt'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('monthly-summary'))).height,
      lessThan(220),
    );
    expect(find.byType(Chip), findsNothing);
    expect(find.text('Bekleyen'), findsNWidgets(2));
    await tester.ensureVisible(find.text('Düzenli maaş'));
    expect(find.text('Düzenli maaş'), findsOneWidget);
    expect(find.text('Düzenli kira'), findsOneWidget);
    expect(find.textContaining('Yaklaşan'), findsNWidgets(2));
    expect(store.balance, 0);
    await tester.ensureVisible(find.text('Gelirler'));
    await tester.tap(find.text('Gelirler'));
    await tester.pumpAndSettle();
    expect(find.text('0 gerçekleşmiş · 1 bekleyen kayıt'), findsOneWidget);
    expect(find.text('Düzenli kira'), findsNothing);
    // The period summary remains independent of the income-only list filter.
    expect(find.text('100,00 ₺'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  test(
    'projection respects paid periods, cursor, end date and inactive series',
    () {
      final store = FinanceStore(read: () async => null, write: (_) async {});
      final rule = RepeatRule(
        id: 'r',
        title: 'Maaş',
        amount: 10000,
        income: true,
        start: DateTime(2026, 1, 15),
        category: 'Maaş',
        frequency: 3,
        endDate: DateTime(2026, 3, 15),
      );
      store.rules.add(rule);
      store.materialize(DateTime(2026, 2, 16));
      var items = annualRadarItems(store, 2026);
      expect(items.length, 3);
      expect(items.where((p) => p.paid).length, 2);
      expect(items.where((p) => !p.paid).single.due, DateTime(2026, 3, 15));
      store.entries.removeAt(0);
      expect(annualRadarItems(store, 2026).length, 2);
      rule.active = false;
      expect(annualRadarItems(store, 2026).single.paid, isTrue);
    },
  );
}
