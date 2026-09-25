import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelir_gider/data/store.dart';
import 'package:gelir_gider/ui/app.dart';
import 'package:gelir_gider/ui/brand.dart';

void main() {
  testWidgets(
    'Launch animates the mark and waits for local data before opening home',
    (tester) async {
      final loaded = Completer<String?>();
      final store = FinanceStore(
        read: () => loaded.future,
        write: (_) async {},
      );
      await tester.pumpWidget(BirikioApp(store: store, initialize: true));
      expect(find.byKey(const ValueKey('birikio-launch')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 800));
      final mark = tester.widget<BirikioMark>(find.byType(BirikioMark));
      expect(mark.progress, greaterThan(0));
      expect(mark.progress, lessThan(1));
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Genel bakış'), findsNothing);
      loaded.complete(null);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text('Genel bakış'), findsOneWidget);
      expect(find.text('Birikio'), findsOneWidget);
      expect(find.byKey(const ValueKey('birikio-launch')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Saved light theme, reduced motion and records survive the renamed launch',
    (tester) async {
      final original = FinanceStore(read: () async => null, write: (_) async {})
        ..dark = false
        ..followSystem = false
        ..motion = false;
      original.goals.add(
        Goal(id: 'existing', title: 'Motorum', icon: 'Motor', target: 100000),
      );
      final store = FinanceStore(
        read: () async => jsonEncode(original.json()),
        write: (_) async {},
      );
      await tester.pumpWidget(BirikioApp(store: store, initialize: true));
      await tester.pumpAndSettle();
      expect(find.text('Motorum'), findsOneWidget);
      expect(store.dark, false);
      expect(
        Theme.of(tester.element(find.text('Genel bakış'))).brightness,
        Brightness.light,
      );
      expect(find.byKey(const ValueKey('birikio-launch')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('Launch read failure allows retry and never opens empty home', (
    tester,
  ) async {
    var attempts = 0;
    final store =
        FinanceStore(
            read: () async {
              if (attempts++ == 0) throw Exception('unavailable');
              return null;
            },
            write: (_) async {},
          )
          ..followSystem = false
          ..motion = false;
    await tester.pumpWidget(BirikioApp(store: store, initialize: true));
    await tester.pumpAndSettle();
    expect(find.text('Genel bakış'), findsNothing);
    expect(find.text('Tekrar dene'), findsOneWidget);
    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();
    expect(find.text('Genel bakış'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
