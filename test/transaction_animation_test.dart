import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:birikio/ui/widgets.dart';

void main() {
  for (final income in [true, false]) {
    testWidgets(
      'transaction moment renders and completes for ${income ? 'income' : 'expense'}',
      (tester) async {
        var completed = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox.expand(
                child: MoneyBurst(
                  adding: income,
                  onEnd: () => completed = true,
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));
        expect(
          find.text(income ? 'GELİR KAYDEDİLDİ' : 'GİDER KAYDEDİLDİ'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(milliseconds: 1300));
        expect(completed, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
