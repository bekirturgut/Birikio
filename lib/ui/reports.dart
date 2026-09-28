import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/store.dart';
import '../data/analytics.dart';
import 'widgets.dart';
import 'palette.dart';
import 'forms.dart';

class BudgetPage extends StatefulWidget {
  final FinanceStore store;
  const BudgetPage({super.key, required this.store});
  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  DateTime selected = DateTime(DateTime.now().year, DateTime.now().month);
  @override
  Widget build(BuildContext context) {
    final s = widget.store, key = widget.store.budgetKey(selected);
    final limit = s.budgets[key] ?? 0;
    final spent = s.entries
        .where(
          (e) =>
              !e.income &&
              e.date.year == selected.year &&
              e.date.month == selected.month,
        )
        .fold(0, (v, e) => v + e.amount);
    final categoryLimits = s.categoryBudgets[key] ?? {};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Önceki ay',
              onPressed: () => setState(
                () => selected = DateTime(selected.year, selected.month - 1),
              ),
              icon: Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                '${months[selected.month - 1]} ${selected.year}',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              ),
            ),
            IconButton(
              tooltip: 'Sonraki ay',
              onPressed: () => setState(
                () => selected = DateTime(selected.year, selected.month + 1),
              ),
              icon: Icon(Icons.chevron_right),
            ),
          ],
        ),
        SizedBox(height: 20),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Eyebrow('AYLIK HARCAMA PLANI'),
              SizedBox(height: 24),
              Center(
                child: SizedBox(
                  width: 180,
                  height: 180,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(
                            end: limit == 0 ? 0 : (spent / limit).clamp(0, 1),
                          ),
                          duration: Duration(
                            milliseconds:
                                MediaQuery.disableAnimationsOf(context)
                                ? 0
                                : 800,
                          ),
                          builder: (_, value, _) => CircularProgressIndicator(
                            value: value,
                            strokeWidth: 12,
                            strokeCap: StrokeCap.round,
                            color: spent > limit && limit > 0
                                ? financeColors(context).negative
                                : financeColors(context).positive,
                            backgroundColor: lavender.withValues(alpha: .12),
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            limit == 0
                                ? '—'
                                : '%${(spent / limit * 100).round()}',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'bütçe kullanımı',
                            style: TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 28),
              Text(
                'Harcanan',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: 6),
              Amount(spent, color: financeColors(context).negative),
              SizedBox(height: 18),
              Text(
                limit == 0
                    ? 'Bu ay için henüz bir limit belirlemedin.'
                    : 'Limit: ${money(limit)}\n${spent > limit ? 'Aşım' : 'Kalan'}: ${money((limit - spent).abs())}',
                style: TextStyle(height: 1.7, fontSize: 13),
              ),
              SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => editBudget(limit),
                icon: Icon(Icons.tune_rounded, size: 18),
                label: Text(
                  limit == 0 ? 'Aylık limit belirle' : 'Limiti düzenle',
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 18),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Kategori bütçeleri',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
              ),
            ),
            TextButton.icon(
              onPressed: () => editCategoryBudget(),
              icon: const Icon(Icons.add_rounded, size: 17),
              label: const Text('Ekle'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (categoryLimits.isEmpty)
          Panel(
            child: Text(
              'Henüz kategori limiti yok. Harcamalarını kategori kategori planlayabilirsin.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          ...categoryLimits.entries.map((item) {
            final used = s.categorySpent(selected, item.key);
            final exceeded = used > item.value;
            final color = exceeded
                ? financeColors(context).negative
                : financeColors(context).positive;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.key,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: '${item.key} limitini düzenle',
                          onPressed: () => editCategoryBudget(
                            category: item.key,
                            current: item.value,
                          ),
                          icon: const Icon(Icons.tune_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${money(used)} / ${money(item.value)} · %${(used / item.value * 100).round()}',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: (used / item.value).clamp(0, 1),
                        minHeight: 8,
                        color: color,
                        backgroundColor: color.withValues(alpha: .12),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      exceeded
                          ? '${money(used - item.value)} aşıldı'
                          : '${money(item.value - used)} kaldı',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 14),
        Text(
          'Genel limit ve kategori limitleri ayrı planlardır; kategori limitlerinin toplamı genel limiti değiştirmez. Kategori limiti olmayan giderler de genel harcamaya dahildir. Bütçeler bakiyeni değiştirmez.',
          style: TextStyle(fontSize: 12, height: 1.7),
        ),
      ],
    );
  }

  Future<void> editCategoryBudget({String? category, int? current}) async {
    final availableCategories = widget.store.expenseCategories
        .where(
          (name) =>
              !(widget.store.categoryBudgets[widget.store.budgetKey(
                        selected,
                      )] ??
                      {})
                  .containsKey(name),
        )
        .toList();
    var selectedCategory = category ?? availableCategories.firstOrNull;
    if (selectedCategory == null) return;
    var amountText = current == null
        ? ''
        : (current / 100).toStringAsFixed(2).replaceAll('.', ',');
    String? error;
    var saving = false;
    await sheet(
      context,
      StatefulBuilder(
        builder: (dialogContext, update) => FormShell(
          title: category == null
              ? 'Kategori limiti ekle'
              : 'Kategori limitini düzenle',
          subtitle: '${months[selected.month - 1]} ${selected.year}',
          children: [
            if (category == null)
              DropdownButtonFormField<String>(
                initialValue: selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Gider kategorisi',
                ),
                items: availableCategories
                    .map(
                      (name) =>
                          DropdownMenuItem(value: name, child: Text(name)),
                    )
                    .toList(),
                onChanged: (value) => selectedCategory = value,
              )
            else
              Text(
                category,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: amountText,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Aylık limit',
                suffixText: '₺',
                errorText: error,
              ),
              onChanged: (value) => amountText = value,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final value = parseMoney(amountText);
                      if (value == null || selectedCategory == null) {
                        update(() => error = 'Geçerli bir tutar gir.');
                        return;
                      }
                      update(() => saving = true);
                      try {
                        await widget.store.change(() {
                          final monthly = widget.store.categoryBudgets
                              .putIfAbsent(
                                widget.store.budgetKey(selected),
                                () => {},
                              );
                          monthly[selectedCategory!] = value;
                        });
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        if (mounted) setState(() {});
                      } catch (_) {
                        if (dialogContext.mounted) {
                          update(() {
                            saving = false;
                            error = 'Kaydedilemedi.';
                          });
                        }
                      }
                    },
              child: Text(saving ? 'Kaydediliyor…' : 'Limiti kaydet'),
            ),
            if (category != null)
              TextButton(
                onPressed: saving
                    ? null
                    : () async {
                        update(() => saving = true);
                        try {
                          await widget.store.change(() {
                            widget
                                .store
                                .categoryBudgets[widget.store.budgetKey(
                                  selected,
                                )]
                                ?.remove(category);
                          });
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                          if (mounted) setState(() {});
                        } catch (_) {
                          if (dialogContext.mounted) {
                            update(() {
                              saving = false;
                              error = 'Kaldırılamadı.';
                            });
                          }
                        }
                      },
                child: const Text('Limiti kaldır'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> editBudget(int limit) async {
    final controller = TextEditingController(
      text: limit == 0
          ? ''
          : (limit / 100).toStringAsFixed(2).replaceAll('.', ','),
    );
    String? error;
    bool busy = false;
    await sheet(
      context,
      StatefulBuilder(
        builder: (context, update) => FormShell(
          title: 'Aylık bütçe limiti',
          subtitle:
              '${months[selected.month - 1]} ${selected.year} için planın',
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Harcama limiti',
                suffixText: '₺',
                errorText: error,
              ),
            ),
            SizedBox(height: 20),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      final value = parseMoney(controller.text);
                      if (value == null) {
                        update(() => error = 'Geçerli bir tutar gir.');
                        return;
                      }
                      update(() => busy = true);
                      try {
                        await widget.store.change(
                          () =>
                              widget.store.budgets[widget.store.budgetKey(
                                    selected,
                                  )] =
                                  value,
                        );
                        if (context.mounted) Navigator.pop(context);
                      } catch (_) {
                        if (context.mounted) {
                          update(() {
                            busy = false;
                            error = 'Kaydedilemedi.';
                          });
                        }
                      }
                    },
              child: Text(busy ? 'Kaydediliyor…' : 'Limiti kaydet'),
            ),
            if (limit > 0)
              TextButton(
                onPressed: busy
                    ? null
                    : () async {
                        update(() => busy = true);
                        try {
                          await widget.store.change(
                            () => widget.store.budgets.remove(
                              widget.store.budgetKey(selected),
                            ),
                          );
                          if (context.mounted) Navigator.pop(context);
                        } catch (_) {
                          if (context.mounted) {
                            update(() {
                              busy = false;
                              error = 'Kaydedilemedi.';
                            });
                          }
                        }
                      },
                child: Text('Limiti kaldır'),
              ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(Duration(milliseconds: 400));
    controller.dispose();
    if (mounted) setState(() {});
  }
}

class AnalysisPage extends StatefulWidget {
  final FinanceStore store;
  const AnalysisPage({super.key, required this.store});
  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  String _changeText(int current, int previous) {
    if (previous == 0) {
      return current == 0 ? 'değişim yok' : 'önceki dönemde kayıt yok';
    }
    final percent = ((current - previous) / previous * 100).round();
    return '${percent >= 0 ? '+' : ''}%$percent';
  }

  int mode = 2;
  DateTime selected = day(DateTime.now());
  DateTime get start => switch (mode) {
    0 => day(selected),
    1 => day(selected).subtract(Duration(days: selected.weekday - 1)),
    2 => DateTime(selected.year, selected.month),
    _ => DateTime(selected.year),
  };
  DateTime get end => switch (mode) {
    0 => DateTime(start.year, start.month, start.day + 1),
    1 => DateTime(start.year, start.month, start.day + 7),
    2 => DateTime(start.year, start.month + 1),
    _ => DateTime(start.year + 1),
  };
  List<Entry> between(DateTime a, DateTime b) => widget.store.entries
      .where((e) => !e.date.isBefore(a) && e.date.isBefore(b))
      .toList();
  int sum(List<Entry> list, bool income) =>
      list.where((e) => e.income == income).fold(0, (v, e) => v + e.amount);
  String get label => switch (mode) {
    0 => dateLabel(start),
    1 => '${dateLabel(start)} – ${dateLabel(end.subtract(Duration(days: 1)))}',
    2 => '${months[selected.month - 1]} ${selected.year}',
    _ => '${selected.year}',
  };
  @override
  Widget build(BuildContext context) {
    final previousStart = switch (mode) {
      0 => start.subtract(const Duration(days: 1)),
      1 => start.subtract(const Duration(days: 7)),
      2 => DateTime(start.year, start.month - 1),
      _ => DateTime(start.year - 1),
    };
    final insights = calculateInsights(
      widget.store,
      start,
      end,
      previousStart: previousStart,
      now: DateTime.now(),
      monthly: mode == 2,
    );
    final list = between(start, end),
        income = sum(between(start, end), true),
        expense = sum(between(start, end), false);
    final cats = <String, int>{};
    for (final e in list.where((e) => !e.income)) {
      cats[e.category] = (cats[e.category] ?? 0) + e.amount;
    }
    final sorted = cats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: List.generate(
              4,
              (i) => Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => mode = i),
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 220),
                    padding: EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: mode == i
                          ? financeColors(context).accent
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      ['Günlük', 'Haftalık', 'Aylık', 'Yıllık'][i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: mode == i
                            ? financeColors(context).onAccent
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: 18),
        InkWell(
          onTap: selectPeriod,
          borderRadius: BorderRadius.circular(18),
          child: Panel(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  color: financeColors(context).accent,
                  size: 20,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
                Icon(Icons.expand_more_rounded),
              ],
            ),
          ),
        ),
        SizedBox(height: 18),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Eyebrow('DÖNEMİN ÖZETİ'),
              SizedBox(height: 12),
              Amount(
                income - expense,
                size: 34,
                color: income >= expense
                    ? Theme.of(context).colorScheme.primary
                    : financeColors(context).negative,
              ),
              SizedBox(height: 4),
              Text(
                'Net gelir · ${list.length} işlem',
                style: TextStyle(fontSize: 12),
              ),
              SizedBox(height: 28),
              chartBar(
                'Gelir',
                income,
                math.max(income, expense),
                financeColors(context).positive,
              ),
              SizedBox(height: 18),
              chartBar(
                'Gider',
                expense,
                math.max(income, expense),
                financeColors(context).negative,
              ),
              SizedBox(height: 24),
              Text(
                income == 0
                    ? 'Birikim oranı için bu dönemde gelir kaydı gerekiyor.'
                    : 'Gelirinin %${((income - expense) / income * 100).round()} kadarı harcamalar sonrası kaldı.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 18),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Eyebrow('HARCAMA İÇGÖRÜLERİ'),
              const SizedBox(height: 14),
              Text(
                'Önceki döneme göre gelir: ${_changeText(income, insights.previousIncome)}',
              ),
              const SizedBox(height: 6),
              Text(
                'Önceki döneme göre gider: ${_changeText(expense, insights.previousExpense)}',
              ),
              const SizedBox(height: 6),
              Text('Günlük ortalama gider: ${money(insights.dailyAverage)}'),
              if (insights.topCategory != null) ...[
                const SizedBox(height: 6),
                Text('En çok harcanan kategori: ${insights.topCategory}'),
              ],
              if (insights.highestDay != null) ...[
                const SizedBox(height: 6),
                Text(
                  'En yüksek harcama günü: ${dateLabel(insights.highestDay!)}',
                ),
              ],
              const SizedBox(height: 6),
              Text(
                'Hedeflere aktarılan net tutar: ${money(insights.goalTransfers)}',
              ),
              if (insights.projectedMonthlyExpense != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Ay sonu gider tahmini: ${money(insights.projectedMonthlyExpense!)}',
                ),
                Text(
                  'Şimdiye kadarki günlük ortalama ayın kalanında sürerse; en az 7 günlük kayıtla hesaplanır.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if ((widget.store.budgets[widget.store.budgetKey(start)] ?? 0) >
                    0)
                  Text(
                    insights.projectedMonthlyExpense! >
                            widget.store.budgets[widget.store.budgetKey(start)]!
                        ? 'Bu hızla aylık limit aşılabilir.'
                        : 'Bu hızla aylık limit içinde kalınabilir.',
                  ),
              ],
            ],
          ),
        ),
        SizedBox(height: 26),
        Text(
          'Paran nereye gidiyor?',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
        SizedBox(height: 14),
        Panel(
          child: Column(
            children: [
              if (sorted.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 24,
                    horizontal: 12,
                  ),
                  child: Column(
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: .75, end: 1),
                        duration: Duration(
                          milliseconds: MediaQuery.disableAnimationsOf(context)
                              ? 0
                              : 600,
                        ),
                        curve: Curves.easeOutBack,
                        builder: (_, value, child) =>
                            Transform.scale(scale: value, child: child),
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: financeColors(
                              context,
                            ).accent.withValues(alpha: .1),
                          ),
                          child: Icon(
                            Icons.donut_small_rounded,
                            color: financeColors(context).accent,
                            size: 32,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Bu dönemde gider kaydı yok.',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Kayıt eklediğinde kategori dağılımın burada belirecek.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ...sorted.map(
                (e) => Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(e.key, style: TextStyle(fontSize: 13)),
                          ),
                          Text(
                            money(e.value),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            '%${(e.value / expense * 100).round()}',
                            style: TextStyle(
                              fontSize: 10,
                              color: financeColors(context).accent,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: e.value / expense,
                          color: financeColors(context).accent,
                          backgroundColor: lavender.withValues(alpha: .1),
                          minHeight: 5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget chartBar(String label, int value, int max, Color color) => Column(
    children: [
      Row(
        children: [
          Text(label, style: TextStyle(fontSize: 12)),
          Spacer(),
          Text(
            money(value),
            style: TextStyle(fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
      SizedBox(height: 10),
      TweenAnimationBuilder<double>(
        tween: Tween(end: max == 0 ? 0 : value / max),
        duration: Duration(
          milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 700,
        ),
        curve: Curves.easeOutCubic,
        builder: (_, v, _) => ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: v,
            color: color,
            backgroundColor: color.withValues(alpha: .08),
            minHeight: 12,
          ),
        ),
      ),
    ],
  );
  Future<void> selectPeriod() async {
    if (mode < 2) {
      final result = await showDatePicker(
        context: context,
        initialDate: selected.isAfter(DateTime.now())
            ? DateTime.now()
            : selected,
        firstDate: DateTime(2000),
        lastDate: DateTime.now(),
      );
      if (result != null) setState(() => selected = result);
      return;
    }
    int year = selected.year;
    await sheet(
      context,
      StatefulBuilder(
        builder: (context, update) => FormShell(
          title: mode == 2 ? 'Ay seç' : 'Yıl seç',
          subtitle: 'Döneme girmeden önce gelir ve giderine göz at.',
          children: [
            if (mode == 2)
              Row(
                children: [
                  IconButton(
                    tooltip: 'Önceki yıl',
                    onPressed: year > 2000 ? () => update(() => year--) : null,
                    icon: Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      '$year',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Sonraki yıl',
                    onPressed: year < DateTime.now().year
                        ? () => update(() => year++)
                        : null,
                    icon: Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ...List.generate(
              mode == 2
                  ? 12
                  : DateTime.now().year -
                        math.min<int>(
                          DateTime.now().year - 4,
                          widget.store.entries.fold<int>(
                            DateTime.now().year,
                            (v, e) => math.min<int>(v, e.date.year),
                          ),
                        ) +
                        1,
              (i) {
                final a = mode == 2
                    ? DateTime(year, i + 1)
                    : DateTime(DateTime.now().year - i);
                final b = mode == 2
                    ? DateTime(year, i + 2)
                    : DateTime(a.year + 1);
                final data = between(a, b);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    mode == 2 ? months[i] : '${a.year}',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Wrap(
                      spacing: 14,
                      runSpacing: 4,
                      children: [
                        Text(
                          '↙ ${money(sum(data, true))}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        Text(
                          '↗ ${money(sum(data, false))}',
                          style: TextStyle(
                            fontSize: 11,
                            color: financeColors(context).negative,
                          ),
                        ),
                      ],
                    ),
                  ),
                  trailing: Icon(Icons.chevron_right, size: 18),
                  onTap: () {
                    setState(() => selected = a);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
