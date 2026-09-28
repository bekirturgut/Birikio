import 'package:birikio/data/store.dart';
import 'package:birikio/ui/app.dart';
import 'package:birikio/ui/forms.dart';
import 'package:birikio/ui/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('every goal category renders an animated scene', (tester) async {
    for (final category in goalIcons.keys) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 110,
              child: GoalScene(icon: category, motion: true),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.takeException(), isNull, reason: category);
    }
  });

  testWidgets(
    'goal category picker shows more than ten choices and saves selection',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = FinanceStore(read: () async => null, write: (_) async {})
        ..motion = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GoalForm(store: store)),
        ),
      );
      expect(goalIcons.length, greaterThan(10));
      expect(
        find.text('Kategoriyi değiştir · ${goalIcons.length} seçenek'),
        findsOneWidget,
      );
      expect(find.byType(ChoiceChip), findsNothing);
      await tester.tap(
        find.text('Kategoriyi değiştir · ${goalIcons.length} seçenek'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Birikim kategorisi'), findsOneWidget);
      await tester.drag(find.byType(GridView).last, const Offset(0, -420));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Müzik').last);
      await tester.pumpAndSettle();
      expect(find.text('Müzik'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Hedef tutar'),
        '1000',
      );
      await tester.ensureVisible(find.text('Hedefimi oluştur'));
      await tester.tap(find.text('Hedefimi oluştur'));
      await tester.pumpAndSettle();
      expect(store.goals.single.icon, 'Müzik');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('goal form saves a monthly amount and due day together', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = FinanceStore(read: () async => null, write: (_) async {})
      ..motion = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GoalForm(store: store)),
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Hedef tutar'),
      '1000',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Planlanan aylık birikim'),
      '100',
    );
    final due = find.text('Ayın kaçıncı günü?');
    await tester.ensureVisible(due);
    await tester.pumpAndSettle();
    final daysInMonth = DateTime(
      DateTime.now().year,
      DateTime.now().month + 1,
      0,
    ).day;
    expect(
      find.text('Bu ay $daysInMonth gün · kısa aylarda son gün geçerlidir'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<GridView>(find.byType(GridView))
          .childrenDelegate
          .estimatedChildCount,
      daysInMonth,
    );
    await tester.tap(find.text('5'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Hedefimi oluştur'));
    await tester.tap(find.text('Hedefimi oluştur'));
    await tester.pumpAndSettle();
    expect(store.goals.single.monthlyContribution, 10000);
    expect(store.goals.single.monthlyDueDay, 5);
    expect(store.goals.single.icon, 'Birikim');
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile displays the highest priority monthly savings alert', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime.now();
    final store = FinanceStore(read: () async => null, write: (_) async {});
    store.goals.add(
      Goal(
        id: 'goal',
        title: 'Ev',
        icon: 'Ev',
        target: 1000000,
        monthlyContribution: 20000,
        monthlyDueDay: 1,
        monthlyPlanStart: DateTime(now.year, now.month - 1, 1),
      ),
    );
    await tester.pumpWidget(BirikioApp(store: store));
    await tester.tap(find.text('Profil').last);
    await tester.pumpAndSettle();
    expect(find.text('Bu ay dikkat et'), findsOneWidget);
    expect(find.textContaining('eksik yatırdın'), findsOneWidget);
    await tester.ensureVisible(find.textContaining('eksik yatırdın'));
    await tester.drag(find.byType(ListView).first, const Offset(0, -180));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('eksik yatırdın'));
    await tester.pumpAndSettle();
    expect(find.text('Paranın genel resmi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
