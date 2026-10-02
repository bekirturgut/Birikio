import 'package:birikio/data/annual_radar.dart';
import 'package:birikio/data/store.dart';
import 'package:birikio/ui/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(350, 820);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

FinanceStore memoryStore() =>
    FinanceStore(read: () async => null, write: (_) async {})..motion = false;

void main() {
  testWidgets(
    'older records remain reachable when the selected month is empty',
    (tester) async {
      phone(tester);
      final now = DateTime.now();
      final store = memoryStore();
      store.entries.add(
        Entry(
          id: 'old',
          title: 'Önceki ay maaşı',
          amount: 100000,
          income: true,
          date: DateTime(now.year, now.month - 1, 15),
          category: 'Maaş',
        ),
      );
      await tester.pumpWidget(BirikioApp(store: store));
      await tester.tap(find.text('Gelir & Gider').last);
      await tester.pumpAndSettle();
      expect(find.text('Bu ay kayıt yok'), findsOneWidget);
      expect(find.text('Henüz kayıt yok'), findsNothing);
      await tester.tap(find.text('Tüm kayıtları göster'));
      await tester.pumpAndSettle();
      expect(find.text('Önceki ay maaşı'), findsOneWidget);
      expect(store.balance, 100000);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'adding a record clears a stale search and opens the saved month',
    (tester) async {
      phone(tester);
      final store = memoryStore();
      await tester.pumpWidget(BirikioApp(store: store));
      await tester.tap(find.text('Gelir & Gider').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Önceki ay'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'bulunmayan');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Yeni kayıt ekle'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gelir ekle'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Tutar'),
        '1200',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Gelir kaynağı'),
        'Yeni ödeme',
      );
      await tester.ensureVisible(find.text('Kaydet'));
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      expect(find.text('Yeni ödeme'), findsOneWidget);
      expect(find.text('Bu ay kayıt yok'), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(store.balance, 120000);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pending income and expense are visible and editable from records',
    (tester) async {
      phone(tester);
      final now = DateTime.now();
      final store = memoryStore();
      store.scheduledExpenses.addAll([
        ScheduledExpense(
          id: 'i',
          title: 'Beklenen burs',
          category: 'Diğer',
          amount: 200000,
          due: DateTime(now.year, now.month, 28),
          income: true,
        ),
        ScheduledExpense(
          id: 'e',
          title: 'Bekleyen kira',
          category: 'Ev & faturalar',
          amount: 100000,
          due: DateTime(now.year, now.month, 28),
        ),
      ]);
      await tester.pumpWidget(BirikioApp(store: store));
      await tester.tap(find.text('Gelir & Gider').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Beklenen burs'));
      expect(find.text('Beklenen burs'), findsOneWidget);
      expect(find.text('Bekleyen kira'), findsOneWidget);
      await Scrollable.ensureVisible(
        tester.element(find.byTooltip('Bekleyen kaydı düzenle').first),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Bekleyen kaydı düzenle').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Tutar'),
        '2500',
      );
      await tester.ensureVisible(find.text('Kaydet'));
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      expect(store.scheduledExpenses.first.amount, 250000);
      expect(store.balance, 0);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'radar includes both signs and keeps detached historical records once',
    () {
      final store = memoryStore();
      store.entries.addAll([
        Entry(
          id: 'income',
          title: 'Maaş',
          amount: 100000,
          income: true,
          date: DateTime(2027, 1, 1),
          category: 'Maaş',
        ),
        Entry(
          id: 'deleted:0',
          title: 'Eski seri',
          amount: 5000,
          income: false,
          date: DateTime(2027, 1, 2),
          category: 'Diğer',
          rule: 'deleted',
        ),
      ]);
      store.scheduledExpenses.add(
        ScheduledExpense(
          id: 'expected',
          title: 'Burs',
          category: 'Diğer',
          amount: 20000,
          due: DateTime(2027, 2, 5),
          income: true,
        ),
      );
      store.rules.add(
        RepeatRule(
          id: 'rent',
          title: 'Kira',
          amount: 10000,
          income: false,
          start: DateTime(2027, 1, 5),
          endDate: DateTime(2027, 1, 5),
          category: 'Diğer',
          frequency: 3,
        ),
      );
      store.materialize(DateTime(2027, 1, 6));
      final items = annualRadarItems(store, 2027);
      expect(
        items.where((e) => e.income).fold<int>(0, (s, e) => s + e.amount),
        120000,
      );
      expect(
        items.where((e) => !e.income).fold<int>(0, (s, e) => s + e.amount),
        15000,
      );
      expect(items.where((e) => e.id == 'rent').length, 1);
      expect(items.any((e) => e.id == 'deleted:0'), isTrue);
    },
  );
}
