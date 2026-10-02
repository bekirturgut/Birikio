import 'package:birikio/data/store.dart';
import 'package:birikio/ui/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'five record preview opens a live separate list with the same month and type',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final now = DateTime.now();
      final store = FinanceStore(read: () async => null, write: (_) async {})
        ..motion = false;
      store.entries.addAll([
        for (var i = 0; i < 9; i++)
          Entry(
            id: '$i',
            title: 'Kayıt $i',
            amount: 10000,
            income: true,
            date: DateTime(now.year, now.month, 1, i),
            category: 'Maaş',
          ),
        Entry(
          id: 'expense',
          title: 'Gider dışarıda',
          amount: 100,
          income: false,
          date: now,
          category: 'Diğer',
        ),
        Entry(
          id: 'old',
          title: 'Önceki ay dışarıda',
          amount: 100,
          income: true,
          date: DateTime(now.year, now.month - 1, 1),
          category: 'Maaş',
        ),
      ]);
      await tester.pumpWidget(BirikioApp(store: store));
      await tester.tap(find.text('Gelir & Gider').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gelirler'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Kayıt '), findsNWidgets(5));
      expect(find.text('Kayıt 0'), findsNothing);
      final more = find.text('Tümünü gör (9)');
      await Scrollable.ensureVisible(tester.element(more), alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('9 kayıt'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Kayıt 0'),
        180,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Kayıt 0'), findsOneWidget);
      expect(find.text('Gider dışarıda'), findsNothing);
      expect(find.text('Önceki ay dışarıda'), findsNothing);
      await store.change(() => store.entries.removeWhere((e) => e.id == '0'));
      await tester.pumpAndSettle();
      expect(find.text('8 kayıt'), findsOneWidget);
      expect(find.text('Kayıt 0'), findsNothing);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(AppBar), findsNothing);
      expect(find.textContaining('Kayıt '), findsNWidgets(5));
      expect(tester.takeException(), isNull);
    },
  );
}
