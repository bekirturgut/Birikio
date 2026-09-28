import 'package:birikio/data/money_journey.dart';
import 'package:birikio/data/store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'income, expense, deposits and withdrawals reconcile without double counting',
    () {
      final store = FinanceStore(read: () async => null, write: (_) async {});
      store.goals.add(
        Goal(id: 'g', title: 'Motor', icon: 'Motor', target: 500000),
      );
      store.entries.addAll([
        Entry(
          id: 'income',
          title: 'Maaş',
          amount: 100000,
          income: true,
          date: DateTime(2026, 9, 1),
          category: 'Maaş',
        ),
        Entry(
          id: 'expense',
          title: 'Market',
          amount: 30000,
          income: false,
          date: DateTime(2026, 9, 2),
          category: 'Market',
        ),
        Entry(
          id: 'outside',
          title: 'Eski gelir',
          amount: 20000,
          income: true,
          date: DateTime(2026, 8, 31),
          category: 'Diğer',
        ),
      ]);
      store.transfers.addAll([
        Transfer(
          id: 'deposit',
          goal: 'g',
          amount: 25000,
          date: DateTime(2026, 9, 3),
        ),
        Transfer(
          id: 'withdraw',
          goal: 'g',
          amount: -5000,
          date: DateTime(2026, 9, 4),
        ),
      ]);
      final flow = calculateMoneyJourney(
        store,
        DateTime(2026, 9),
        DateTime(2026, 10),
      );
      expect(flow.income, 100000);
      expect(flow.expenses, 30000);
      expect(flow.deposits, 25000);
      expect(flow.withdrawals, 5000);
      expect(flow.change, 50000);
      expect(flow.total, 105000);
      expect(
        flow.destinations.fold(0, (sum, item) => sum + item.amount),
        flow.total,
      );
      expect(
        flow.sources
            .where((item) => item.kind == FlowKind.withdrawal)
            .single
            .amount,
        5000,
      );
      expect(
        flow.destinations
            .where((item) => item.kind == FlowKind.deposit)
            .single
            .amount,
        25000,
      );
    },
  );

  test('a shortfall is shown as prior balance or an open deficit', () {
    final store = FinanceStore(read: () async => null, write: (_) async {});
    store.entries.add(
      Entry(
        id: 'expense',
        title: 'Fatura',
        amount: 40000,
        income: false,
        date: DateTime(2026, 9, 5),
        category: 'Ev & faturalar',
      ),
    );
    final flow = calculateMoneyJourney(
      store,
      DateTime(2026, 9),
      DateTime(2026, 10),
    );
    expect(flow.change, -40000);
    expect(flow.sources.single.kind, FlowKind.priorBalance);
    expect(flow.total, 40000);
    expect(flow.destinations.single.amount, flow.total);
  });
}
