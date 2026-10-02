import 'package:birikio/data/store.dart';
import 'package:birikio/ui/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('regular details shrink to content and scroll long notes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime.now();
    final store = FinanceStore(read: () async => null, write: (_) async {})
      ..motion = false;
    final rule = RepeatRule(
      id: 'r',
      title: 'Abim',
      amount: 300000,
      income: true,
      start: DateTime(now.year, now.month, 28),
      category: 'Diğer',
      frequency: 3,
    );
    store.rules.add(rule);
    await tester.pumpWidget(BirikioApp(store: store));
    await tester.tap(find.text('Gelir & Gider').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Abim'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abim'));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(BottomSheet)).height, lessThan(400));
    await tester.tap(find.text('Durdur'));
    await tester.pumpAndSettle();
    expect(find.text('Sürdür'), findsOneWidget);
    await tester.tap(find.text('Sürdür'));
    await tester.pumpAndSettle();
    await store.change(
      () => rule.note = List.filled(100, 'Uzun açıklama satırı.').join('\n'),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(BottomSheet)).height, lessThan(844));
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(SingleChildScrollView),
      ),
      findsOneWidget,
    );
    await tester.drag(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(SingleChildScrollView),
      ),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
