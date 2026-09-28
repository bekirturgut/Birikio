import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:birikio/ui/widget_picker.dart';

void main() {
  testWidgets(
    'widget picker fits a small screen and returns the chosen widget',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => selected = await showDialog<String>(
                  context: context,
                  builder: (_) => const WidgetPickerDialog(),
                ),
                child: const Text('Aç'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Aç'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Hedef yüzdesi'), findsOneWidget);
      expect(find.text('Finansal özet'), findsOneWidget);
    await tester.ensureVisible(find.text('Finansal özet'));
    await tester.pumpAndSettle();
      await tester.tap(find.text('Finansal özet'));
      await tester.pumpAndSettle();
      expect(selected, 'BirikioOverviewWidget');
    },
  );
}
