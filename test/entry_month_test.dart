import 'package:birikio/data/store.dart';
import 'package:birikio/ui/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('entry page shows one month and navigates to the next', (
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
        id: 'current',
        title: 'Bu ay geliri',
        amount: 10000,
        income: true,
        date: DateTime(now.year, now.month, 1),
        category: 'Maaş',
      ),
      Entry(
        id: 'next',
        title: 'Gelecek ay geliri',
        amount: 20000,
        income: true,
        date: DateTime(now.year, now.month + 1, 1),
        category: 'Maaş',
      ),
    ]);
    await tester.pumpWidget(BirikioApp(store: store));
    await tester.tap(find.text('Gelir & Gider').last);
    await tester.pumpAndSettle();
    expect(find.text('Bu ay geliri'), findsOneWidget);
    expect(find.text('Gelecek ay geliri'), findsNothing);
    await tester.tap(find.byTooltip('Sonraki ay'));
    await tester.pumpAndSettle();
    expect(find.text('Bu ay geliri'), findsNothing);
    expect(find.text('Gelecek ay geliri'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
