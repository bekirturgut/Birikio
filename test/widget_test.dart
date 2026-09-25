import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelir_gider/data/store.dart';
import 'package:gelir_gider/ui/app.dart';

void main() {
  testWidgets(
    'Mobile navigation, income form, persistence and analysis preview',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? disk;
      final store =
          FinanceStore(
              read: () async => disk,
              write: (value) async => disk = value,
            )
            ..followSystem = false
            ..motion = false;
      await tester.pumpWidget(BirikioApp(store: store));
      await tester.pumpAndSettle();
      expect(find.text('Genel bakış'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Yeni kayıt ekle'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gelir ekle'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Tutar'),
        '15000,50',
      );
      await tester.ensureVisible(find.text('Kaydet'));
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      expect(store.entries.single.amount, 1500050);
      expect(store.entries.single.title, 'Gelir');
      expect(disk, isNotNull);
      for (final label in ['Gelir', 'Gider', 'Birikim', 'Bütçe', 'Analiz']) {
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: label);
      }
      await tester.tap(
        find.text('${months[DateTime.now().month - 1]} ${DateTime.now().year}'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ay seç'), findsOneWidget);
      expect(find.textContaining('15.000,50'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('Goal card fits small phone and light theme', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = FinanceStore(read: () async => null, write: (_) async {})
      ..followSystem = false
      ..motion = false
      ..dark = false;
    store.goals.add(
      Goal(
        id: 'g',
        title: 'Hayalimdeki motor',
        icon: 'Motor',
        target: 25000000,
      ),
    );
    await tester.pumpWidget(BirikioApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('Hayalimdeki motor'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
