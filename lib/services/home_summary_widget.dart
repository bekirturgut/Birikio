import 'dart:io';
import 'package:home_widget/home_widget.dart';
import '../data/store.dart';

class HomeSummaryWidget {
  static Future<void> sync(FinanceStore store) async {
    if (!Platform.isAndroid) return;
    final goal = store.featured;
    final progress = goal == null || goal.target <= 0
        ? 0
        : (store.saved(goal) / goal.target * 100).round().clamp(0, 100);
    await HomeWidget.saveWidgetData<String>(
      'title',
      'Birikio · kullanılabilir',
    );
    await HomeWidget.saveWidgetData<String>(
      'balance',
      store.showWidgetBalance ? money(store.balance) : 'Bakiye gizli',
    );
    await HomeWidget.saveWidgetData<String>(
      'goal',
      goal == null
          ? 'Hedef eklemek için dokun'
          : '${goal.title} · %$progress tamamlandı',
    );
    await HomeWidget.saveWidgetData<int>('progress', progress);
    await HomeWidget.saveWidgetData<String>(
      'goalTitle',
      goal?.title ?? 'Yeni hedefini belirle',
    );
    final now = DateTime.now();
    final monthEntries = store.entries.where(
      (e) => e.date.year == now.year && e.date.month == now.month,
    );
    final income = monthEntries
        .where((e) => e.income)
        .fold<int>(0, (sum, e) => sum + e.amount);
    final expense = monthEntries
        .where((e) => !e.income)
        .fold<int>(0, (sum, e) => sum + e.amount);
    final limit = store.budgets[store.budgetKey(now)] ?? 0;
    await HomeWidget.saveWidgetData<String>('income', money(income));
    await HomeWidget.saveWidgetData<String>('expense', money(expense));
    await HomeWidget.saveWidgetData<String>(
      'budget',
      limit > 0 ? money(limit - expense) : 'Limit belirle',
    );
    await HomeWidget.saveWidgetData<int>(
      'budgetProgress',
      limit > 0 ? (expense / limit * 100).round().clamp(0, 100) : 0,
    );
    await HomeWidget.saveWidgetData<int>(
      'budgetPercent',
      limit > 0 ? (expense / limit * 100).round() : 0,
    );
    for (final name in [
      'BirikioMiniWidget',
      'BirikioBalanceWidget',
      'BirikioGoalWidget',
      'BirikioBudgetWidget',
      'BirikioOverviewWidget',
    ]) {
      await HomeWidget.updateWidget(androidName: name);
    }
  }
}
