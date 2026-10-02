import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:birikio/data/store.dart';
import 'package:birikio/ui/app.dart';

void main() {
  testWidgets('profile is rightmost tab and opens settings', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = FinanceStore(read: () async => null, write: (_) async {});
    await tester.pumpWidget(BirikioApp(store: store));
    await tester.tap(find.text('Profil').last);
    await tester.pumpAndSettle();
    expect(find.text('Senin alanın'), findsOneWidget);
    expect(find.text('Kategoriler'), findsOneWidget);
    await tester.ensureVisible(find.widgetWithText(ListTile, 'Ayarlar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Ayarlar'));
    await tester.pumpAndSettle();
    expect(find.text('Görsel animasyonlar'), findsOneWidget);
  });
}
