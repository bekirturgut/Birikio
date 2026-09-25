import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelir_gider/data/store.dart';
import 'package:gelir_gider/ui/app.dart';

void main() {
  testWidgets('Create a goal, deposit, withdraw and edit a transaction', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = FinanceStore(read: () async => null, write: (_) async {})
      ..followSystem = false
      ..motion = false;
    store.entries.add(
      Entry(
        id: 'seed',
        title: 'Maaş kaydı',
        amount: 1000000,
        income: true,
        date: DateTime.now(),
        category: 'Maaş',
      ),
    );
    await tester.pumpWidget(BirikioApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('İlk hedefimi oluştur'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Hedef tutar'),
      '25000',
    );
    await tester.ensureVisible(find.text('Hedefimi oluştur'));
    await tester.tap(find.text('Hedefimi oluştur'));
    await tester.pumpAndSettle();
    expect(store.goals.single.title, 'Motor hedefim');
    await tester.tap(find.text('Para ekle'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Tutar'), '2000');
    await tester.tap(find.text('Birikime aktar'));
    await tester.pumpAndSettle();
    expect(store.savings, 200000);
    expect(store.balance, 800000);
    await tester.tap(find.byTooltip('Birikimden para çek'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Tutar'), '500');
    await tester.tap(find.text('Bakiyeme geri al'));
    await tester.pumpAndSettle();
    expect(store.savings, 150000);
    expect(store.balance, 850000);
    await tester.tap(find.text('Gelir').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Maaş kaydı'));
    await tester.tap(find.text('Maaş kaydı'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kaydı düzenle'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Tutar'),
      '12000',
    );
    await tester.ensureVisible(find.text('Kaydet'));
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(store.balance, 1050000);
    expect(store.transfers.length, 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
