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
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('Senin alanın'), findsOneWidget);
    expect(find.text('Yalnızca bu cihazda'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Ayarlar'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.widgetWithText(ListTile, 'Ayarlar'));
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('Görsel animasyonlar'), findsOneWidget);
  });
}
