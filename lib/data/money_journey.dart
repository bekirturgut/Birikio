import 'store.dart';

enum FlowKind { income, withdrawal, priorBalance, expense, deposit, remaining }

class FlowBucket {
  final String label;
  final int amount;
  final FlowKind kind;
  final String? category;
  final String? goalId;
  const FlowBucket(
    this.label,
    this.amount,
    this.kind, {
    this.category,
    this.goalId,
  });
}

class MoneyJourney {
  final List<FlowBucket> sources;
  final List<FlowBucket> destinations;
  final int income, expenses, deposits, withdrawals, change;
  const MoneyJourney({
    required this.sources,
    required this.destinations,
    required this.income,
    required this.expenses,
    required this.deposits,
    required this.withdrawals,
    required this.change,
  });
  int get total => sources.fold(0, (sum, bucket) => sum + bucket.amount);
}

MoneyJourney calculateMoneyJourney(
  FinanceStore store,
  DateTime start,
  DateTime end,
) {
  final incomeByCategory = <String, int>{};
  final expenseByCategory = <String, int>{};
  final depositsByGoal = <String, int>{};
  final withdrawalsByGoal = <String, int>{};
  for (final entry in store.entries.where(
    (entry) => !entry.date.isBefore(start) && entry.date.isBefore(end),
  )) {
    final map = entry.income ? incomeByCategory : expenseByCategory;
    map[entry.category] = (map[entry.category] ?? 0) + entry.amount;
  }
  for (final transfer in store.transfers.where(
    (transfer) => !transfer.date.isBefore(start) && transfer.date.isBefore(end),
  )) {
    final map = transfer.amount > 0 ? depositsByGoal : withdrawalsByGoal;
    map[transfer.goal] = (map[transfer.goal] ?? 0) + transfer.amount.abs();
  }
  int sum(Map<String, int> map) => map.values.fold(0, (a, b) => a + b);
  final income = sum(incomeByCategory);
  final expenses = sum(expenseByCategory);
  final deposits = sum(depositsByGoal);
  final withdrawals = sum(withdrawalsByGoal);
  final change = income + withdrawals - expenses - deposits;
  final goalTitles = {for (final goal in store.goals) goal.id: goal.title};
  final sources = <FlowBucket>[
    for (final entry in incomeByCategory.entries)
      FlowBucket(entry.key, entry.value, FlowKind.income, category: entry.key),
    for (final entry in withdrawalsByGoal.entries)
      FlowBucket(
        'Çekilen · ${goalTitles[entry.key] ?? 'Eski hedef'}',
        entry.value,
        FlowKind.withdrawal,
        goalId: entry.key,
      ),
    if (change < 0)
      FlowBucket('Önceki bakiye / açık', -change, FlowKind.priorBalance),
  ]..sort((a, b) => b.amount.compareTo(a.amount));
  final destinations = <FlowBucket>[
    for (final entry in expenseByCategory.entries)
      FlowBucket(entry.key, entry.value, FlowKind.expense, category: entry.key),
    for (final entry in depositsByGoal.entries)
      FlowBucket(
        'Birikim · ${goalTitles[entry.key] ?? 'Eski hedef'}',
        entry.value,
        FlowKind.deposit,
        goalId: entry.key,
      ),
    if (change > 0) FlowBucket('Bu dönem artan', change, FlowKind.remaining),
  ]..sort((a, b) => b.amount.compareTo(a.amount));
  return MoneyJourney(
    sources: sources,
    destinations: destinations,
    income: income,
    expenses: expenses,
    deposits: deposits,
    withdrawals: withdrawals,
    change: change,
  );
}
