import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelir_gider/data/store.dart';
import 'package:gelir_gider/ui/app.dart';

void main() {
  testWidgets(
    'Back closes sheets, returns to home, and never pops the app root',
    (tester) async {
      final store = FinanceStore(read: () async => null, write: (_) async {})
        ..motion = false;
      await tester.pumpWidget(BirikioApp(store: store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Analiz').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Yeni kayıt ekle'));
      await tester.pumpAndSettle();
      expect(find.text('Bugün ne ekleyelim?'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Bugün ne ekleyelim?'), findsNothing);
      expect(find.text('DÖNEMİN ÖZETİ'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Genel bakış'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Genel bakış'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'System brightness changes update the app live; manual overrides remain possible',
    (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final store = FinanceStore(read: () async => null, write: (_) async {})
        ..motion = false;
      await tester.pumpWidget(BirikioApp(store: store));
      await tester.pumpAndSettle();
      Brightness brightness() =>
          Theme.of(tester.element(find.text('Genel bakış'))).brightness;
      expect(brightness(), Brightness.dark);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpAndSettle();
      expect(brightness(), Brightness.light);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expect(brightness(), Brightness.dark);
      await store.change(() {
        store.followSystem = false;
        store.dark = false;
      });
      await tester.pumpAndSettle();
      expect(brightness(), Brightness.light);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  test('Existing saved settings default to following the system', () async {
    final s = FinanceStore(read: () async => null, write: (_) async {});
    final legacy = s.json()..remove('followSystem');
    s.restore(legacy);
    expect(s.followSystem, true);
    s.followSystem = false;
    final saved = s.json();
    s.restore(saved);
    expect(s.followSystem, false);
  });
}
