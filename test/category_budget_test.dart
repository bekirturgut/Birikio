import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:birikio/data/store.dart';
import 'package:birikio/ui/reports.dart';

void main() {
  test(
    'category limits persist separately from general budget and balance',
    () async {
      String? disk;
      FinanceStore create() => FinanceStore(
        read: () async => disk,
        write: (value) async => disk = value,
      );
      final store = create();
      await store.change(() {
        store.budgets['2026-9'] = 30000;
        store.categoryBudgets['2026-9'] = {'Alışveriş': 10000};
        store.entries.add(
          Entry(
            id: 'expense',
            title: 'Market',
            amount: 12000,
            income: false,
            date: DateTime(2026, 9, 2),
            category: 'Alışveriş',
          ),
        );
      });
      final reopened = create();
      await reopened.load();
      expect(reopened.budgets['2026-9'], 30000);
      expect(reopened.categoryBudgets['2026-9']?['Alışveriş'], 10000);
      expect(reopened.categorySpent(DateTime(2026, 9), 'Alışveriş'), 12000);
      expect(reopened.categorySpent(DateTime(2026, 10), 'Alışveriş'), 0);
      expect(reopened.balance, -12000);
    },
  );

  test('renaming a category carries its monthly limits', () async {
    final store = FinanceStore(read: () async => null, write: (_) async {});
    await store.change(() {
      store.addCategory(false, 'Kedi');
      store.categoryBudgets['2026-9'] = {'Kedi': 5000};
      store.categoryBudgets['2026-10'] = {'Kedi': 6000};
    });
    await store.change(
      () => store.renameCategory(false, 'Kedi', 'Evcil hayvan'),
    );
    expect(store.categoryBudgets['2026-9'], {'Evcil hayvan': 5000});
    expect(store.categoryBudgets['2026-10'], {'Evcil hayvan': 6000});
    await store.change(() => store.removeCategory(false, 'Evcil hayvan'));
    expect(store.categoryBudgets['2026-9'], {'Evcil hayvan': 5000});
  });

  testWidgets('category limit can be created and displayed', (tester) async {
    final store = FinanceStore(read: () async => null, write: (_) async {});
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: BudgetPage(store: store)),
        ),
      ),
    );
    await tester.ensureVisible(find.text('Kategori bütçeleri'));
    await tester.tap(find.text('Ekle'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Aylık limit'),
      '500',
    );
    await tester.tap(find.text('Limiti kaydet'));
    await tester.pumpAndSettle();
    expect(
      store.categoryBudgets[store.budgetKey(DateTime.now())]?['Alışveriş'],
      50000,
    );
    expect(find.textContaining('500,00 ₺'), findsWidgets);
  });
}
