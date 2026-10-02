import 'package:birikio/data/store.dart';
import 'package:birikio/ui/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> tapVisible(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
  expect(t.takeException(), isNull, reason: '$f');
}

void main() {
  testWidgets(
    'future category, pending amount sorting and future date filter use the same scope',
    (t) async {
      phone(t);
      final now = DateTime.now();
      final s = FinanceStore(read: () async => null, write: (_) async {})
        ..motion = false;
      s.scheduledExpenses.addAll([
        ScheduledExpense(
          id: 'low',
          title: 'Küçük ödeme',
          category: 'Diğer',
          amount: 10000,
          due: DateTime(now.year, now.month, 20),
        ),
        ScheduledExpense(
          id: 'high',
          title: 'Büyük ödeme',
          category: 'Diğer',
          amount: 40000,
          due: DateTime(now.year, now.month, 10),
        ),
        ScheduledExpense(
          id: 'future',
          title: 'Gelecek yıl sağlık',
          category: 'Sağlık',
          amount: 30000,
          due: DateTime(now.year + 1, 1, 15),
        ),
      ]);
      await t.pumpWidget(BirikioApp(store: s));
      await t.tap(find.text('Gelir & Gider').last);
      await t.pumpAndSettle();
      await tapVisible(t, find.text('Tüm kayıtları göster'));
      expect(find.textContaining('düzenli/yıllık vadeler:'), findsOneWidget);
      await tapVisible(t, find.text('Tüm kategoriler').first);
      await t.tap(find.text('Sağlık').last);
      await t.pumpAndSettle();
      expect(find.text('0 gerçekleşmiş · 1 bekleyen kayıt'), findsOneWidget);
      expect(find.text('Gelecek yıl sağlık'), findsOneWidget);
      await tapVisible(t, find.text('Sağlık').first);
      await t.tap(find.text('Tüm kategoriler').last);
      await t.pumpAndSettle();
      await tapVisible(t, find.byTooltip('Filtrele ve sırala'));
      await tapVisible(t, find.text('Tüm tarihler'));
      expect(
        t
            .widget<DateRangePickerDialog>(find.byType(DateRangePickerDialog))
            .lastDate
            .year,
        2100,
      );
      Navigator.of(t.element(find.byType(DateRangePickerDialog))).pop();
      await t.pumpAndSettle();
      await tapVisible(
        t,
        find.widgetWithText(DropdownButtonFormField<int>, 'Sıralama'),
      );
      await t.tap(find.text('Tutar: yüksekten düşüğe').last);
      await t.pumpAndSettle();
      await tapVisible(t, find.text('Uygula'));
      await t.ensureVisible(find.text('Büyük ödeme'));
      await t.pumpAndSettle();
      expect(
        t.getTopLeft(find.text('Büyük ödeme')).dy,
        lessThan(t.getTopLeft(find.text('Gelecek yıl sağlık')).dy),
      );
      expect(
        t.getTopLeft(find.text('Gelecek yıl sağlık')).dy,
        lessThan(t.getTopLeft(find.text('Küçük ödeme')).dy),
      );
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'radar shares schedule editor and deleting a rule closes its detail',
    (t) async {
      phone(t);
      final now = DateTime.now();
      final s = FinanceStore(read: () async => null, write: (_) async {})
        ..motion = false;
      final old = RepeatRule(
        id: 'r',
        title: 'Eski seri',
        amount: 10000,
        income: true,
        start: DateTime(now.year, now.month, 28),
        category: 'Maaş',
        frequency: 3,
      );
      s.rules.add(old);
      s.entries.add(
        Entry(
          id: 'history',
          title: 'Geçmiş',
          amount: 10000,
          income: true,
          date: DateTime(now.year, now.month - 1, 28),
          category: 'Maaş',
          rule: old.id,
        ),
      );
      await t.pumpWidget(BirikioApp(store: s));
      await t.tap(find.text('Gelir & Gider').last);
      await t.pumpAndSettle();
      await tapVisible(t, find.text('Yıllık radar'));
      await tapVisible(t, find.text('Düzenle'));
      await t.enterText(find.widgetWithText(TextFormField, 'Ad'), 'Yeni seri');
      await tapVisible(
        t,
        find.widgetWithText(DropdownButtonFormField<int>, 'Tekrarlama'),
      );
      await t.tap(find.text('Haftalık').last);
      await t.pumpAndSettle();
      await tapVisible(t, find.text('Kaydet'));
      expect(s.rules.single.frequency, 2);
      expect(s.rules.single.id, isNot(old.id));
      expect(s.entries.single.title, 'Geçmiş');
      await tapVisible(t, find.text('Kayıtlar'));
      await tapVisible(t, find.text('Yeni seri').first);
      expect(find.byType(BottomSheet), findsOneWidget);
      await t.tap(find.byTooltip('Seriyi sil').last);
      await t.pumpAndSettle();
      await t.tap(find.text('Sil').last);
      await t.pumpAndSettle();
      expect(s.rules, isEmpty);
      expect(s.entries.single.title, 'Geçmiş');
      expect(find.byType(BottomSheet), findsNothing);
      expect(t.takeException(), isNull);
    },
  );
}
