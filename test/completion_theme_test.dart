import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelir_gider/data/store.dart';
import 'package:gelir_gider/ui/app.dart';
import 'package:gelir_gider/ui/palette.dart';
import 'package:gelir_gider/ui/widgets.dart';

double contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return ((x > y ? x : y) + .05) / ((x > y ? y : x) + .05);
}

void main() {
  test('Semantic foregrounds meet normal text contrast in both themes', () {
    for (final dark in [false, true]) {
      final c = FinanceColors(dark);
      final surfaces = [
        dark ? const Color(0xFF171D2B) : Colors.white,
        dark ? const Color(0xFF0C101B) : const Color(0xFFF5F6FA),
      ];
      for (final foreground in [c.positive, c.negative, c.accent, c.gold]) {
        for (final background in surfaces) {
          expect(contrast(foreground, background), greaterThanOrEqualTo(4.5));
        }
      }
      for (final background in c.goalBackground) {
        for (final foreground in [c.goalText, c.goalMuted, c.accent]) {
          expect(contrast(foreground, background), greaterThanOrEqualTo(4.5));
        }
      }
      for (final background in c.completedBackground) {
        for (final foreground in [
          c.completedText,
          c.completedMuted,
          c.gold,
          c.positive,
        ]) {
          expect(contrast(foreground, background), greaterThanOrEqualTo(4.5));
        }
      }
      expect(contrast(c.onAccent, c.accent), greaterThanOrEqualTo(4.5));
      expect(contrast(c.onAccent, c.positive), greaterThanOrEqualTo(4.5));
    }
  });
  testWidgets(
    'Completion changes appearance, theme changes surfaces, withdrawal restores progress',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = FinanceStore(read: () async => null, write: (_) async {})
        ..followSystem = false
        ..motion = false;
      final goal = Goal(
        id: 'motor',
        title: 'RKS R250',
        icon: 'Motor',
        target: 100000,
      );
      store.goals.add(goal);
      store.entries.add(
        Entry(
          id: 'income',
          title: 'Gelir',
          amount: 200000,
          income: true,
          date: DateTime.now(),
          category: 'Diğer',
        ),
      );
      await tester.pumpWidget(BirikioApp(store: store));
      await tester.pumpAndSettle();
      expect(find.byType(AchievementScene), findsNothing);
      final active =
          tester
                  .widget<AnimatedContainer>(
                    find.byKey(const ValueKey('goal-card-motor')),
                  )
                  .decoration
              as BoxDecoration;
      await store.move(goal, 100000);
      await tester.pumpAndSettle();
      expect(find.byType(AchievementScene), findsOneWidget);
      expect(find.text('Hedefe ulaştın'), findsOneWidget);
      expect(find.text('Yeni hedef oluştur'), findsOneWidget);
      expect(find.byType(GoalScene), findsNothing);
      final complete =
          tester
                  .widget<AnimatedContainer>(
                    find.byKey(const ValueKey('goal-card-motor')),
                  )
                  .decoration
              as BoxDecoration;
      expect(complete.gradient, isNot(active.gradient));
      await store.change(() => store.dark = false);
      await tester.pumpAndSettle();
      final light =
          tester
                  .widget<AnimatedContainer>(
                    find.byKey(const ValueKey('goal-card-motor')),
                  )
                  .decoration
              as BoxDecoration;
      expect(light.gradient, isNot(complete.gradient));
      expect(
        (light.gradient as LinearGradient).colors.first.computeLuminance(),
        greaterThan(.7),
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byTooltip('Birikimden para çek'));
      await tester.tap(find.byTooltip('Birikimden para çek'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Tutar'), '100');
      await tester.tap(find.text('Bakiyeme geri al'));
      await tester.pumpAndSettle();
      expect(find.byType(AchievementScene), findsNothing);
      expect(find.byType(GoalScene), findsOneWidget);
      expect(find.text('Hedefe ulaştın'), findsNothing);
      expect(find.text('Para ekle'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
