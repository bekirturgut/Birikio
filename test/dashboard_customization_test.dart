import 'dart:convert';

import 'package:birikio/data/store.dart';
import 'package:birikio/ui/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'dashboard choices survive reload and legacy data gets new defaults',
    () async {
      String? disk;
      final store = FinanceStore(
        read: () async => disk,
        write: (value) async => disk = value,
      );
      expect(store.dashboardSections, FinanceStore.defaultDashboardSections);
      await store.change(
        () => store.dashboardSections = ['summary', 'goal', 'cashflow'],
      );
      final next = FinanceStore(read: () async => disk, write: (_) async {});
      await next.load();
      expect(next.dashboardSections, ['summary', 'goal', 'cashflow']);
      final old = jsonDecode(disk!) as Map<String, dynamic>
        ..remove('dashboardSections');
      next.restore(old);
      expect(next.dashboardSections, FinanceStore.defaultDashboardSections);
    },
  );

  testWidgets(
    'dashboard hides duplicate cards by default and editor can add one',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = FinanceStore(read: () async => null, write: (_) async {});
      await tester.pumpWidget(BirikioApp(store: store));
      await tester.pumpAndSettle();
      expect(find.text('KULLANILABİLİR BAKİYE'), findsOneWidget);
      expect(find.text('GELİR'), findsOneWidget);
      await tester.tap(find.byTooltip('Ana ekranı düzenle'));
      await tester.pumpAndSettle();
      expect(find.text('Ayrı gelir / gider kartları'), findsOneWidget);
      await tester.ensureVisible(find.text('Ayrı gelir / gider kartları'));
      final row = find
          .ancestor(
            of: find.text('Ayrı gelir / gider kartları'),
            matching: find.byType(Row),
          )
          .first;
      await tester.tap(find.descendant(of: row, matching: find.byType(Switch)));
      await tester.pumpAndSettle();
      expect(store.dashboardSections, contains('cashflow'));
      await tester.tap(find.byTooltip('Ayrı gelir / gider kartları yukarı'));
      await tester.pumpAndSettle();
      expect(store.dashboardSections.last, isNot('cashflow'));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('financial score opens a readable factor breakdown', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = FinanceStore(read: () async => null, write: (_) async {});
    store.entries.add(
      Entry(
        id: 'income',
        title: 'Maaş',
        amount: 100000,
        income: true,
        date: DateTime.now(),
        category: 'Maaş',
      ),
    );
    store.entries.add(
      Entry(
        id: 'expense',
        title: 'Market',
        amount: 20000,
        income: false,
        date: DateTime.now(),
        category: 'Market',
      ),
    );
    await tester.pumpWidget(BirikioApp(store: store));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Puanı ve yorumları incele'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Puanı ve yorumları incele'));
    await tester.pumpAndSettle();
    expect(find.text('Paranın genel resmi'), findsOneWidget);
    expect(find.text('Gelir–gider dengesi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
