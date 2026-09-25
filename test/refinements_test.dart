import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelir_gider/data/store.dart';
import 'package:gelir_gider/ui/app.dart';
import 'package:gelir_gider/ui/forms.dart';
import 'package:gelir_gider/ui/widgets.dart';

void main() {
  testWidgets('Expense name is optional but amount remains necessary', (
    tester,
  ) async {
    final store = FinanceStore(read: () async => null, write: (_) async {});
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: EntryForm(store: store, income: false)),
      ),
    );
    await tester.ensureVisible(find.text('Kaydet'));
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(store.entries, isEmpty);
    expect(find.text('Geçerli bir tutar gir (ör. 1.250,50).'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Tutar'), '250');
    await tester.ensureVisible(find.text('Kaydet'));
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(store.entries.single.title, 'Gider');
    expect(store.entries.single.amount, 25000);
  });
  testWidgets(
    'Animated transitions render intermediate frames and settle correctly',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = FinanceStore(read: () async => null, write: (_) async {});
      await tester.pumpWidget(BirikioApp(store: store));
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.byType(RacingMotor), findsOneWidget);
      for (final label in ['Gelir', 'Birikim', 'Analiz', 'Anasayfa']) {
        await tester.tap(find.text(label).last);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 180));
        expect(find.byType(ImageFiltered), findsWidgets);
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(milliseconds: 600));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
