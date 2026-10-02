import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/store.dart';
import '../data/analytics.dart';
import '../data/money_journey.dart';
import 'widgets.dart';
import 'palette.dart';
import 'forms.dart';
import 'money_journey.dart';
import 'annual_radar.dart';
import 'orbit_chart.dart';
import 'money_input.dart';

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
        FeatureCard(
          color: financeColors(context).positive,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconBadge(
                    Icons.donut_large_rounded,
                    color: financeColors(context).positive,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Eyebrow('AYLIK PLAN'),
                        SizedBox(height: 4),
                        Text(
                          'Harcama bütçen',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const InfoButton(
                    title: 'Bütçe hesabı',
                    message:
                        'Genel limit ve kategori limitleri ayrı planlardır; kategori limitlerinin toplamı genel limiti değiştirmez. Kategori limiti olmayan giderler de genel harcamaya dahildir. Bütçeler bakiyeni değiştirmez.',
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  SizedBox(
                    width: 84,
                    height: 84,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox.expand(
                          child: CircularProgressIndicator(
                            value: limit == 0 ? 0 : (spent / limit).clamp(0, 1),
                            strokeWidth: 7,
                            strokeCap: StrokeCap.round,
                            color: spent > limit && limit > 0
                                ? financeColors(context).negative
                                : financeColors(context).positive,
                            backgroundColor: financeColors(
                              context,
                            ).positive.withValues(alpha: .12),
                          ),
                        ),
                        Text(
                          limit == 0
                              ? '—'
                              : '%${(spent / limit * 100).round()}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Eyebrow('HARCANAN'),
                        const SizedBox(height: 6),
                        Amount(
                          spent,
                          size: 26,
                          color: financeColors(context).negative,
                        ),
                        const SizedBox(height: 5),
                        const Text('bu ay', style: TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: _budgetMetric('Limit', limit)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _budgetMetric(
                      spent > limit && limit > 0 ? 'Aşım' : 'Kalan',
                      limit == 0 ? 0 : (limit - spent).abs(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => editBudget(limit),
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: Text(
                  limit == 0 ? 'Aylık limit belirle' : 'Limiti düzenle',
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 18),
        SectionCard(
          title: 'Kategori bütçeleri',
          icon: Icons.category_outlined,
          action: TextButton.icon(
            onPressed: () => editCategoryBudget(),
            icon: const Icon(Icons.add_rounded, size: 17),
            label: const Text('Ekle'),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (categoryLimits.isEmpty)
                Row(
                  children: [
                    const IconBadge(Icons.pie_chart_outline_rounded, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Henüz kategori limiti yok',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
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
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _budgetMetric(String label, int amount) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: .65),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 5),
        Amount(amount, size: 17),
      ],
    ),
  );

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
                isExpanded: true,
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
              inputFormatters: const [MoneyInputFormatter()],
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
              inputFormatters: const [MoneyInputFormatter()],
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
  int view = 0;
  int breakdownKind = 0;
  String _changeText(int current, int previous) {
    if (previous == 0) {
      return current == 0 ? 'Kayıt yok' : 'İlk dönem';
    }
    final percent = ((current - previous) / previous * 100).round();
    return '${percent >= 0 ? '+' : ''}%$percent';
  }

  Widget _trendTile(
    String label,
    int current,
    int previous,
    IconData icon,
    Color color,
  ) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: color.withValues(alpha: .17)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 12),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 5),
        Text(
          _changeText(current, previous),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          previous == 0 ? 'Önceki dönemde veri yok' : 'Önceki döneme göre',
          maxLines: 2,
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );

  Widget _insightRow(String label, String value, IconData icon, Color color) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      );

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
    for (final e in list.where((e) => e.income == (breakdownKind == 1))) {
      cats[e.category] = (cats[e.category] ?? 0) + e.amount;
    }
    final sorted = cats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final journey = calculateMoneyJourney(widget.store, start, end);
    const chartColors = <Color>[
      Color(0xFF70E5BC),
      Color(0xFFB9A3FF),
      Color(0xFFFFD780),
      Color(0xFFFF7D8C),
      Color(0xFF78B9FF),
      Color(0xFFDA9EFB),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              for (var i = 0; i < 3; i++)
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => setState(() => view = i),
                    child: AnimatedContainer(
                      duration: Duration(
                        milliseconds: MediaQuery.disableAnimationsOf(context)
                            ? 0
                            : 250,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: view == i
                            ? financeColors(
                                context,
                              ).accent.withValues(alpha: .22)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: view == i
                              ? financeColors(
                                  context,
                                ).accent.withValues(alpha: .55)
                              : Colors.transparent,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            [
                              Icons.insights_rounded,
                              Icons.route_rounded,
                              Icons.calendar_month_rounded,
                            ][i],
                            size: 19,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            ['Özet', 'Para akışı', 'Yıllık radar'][i],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: view == i
                                  ? financeColors(context).accent
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        AnimatedSwitcher(
          duration: Duration(milliseconds: widget.store.motion ? 200 : 0),
          reverseDuration: Duration(
            milliseconds: widget.store.motion ? 150 : 0,
          ),
          transitionBuilder: (child, animation) =>
              BlurTabTransition(animation: animation, child: child),
          child: Column(
            key: ValueKey('analysis-$view-$mode-${selected.toIso8601String()}'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (view != 2) ...[
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
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Icon(Icons.expand_more_rounded),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 18),
              ],
              if (view == 1) ...[
                MoneyJourneyCard(store: widget.store, start: start, end: end),
                if (journey.total > 0) ...[
                  const SizedBox(height: 18),
                  Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Eyebrow('DÖNEMİN PAYLARI'),
                        const SizedBox(height: 7),
                        const Text(
                          'Para hangi yöne aktı?',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 14),
                        OrbitChart(
                          key: ValueKey(
                            'flow-${start.toIso8601String()}-${end.toIso8601String()}',
                          ),
                          centerLabel: 'Dönemin payı',
                          slices: [
                            ChartSlice(
                              'Giderler',
                              journey.expenses,
                              financeColors(context).negative,
                            ),
                            ChartSlice(
                              'Birikime yatırılan',
                              journey.deposits,
                              financeColors(context).accent,
                            ),
                            ChartSlice(
                              'Dönemde artan',
                              math.max(0, journey.change),
                              financeColors(context).positive,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
              if (view == 2) AnnualRadar(store: widget.store),
              if (view == 0) ...[
                FeatureCard(
                  color: financeColors(context).positive,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconBadge(
                            Icons.insights_rounded,
                            color: financeColors(context).positive,
                            size: 36,
                          ),
                          const SizedBox(width: 10),
                          const Eyebrow('DÖNEMİN ÖZETİ'),
                        ],
                      ),
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
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: financeColors(
                                context,
                              ).accent.withValues(alpha: .13),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.auto_awesome_rounded,
                              size: 19,
                              color: financeColors(context).accent,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Eyebrow('HARCAMA İÇGÖRÜLERİ'),
                                SizedBox(height: 3),
                                Text(
                                  'Bu dönemin izleri',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _trendTile(
                              'Gelir değişimi',
                              income,
                              insights.previousIncome,
                              Icons.south_west_rounded,
                              financeColors(context).positive,
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: _trendTile(
                              'Gider değişimi',
                              expense,
                              insights.previousExpense,
                              Icons.north_east_rounded,
                              financeColors(context).negative,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _insightRow(
                        'Günlük ortalama',
                        money(insights.dailyAverage),
                        Icons.today_rounded,
                        financeColors(context).gold,
                      ),
                      if (insights.topCategory != null)
                        _insightRow(
                          'En çok harcanan',
                          insights.topCategory!,
                          Icons.category_rounded,
                          financeColors(context).negative,
                        ),
                      if (insights.highestDay != null)
                        _insightRow(
                          'En yoğun gün',
                          dateLabel(insights.highestDay!),
                          Icons.calendar_today_rounded,
                          financeColors(context).gold,
                        ),
                      _insightRow(
                        'Hedeflere net aktarım',
                        money(insights.goalTransfers),
                        Icons.savings_rounded,
                        financeColors(context).accent,
                      ),
                      if (insights.projectedMonthlyExpense != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: financeColors(
                              context,
                            ).accent.withValues(alpha: .09),
                            borderRadius: BorderRadius.circular(17),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AY SONU TAHMİNİ',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.3,
                                  color: financeColors(context).accent,
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                money(insights.projectedMonthlyExpense!),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                (widget.store.budgets[widget.store.budgetKey(
                                              start,
                                            )] ??
                                            0) >
                                        0
                                    ? insights.projectedMonthlyExpense! >
                                              widget.store.budgets[widget.store
                                                  .budgetKey(start)]!
                                          ? 'Bu hızla aylık limit aşılabilir.'
                                          : 'Bu hızla aylık limit içinde kalınabilir.'
                                    : 'Şu ana kadarki harcama hızına göre.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: 26),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Kategori dağılımı',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    for (var i = 0; i < 2; i++)
                      Padding(
                        padding: const EdgeInsets.only(left: 5),
                        child: ChoiceChip(
                          label: Text(
                            i == 0 ? 'Gider' : 'Gelir',
                            style: const TextStyle(fontSize: 10),
                          ),
                          selected: breakdownKind == i,
                          onSelected: (_) => setState(() => breakdownKind = i),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 14),
                Panel(
                  child: Column(
                    children: [
                      if (sorted.isNotEmpty) ...[
                        OrbitChart(
                          key: ValueKey(
                            'category-$breakdownKind-${start.toIso8601String()}-${end.toIso8601String()}',
                          ),
                          centerLabel: breakdownKind == 0
                              ? 'Gider payı'
                              : 'Gelir payı',
                          slices: [
                            for (var i = 0; i < sorted.length && i < 5; i++)
                              ChartSlice(
                                sorted[i].key,
                                sorted[i].value,
                                chartColors[i % chartColors.length],
                              ),
                            if (sorted.length > 5)
                              ChartSlice(
                                'Diğer kategoriler',
                                sorted
                                    .skip(5)
                                    .fold(0, (sum, entry) => sum + entry.value),
                                chartColors[5],
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
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
                                  milliseconds:
                                      MediaQuery.disableAnimationsOf(context)
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
                              Text(
                                breakdownKind == 0
                                    ? 'Bu dönemde gider kaydı yok.'
                                    : 'Bu dönemde gelir kaydı yok.',
                                style: const TextStyle(
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
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
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
