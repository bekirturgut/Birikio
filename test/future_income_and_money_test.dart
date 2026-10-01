import 'package:birikio/data/store.dart';
import 'package:birikio/ui/money_input.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'future one-off income stays out of balance and arrives once on due date',
    () async {
      String? disk;
      FinanceStore create() => FinanceStore(
        read: () async => disk,
        write: (value) async => disk = value,
      );
      final store = create();
      await store.change(
        () => store.scheduledExpenses.add(
          ScheduledExpense(
            id: 'income-1',
            title: 'Beklenen ödeme',
            category: 'Diğer',
            amount: 12345600,
            due: DateTime(2027, 10, 15),
            income: true,
          ),
        ),
      );
      expect(store.balance, 0);
      await store.catchUp(now: DateTime(2027, 10, 14));
      expect(store.balance, 0);
      final reopened = create();
      await reopened.load();
      expect(reopened.balance, 0);
      await reopened.catchUp(now: DateTime(2027, 10, 15));
      expect(reopened.balance, 12345600);
      await reopened.catchUp(now: DateTime(2027, 10, 16));
      expect(reopened.entries.length, 1);
      expect(reopened.entries.single.income, isTrue);
    },
  );

  test('money input groups millions and keeps decimal digits', () {
    const formatter = MoneyInputFormatter();
    const old = TextEditingValue.empty;
    final grouped = formatter.formatEditUpdate(
      old,
      const TextEditingValue(
        text: '123456789',
        selection: TextSelection.collapsed(offset: 9),
      ),
    );
    expect(grouped.text, '123.456.789');
    expect(grouped.selection.baseOffset, grouped.text.length);
    expect(parseMoney(grouped.text), 12345678900);
    final decimal = formatter.formatEditUpdate(
      old,
      const TextEditingValue(
        text: '1234567,891',
        selection: TextSelection.collapsed(offset: 11),
      ),
    );
    expect(decimal.text, '1.234.567,89');
    expect(parseMoney(decimal.text), 123456789);
  });
}
