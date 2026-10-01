import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:birikio/data/store.dart';
import 'package:birikio/ui/app.dart';
import 'package:birikio/ui/forms.dart';

void main() {
  test(
    'custom categories survive reload and old records keep their category',
    () async {
      String? disk;
      FinanceStore create() => FinanceStore(
        read: () async => disk,
        write: (value) async => disk = value,
      );
      final store = create();
      await store.change(() {
        store.addCategory(false, 'Evcil hayvan');
        store.entries.add(
          Entry(
            id: 'cat',
            title: 'Mama',
            amount: 12000,
            income: false,
            date: DateTime(2026, 9, 1),
            category: 'Evcil hayvan',
          ),
        );
      });
      final reopened = create();
      await reopened.load();
      expect(reopened.categoriesFor(false), contains('Evcil hayvan'));
      expect(reopened.entries.single.category, 'Evcil hayvan');
      expect(reopened.expense, 12000);
      expect(
        () => reopened.addCategory(false, 'evcil hayvan'),
        throwsArgumentError,
      );
    },
  );

  test(
    'rename updates matching entries and rules; delete preserves history',
    () async {
      String? disk;
      final store = FinanceStore(
        read: () async => disk,
        write: (value) async => disk = value,
      );
      await store.change(() {
        store.addCategory(false, 'Kedi');
        store.entries.add(
          Entry(
            id: 'a',
            title: 'Mama',
            amount: 1000,
            income: false,
            date: DateTime(2026, 9, 1),
            category: 'Kedi',
          ),
        );
        store.rules.add(
          RepeatRule(
            id: 'r',
            title: 'Mama',
            amount: 1000,
            income: false,
            start: DateTime(2026, 9, 1),
            category: 'Kedi',
            frequency: 3,
            cursor: 1,
            endDate: DateTime(2026, 9, 1),
          ),
        );
        store.scheduledExpenses.add(
          ScheduledExpense(
            id: 'future-cat',
            title: 'Veteriner',
            category: 'Kedi',
            amount: 5000,
            due: DateTime(2027, 1, 1),
          ),
        );
      });
      final categoryId = store.categoryIdFor(false, 'Kedi');
      final budgetId = store.categoryBudgetId(DateTime(2026, 9), 'Kedi');
      await store.change(
        () => store.renameCategory(false, 'Kedi', 'Evcil hayvan'),
      );
      expect(store.categoryIdFor(false, 'Evcil hayvan'), categoryId);
      expect(
        store.categoryBudgetId(DateTime(2026, 9), 'Evcil hayvan'),
        budgetId,
      );
      expect(store.entries.single.category, 'Evcil hayvan');
      expect(store.rules.single.category, 'Evcil hayvan');
      expect(store.scheduledExpenses.single.category, 'Evcil hayvan');
      await expectLater(
        store.change(
          () => store.renameCategory(false, 'Evcil hayvan', 'Alışveriş'),
        ),
        throwsArgumentError,
      );
      expect(store.entries.single.category, 'Evcil hayvan');
      await store.change(() => store.removeCategory(false, 'Evcil hayvan'));
      expect(store.categoriesFor(false), isNot(contains('Evcil hayvan')));
      expect(store.entries.single.category, 'Evcil hayvan');
      expect(store.rules.single.category, 'Evcil hayvan');
      final reopened = FinanceStore(
        read: () async => disk,
        write: (_) async {},
      );
      await reopened.load();
      expect(reopened.entries.single.category, 'Evcil hayvan');
      expect(reopened.scheduledExpenses.single.category, 'Evcil hayvan');
      expect(reopened.categoriesFor(false), isNot(contains('Evcil hayvan')));
    },
  );

  testWidgets('combined page filters transaction type and category', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = FinanceStore(read: () async => null, write: (_) async {});
    store.entries.addAll([
      Entry(
        id: 'i',
        title: 'Maaş kaydı',
        amount: 50000,
        income: true,
        date: DateTime(2026, 9, 1),
        category: 'Maaş',
      ),
      Entry(
        id: 'e1',
        title: 'Market kaydı',
        amount: 10000,
        income: false,
        date: DateTime(2026, 9, 2),
        category: 'Alışveriş',
      ),
      Entry(
        id: 'e2',
        title: 'Otobüs kaydı',
        amount: 2000,
        income: false,
        date: DateTime(2026, 9, 3),
        category: 'Ulaşım',
      ),
    ]);
    await tester.pumpWidget(BirikioApp(store: store));
    await tester.tap(find.text('Gelir & Gider').last);
    await tester.pumpAndSettle();
    expect(find.text('Maaş kaydı'), findsOneWidget);
    expect(find.text('Market kaydı'), findsOneWidget);
    await tester.tap(find.text('Giderler'));
    await tester.pumpAndSettle();
    expect(find.text('Maaş kaydı'), findsNothing);
    expect(find.text('Market kaydı'), findsOneWidget);
    await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ulaşım').last);
    await tester.pumpAndSettle();
    expect(find.text('Market kaydı'), findsNothing);
    expect(find.text('Otobüs kaydı'), findsOneWidget);
  });

  testWidgets('entry form adds and uses a custom category', (tester) async {
    final store = FinanceStore(read: () async => null, write: (_) async {});
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: EntryForm(store: store, income: false)),
      ),
    );
    await tester.ensureVisible(find.text('Yeni kategori ekle'));
    await tester.tap(find.text('Yeni kategori ekle'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Kategori adı'),
      'Kedi',
    );
    await tester.tap(find.text('Ekle'));
    await tester.pumpAndSettle();
    expect(store.categoriesFor(false), contains('Kedi'));
    expect(find.text('Kedi'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Tutar'), '120');
    await tester.ensureVisible(find.text('Kaydet'));
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(store.entries.single.category, 'Kedi');
  });

  testWidgets('amount filter narrows combined records and can be cleared', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = FinanceStore(read: () async => null, write: (_) async {});
    store.entries.addAll([
      Entry(
        id: 'small',
        title: 'Küçük gider',
        amount: 1000,
        income: false,
        date: DateTime(2026, 9, 1),
        category: 'Alışveriş',
      ),
      Entry(
        id: 'big',
        title: 'Büyük gider',
        amount: 10000,
        income: false,
        date: DateTime(2026, 9, 2),
        category: 'Alışveriş',
      ),
    ]);
    await tester.pumpWidget(BirikioApp(store: store));
    await tester.tap(find.text('Gelir & Gider').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Filtrele ve sırala'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'En az'), '50');
    await tester.ensureVisible(find.text('Uygula'));
    await tester.tap(find.text('Uygula'));
    await tester.pumpAndSettle();
    expect(find.text('Büyük gider'), findsOneWidget);
    expect(find.text('Küçük gider'), findsNothing);
  });
}
