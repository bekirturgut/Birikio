import 'package:birikio/data/store.dart';
import 'package:birikio/ui/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'grouped pages and contextual help remain usable on a narrow phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = FinanceStore(read: () async => null, write: (_) async {})
        ..motion = false;
      await tester.pumpWidget(BirikioApp(store: store));
      await tester.tap(find.text('Gelir & Gider').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Düzenli'));
      await tester.pumpAndSettle();
      expect(find.text('Henüz düzenli kayıt yok'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Yıllık radar').first);
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
        tester.element(find.byTooltip('Yıllık radar hakkında')),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Yıllık radar hakkında'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('kullanılabilir bakiye değildir'),
        findsOneWidget,
      );
      await tester.tap(find.text('Anladım'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cüzdan').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bütçe').first);
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
        tester.element(find.byTooltip('Bütçe hesabı hakkında')),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Bütçe hesabı hakkında'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Bütçeler bakiyeni değiştirmez'),
        findsOneWidget,
      );
      await tester.tap(find.text('Anladım'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Profil').last);
      await tester.pumpAndSettle();
      final settings = find.widgetWithText(ListTile, 'Ayarlar');
      await Scrollable.ensureVisible(tester.element(settings), alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(settings);
      await tester.pumpAndSettle();
      final data = find.widgetWithText(ListTile, 'Yedek ve dışa aktarma');
      await Scrollable.ensureVisible(tester.element(data), alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(data);
      await tester.pumpAndSettle();
      expect(find.text('Verilerim ve gizlilik'), findsOneWidget);
      expect(find.byTooltip('Pencereyi kapat'), findsNothing);
      await tester.tap(find.byTooltip('Yeni kayıt ekle'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Birikim hedefi ekle'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.drag(
        find.byType(SingleChildScrollView).last,
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Pencereyi kapat').hitTestable(), findsOneWidget);
      await tester.tap(find.byTooltip('Pencereyi kapat'));
      await tester.pumpAndSettle();
      expect(store.goals, isEmpty);
      expect(store.entries, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
