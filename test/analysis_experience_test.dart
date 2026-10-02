import 'package:birikio/data/store.dart';
import 'package:birikio/ui/app.dart';
import 'package:birikio/ui/orbit_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('insight card fits a narrow phone with long category names', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = FinanceStore(read: () async => null, write: (_) async {})
      ..motion = false;
    store.entries.add(
      Entry(
        id: 'expense',
        title: 'Alışveriş',
        amount: 8000000,
        income: false,
        date: DateTime.now(),
        category: 'Uzun kategorili alışveriş harcamaları',
      ),
    );
    await tester.pumpWidget(BirikioApp(store: store));
    await tester.tap(find.text('Analiz').last);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -430));
    await tester.pumpAndSettle();
    expect(find.text('Bu dönemin izleri'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wallet shows the funded goal share chart', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = FinanceStore(read: () async => null, write: (_) async {})
      ..motion = false;
    store.goals.addAll([
      Goal(id: 'home', title: 'Ev', icon: 'Ev', target: 1000000),
      Goal(id: 'bike', title: 'Motor', icon: 'Motor', target: 500000),
    ]);
    store.transfers.addAll([
      Transfer(id: 'a', goal: 'home', amount: 100000, date: DateTime.now()),
      Transfer(id: 'b', goal: 'bike', amount: 50000, date: DateTime.now()),
    ]);
    await tester.pumpWidget(BirikioApp(store: store));
    await tester.tap(find.text('Cüzdan').last);
    await tester.pumpAndSettle();
    expect(find.text('BİRİKİM DAĞILIMI'), findsOneWidget);
    expect(find.byType(OrbitChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('analysis opens the money flow and its transaction detail', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime.now();
    final store = FinanceStore(read: () async => null, write: (_) async {})
      ..motion = false;
    store.entries.addAll([
      Entry(
        id: 'income',
        title: 'Maaş',
        amount: 150000,
        income: true,
        date: now,
        category: 'Maaş',
      ),
      Entry(
        id: 'expense',
        title: 'Market alışverişi',
        amount: 30000,
        income: false,
        date: now,
        category: 'Market',
      ),
    ]);
    await tester.pumpWidget(BirikioApp(store: store));
    await tester.tap(find.text('Analiz').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Para akışı'));
    await tester.pumpAndSettle();
    expect(find.text('PARANIN YOLCULUĞU'), findsOneWidget);
    expect(find.byType(OrbitChart), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -260));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Market').first);
    await tester.pumpAndSettle();
    expect(find.text('Market alışverişi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'radar keeps legacy annual plans editable without duplicate creation buttons',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final now = DateTime.now();
      final store = FinanceStore(read: () async => null, write: (_) async {})
        ..motion = false;
      store.annualPlans.add(
        AnnualPlan(
          id: 'legacy',
          title: 'Araç sigortası',
          category: 'Ulaşım',
          amount: 120000,
          month: now.month,
          dueDay: 28,
          startYear: now.year,
        ),
      );
      await tester.pumpWidget(BirikioApp(store: store));
      await tester.tap(find.text('Analiz').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yıllık radar'));
      await tester.pumpAndSettle();
      expect(find.text('Planla'), findsNothing);
      expect(find.text('Gider ekle'), findsNothing);
      await tester.ensureVisible(find.byTooltip('Plan seçenekleri'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Plan seçenekleri'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Düzenle'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Tahmini tutar'),
        '1500',
      );
      await tester.ensureVisible(find.text('Planı kaydet'));
      await tester.tap(find.text('Planı kaydet'));
      await tester.pumpAndSettle();
      expect(store.annualPlans.single.amount, 150000);
      expect(store.balance, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
