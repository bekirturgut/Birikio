import 'package:birikio/data/store.dart';
import 'package:birikio/ui/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final income in [true, false]) {
    testWidgets(
      'edit future regular ${income ? 'income' : 'expense'} without changing history',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final now = DateTime.now();
        String? disk;
        final store = FinanceStore(
          read: () async => disk,
          write: (value) async => disk = value,
        )..motion = false;
        final rule = RepeatRule(
          id: 'r',
          title: 'Eski başlık',
          amount: 300000,
          income: income,
          start: DateTime(now.year, now.month - 1, 28),
          category: income ? 'Maaş' : 'Alışveriş',
          frequency: 3,
          cursor: 1,
        );
        store.rules.add(rule);
        store.entries.add(
          Entry(
            id: 'r:0',
            title: 'Geçmiş başlık',
            amount: 300000,
            income: income,
            date: rule.start,
            category: rule.category,
            rule: rule.id,
          ),
        );
        await tester.pumpWidget(BirikioApp(store: store));
        await tester.tap(find.text('Gelir & Gider').last);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byTooltip('Düzenli kaydı düzenle'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Düzenli kaydı düzenle'));
        await tester.pumpAndSettle();
        expect(
          find.text(
            income ? 'Düzenli geliri düzenle' : 'Düzenli ödemeyi düzenle',
          ),
          findsOneWidget,
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Ad'),
          'Yeni başlık',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Tutar'),
          '4500',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Not (isteğe bağlı)'),
          'Yeni not',
        );
        final nextCategory = income ? 'Yatırım' : 'Sağlık';
        await tester.ensureVisible(
          find.widgetWithText(DropdownButtonFormField<String>, 'Kategori'),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(DropdownButtonFormField<String>, 'Kategori'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(nextCategory).last);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Vade günü (1–31)'),
          '27',
        );
        await tester.ensureVisible(find.text('Kaydet'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Kaydet'));
        await tester.pumpAndSettle();
        expect(rule.title, 'Yeni başlık');
        expect(rule.amount, 450000);
        expect(rule.note, 'Yeni not');
        expect(rule.category, nextCategory);
        expect(rule.occurrence(1).day, 27);
        expect(rule.occurrence(0).day, 28);
        expect(store.entries.single.title, 'Geçmiş başlık');
        expect(store.entries.single.amount, 300000);
        final restored = FinanceStore(
          read: () async => disk,
          write: (_) async {},
        );
        await restored.load();
        expect(restored.rules.single.amount, 450000);
        expect(restored.entries.single.amount, 300000);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
