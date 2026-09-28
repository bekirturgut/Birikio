import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:birikio/data/store.dart';
import 'package:birikio/ui/app.dart';
import 'package:birikio/ui/widgets.dart';

void main() {
  testWidgets('dashboard icon follows light and dark theme', (tester) async {
    final store = FinanceStore(read: () async => null, write: (_) async {});
    store.followSystem = false;
    store.dark = true;
    await tester.pumpWidget(BirikioApp(store: store));
    expect(find.byIcon(Icons.nightlight_round), findsOneWidget);
    store.dark = false;
    await tester.pumpWidget(BirikioApp(store: store));
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.byIcon(Icons.wb_sunny_rounded), findsOneWidget);
  });

  testWidgets('wallet shows savings and budget together or separately', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = FinanceStore(read: () async => null, write: (_) async {});
    await tester.pumpWidget(BirikioApp(store: store));
    await tester.tap(find.text('Cüzdan').last);
    await tester.pumpAndSettle();
    expect(find.text('HAYALLERİNE AYIRDIĞIN'), findsOneWidget);
    tester
        .widget<InkWell>(
          find
              .ancestor(
                of: find.text('Bütçe').last,
                matching: find.byType(InkWell),
              )
              .first,
        )
        .onTap!();
    await tester.pumpAndSettle();
    expect(find.text('AYLIK HARCAMA PLANI'), findsOneWidget);
    expect(find.text('HAYALLERİNE AYIRDIĞIN'), findsNothing);
    tester
        .widget<InkWell>(
          find
              .ancestor(
                of: find.text('Birikim').last,
                matching: find.byType(InkWell),
              )
              .first,
        )
        .onTap!();
    await tester.pumpAndSettle();
    expect(find.text('HAYALLERİNE AYIRDIĞIN'), findsOneWidget);
    expect(find.text('AYLIK HARCAMA PLANI'), findsNothing);
  });

  testWidgets('bottom navigation wave follows tab direction', (tester) async {
    final store = FinanceStore(read: () async => null, write: (_) async {});
    await tester.pumpWidget(BirikioApp(store: store));
    await tester.tap(find.text('Cüzdan').last);
    await tester.pump();
    expect(
      tester
          .widgetList<CinematicPageTransition>(
            find.byType(CinematicPageTransition),
          )
          .every((transition) => transition.direction == 1),
      isTrue,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gelir & Gider').last);
    await tester.pump();
    expect(
      tester
          .widgetList<CinematicPageTransition>(
            find.byType(CinematicPageTransition),
          )
          .every((transition) => transition.direction == -1),
      isTrue,
    );
  });
}
