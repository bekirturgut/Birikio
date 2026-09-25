// Generate documentation screenshots with isolated, fictional in-memory data.
// Run: flutter test tools/capture_readme.dart --dart-define=FLUTTER_SDK=C:/flutter
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelir_gider/data/store.dart';
import 'package:gelir_gider/ui/app.dart';

// The test runner uses Ahem for unspecified fonts. Match device typography.
class DocumentationApp extends BirikioApp {
  const DocumentationApp({super.key, required super.store});
  @override
  ThemeData theme(bool dark) {
    final base = super.theme(dark);
    ButtonStyle withFont(ButtonStyle style) => style.copyWith(
      textStyle: WidgetStateProperty.resolveWith(
        (states) => (style.textStyle?.resolve(states) ?? const TextStyle())
            .copyWith(fontFamily: 'Roboto', fontFamilyFallback: ['Symbols']),
      ),
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(fontFamilyFallback: ['Symbols']),
      primaryTextTheme: base.primaryTextTheme.apply(
        fontFamilyFallback: ['Symbols'],
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: withFont(base.filledButtonTheme.style!),
      ),
      textButtonTheme: TextButtonThemeData(
        style: withFont(base.textButtonTheme.style!),
      ),
    );
  }
}

void main() {
  testWidgets('Render README gallery from the real UI', (tester) async {
    final sdk = const String.fromEnvironment('FLUTTER_SDK');
    if (sdk.isEmpty) {
      throw StateError('Pass --dart-define=FLUTTER_SDK=/path/to/flutter');
    }
    final loader = FontLoader('Roboto');
    loader.addFont(
      Future.value(
        ByteData.sublistView(
          File(
            '$sdk/bin/cache/artifacts/material_fonts/roboto-regular.ttf',
          ).readAsBytesSync(),
        ),
      ),
    );
    await loader.load();
    final symbols = File(
      Platform.isWindows
          ? '${Platform.environment['WINDIR']}/Fonts/seguisym.ttf'
          : '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
    );
    if (symbols.existsSync()) {
      final fallback = FontLoader(
        'Symbols',
      )..addFont(Future.value(ByteData.sublistView(symbols.readAsBytesSync())));
      await fallback.load();
    }
    for (final font in {
      'Ahem': 'roboto-regular.ttf',
      'MaterialIcons': 'materialicons-regular.otf',
    }.entries) {
      final fontLoader = FontLoader(font.key);
      fontLoader.addFont(
        Future.value(
          ByteData.sublistView(
            File(
              '$sdk/bin/cache/artifacts/material_fonts/${font.value}',
            ).readAsBytesSync(),
          ),
        ),
      );
      await fontLoader.load();
    }
    tester.view.physicalSize = const Size(412, 980);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = FinanceStore(read: () async => null, write: (_) async {})
      ..followSystem = false
      ..motion = false;
    final now = DateTime.now();
    store.entries.addAll([
      Entry(
        id: '1',
        title: 'Aylık maaş',
        amount: 5500000,
        income: true,
        date: DateTime(now.year, now.month, 1),
        category: 'Maaş',
      ),
      Entry(
        id: '2',
        title: 'Tasarım projesi',
        amount: 750000,
        income: true,
        date: DateTime(now.year, now.month, 2),
        category: 'Serbest iş',
      ),
      Entry(
        id: '3',
        title: 'Ev kirası',
        amount: 1200000,
        income: false,
        date: DateTime(now.year, now.month, 3),
        category: 'Ev & faturalar',
      ),
      Entry(
        id: '4',
        title: 'Market alışverişi',
        amount: 284000,
        income: false,
        date: DateTime(now.year, now.month, 4),
        category: 'Alışveriş',
      ),
      Entry(
        id: '5',
        title: 'Yol & yakıt',
        amount: 180000,
        income: false,
        date: DateTime(now.year, now.month, 5),
        category: 'Ulaşım',
      ),
      Entry(
        id: '6',
        title: 'Kahve molaları',
        amount: 120000,
        income: false,
        date: DateTime(now.year, now.month, 6),
        category: 'Yeme içme',
      ),
    ]);
    final goal = Goal(
      id: 'demo',
      title: 'İlk motorum',
      icon: 'Motor',
      target: 13000000,
    );
    store.goals.add(goal);
    store.transfers.add(
      Transfer(id: 'demo-transfer', goal: goal.id, amount: 3500000, date: now),
    );
    store.budgets[store.budgetKey(now)] = 2500000;
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: DocumentationApp(store: store),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> capture(String name) async {
      expect(tester.takeException(), isNull);
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          'docs/images/$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture('home-dark');
    await store.change(() => store.dark = false);
    await tester.pumpAndSettle();
    await capture('home-light');
    await store.change(() {
      goal.target = 3500000;
    });
    await tester.pumpAndSettle();
    await capture('goal-complete');
    await store.change(() => store.dark = true);
    await tester.tap(find.text('Analiz').last);
    await tester.pumpAndSettle();
    await capture('analysis');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
