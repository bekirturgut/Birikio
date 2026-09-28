import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/annual_radar.dart';
import '../data/store.dart';
import 'forms.dart';
import 'palette.dart';
import 'widgets.dart';

class AnnualRadar extends StatefulWidget {
  final FinanceStore store;
  const AnnualRadar({super.key, required this.store});
  @override
  State<AnnualRadar> createState() => _AnnualRadarState();
}

class _AnnualRadarState extends State<AnnualRadar> {
  int year = DateTime.now().year;
  int selectedMonth = DateTime.now().month;

  Future<void> edit([AnnualPlan? plan]) async {
    final saved = await sheet<bool>(
      context,
      _AnnualPlanForm(store: widget.store, plan: plan),
    );
    if (saved == true && mounted) {
      final updated = plan == null
          ? widget.store.annualPlans.last
          : widget.store.annualPlans.firstWhere((item) => item.id == plan.id);
      final nextDue = nextAnnualPlanDue(updated, DateTime.now());
      setState(() {
        year = nextDue.year;
        selectedMonth = nextDue.month;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            plan == null ? 'Yıllık masraf planlandı.' : 'Plan güncellendi.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> delete(AnnualPlan plan) async {
    if (!await confirm(
      context,
      'Plan silinsin mi?',
      '${plan.title} takvimden kaldırılır. Geçmiş gelir ve gider kayıtları etkilenmez.',
    )) {
      return;
    }
    try {
      await widget.store.change(
        () => widget.store.annualPlans.removeWhere((p) => p.id == plan.id),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plan silinemedi. Tekrar dene.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = annualRadarItems(widget.store, year);
    final monthly = List<int>.generate(
      12,
      (index) => items
          .where((item) => item.due.month == index + 1)
          .fold(0, (sum, item) => sum + item.amount),
    );
    final annualTotal = monthly.fold(0, (a, b) => a + b);
    final monthItems = items
        .where((item) => item.due.month == selectedMonth)
        .toList();
    final reserve = suggestedMonthlyAnnualReserve(widget.store, DateTime.now());
    final colors = financeColors(context);
    final maxMonth = monthly.fold(0, math.max);
    final titleRow = Row(
      children: [
        const Expanded(
          child: Text(
            'Yıllık masraf radarı',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
        ),
        TextButton.icon(
          onPressed: () => edit(),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Planla'),
        ),
      ],
    );
    if (widget.store.annualPlans.isEmpty &&
        !widget.store.rules.any(
          (r) => r.active && !r.income && r.frequency == 4,
        )) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          titleRow,
          const SizedBox(height: 10),
          Panel(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: Duration(
                      milliseconds: MediaQuery.disableAnimationsOf(context)
                          ? 0
                          : 850,
                    ),
                    builder: (_, progress, child) =>
                        Transform.rotate(angle: progress * .25, child: child),
                    child: Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.gold.withValues(alpha: .12),
                        border: Border.all(
                          color: colors.gold.withValues(alpha: .3),
                        ),
                      ),
                      child: Icon(
                        Icons.radar_rounded,
                        color: colors.gold,
                        size: 39,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'Büyük masrafları önceden gör',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Sigorta, bakım veya okul ödemesini planla. Vadesine kadar ayda ne kadar ayırman gerektiğini gösterelim.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 17),
                  FilledButton.icon(
                    onPressed: () => edit(),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('İlk masrafı planla'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        titleRow,
        const SizedBox(height: 10),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Önceki yıl',
                    onPressed: () => setState(() {
                      year--;
                      selectedMonth = 1;
                    }),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Text(
                      '$year · yaklaşan büyük masraflar',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Sonraki yıl',
                    onPressed: () => setState(() {
                      year++;
                      selectedMonth = 1;
                    }),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                money(annualTotal),
                style: TextStyle(
                  color: colors.gold,
                  fontSize: 31,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              Text(
                'Bu yıldaki planlı yıllık masraf toplamı',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: colors.gold.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.gold.withValues(alpha: .25)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month_rounded, color: colors.gold),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bugünden itibaren aylık ayırma önerisi',
                            style: TextStyle(
                              color: colors.gold,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            money(reserve),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 9),
              Text(
                'Bu bir hazırlık hesabıdır; tutar bakiyenden düşmez ve ayrılmış para olarak kaydedilmez.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 10,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 12,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 9,
                  crossAxisSpacing: 9,
                  childAspectRatio: 1.35,
                ),
                itemBuilder: (context, index) {
                  final month = index + 1;
                  final selected = selectedMonth == month;
                  final value = monthly[index];
                  return Material(
                    color: selected
                        ? colors.gold.withValues(alpha: .2)
                        : Theme.of(context).colorScheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                      side: BorderSide(
                        color: colors.gold.withValues(
                          alpha: selected ? .65 : .12,
                        ),
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(17),
                      onTap: () => setState(() => selectedMonth = month),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              months[index].substring(0, 3).toUpperCase(),
                              style: TextStyle(
                                color: selected
                                    ? colors.gold
                                    : colors.goalMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                              ),
                            ),
                            Text(
                              value == 0 ? '—' : money(value),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: value == 0
                                    ? FontWeight.w500
                                    : FontWeight.w800,
                              ),
                            ),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(5),
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(
                                  end: maxMonth == 0 ? 0 : value / maxMonth,
                                ),
                                duration: Duration(
                                  milliseconds:
                                      MediaQuery.disableAnimationsOf(context)
                                      ? 0
                                      : 700,
                                ),
                                builder: (_, progress, _) =>
                                    LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 3,
                                      color: colors.gold,
                                      backgroundColor: colors.gold.withValues(
                                        alpha: .12,
                                      ),
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${months[selectedMonth - 1]} · ${monthItems.length} plan',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        if (monthItems.isEmpty)
          Panel(
            child: Text(
              'Bu ay için yıllık masraf planı yok.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          ...monthItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Panel(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: colors.gold.withValues(alpha: .13),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        item.fromRule
                            ? Icons.autorenew_rounded
                            : Icons.event_rounded,
                        color: colors.gold,
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            '${dateLabel(item.due)} · ${item.category}${item.fromRule ? ' · düzenli kayıt' : ''}',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          money(item.amount),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (!item.fromRule)
                          PopupMenuButton<String>(
                            tooltip: 'Plan seçenekleri',
                            padding: EdgeInsets.zero,
                            icon: const Icon(
                              Icons.more_horiz_rounded,
                              size: 20,
                            ),
                            onSelected: (action) {
                              final plan = widget.store.annualPlans
                                  .where((p) => p.id == item.id)
                                  .firstOrNull;
                              if (plan == null) return;
                              if (action == 'edit') edit(plan);
                              if (action == 'delete') delete(plan);
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text('Düzenle'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Sil'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 7),
        Text(
          'Yıllık tekrarlayan giderler otomatik görünür. Manuel planlar ödeme yapıldı anlamına gelmez; gerçek gideri ayrıca kaydetmelisin.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 11,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _AnnualPlanForm extends StatefulWidget {
  final FinanceStore store;
  final AnnualPlan? plan;
  const _AnnualPlanForm({required this.store, this.plan});
  @override
  State<_AnnualPlanForm> createState() => _AnnualPlanFormState();
}

class _AnnualPlanFormState extends State<_AnnualPlanForm> {
  final form = GlobalKey<FormState>();
  late final title = TextEditingController(text: widget.plan?.title);
  late final amount = TextEditingController(
    text: widget.plan == null
        ? ''
        : (widget.plan!.amount / 100).toStringAsFixed(2).replaceAll('.', ','),
  );
  late String category =
      widget.plan?.category ??
      widget.store.expenseCategories.firstOrNull ??
      'Diğer';
  late DateTime due = widget.plan == null
      ? DateTime(DateTime.now().year, DateTime.now().month + 1, 1)
      : nextAnnualPlanDue(widget.plan!, DateTime.now());
  bool dateChanged = false;
  bool saving = false;
  String? error;

  @override
  void dispose() {
    title.dispose();
    amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: form,
    child: FormShell(
      title: widget.plan == null ? 'Büyük masrafı planla' : 'Planı düzenle',
      subtitle: 'Vade gelmeden hazırlığını gör. Bu plan bakiyeni değiştirmez.',
      children: [
        TextFormField(
          controller: title,
          maxLength: 40,
          decoration: const InputDecoration(
            labelText: 'Masraf adı',
            hintText: 'Örn. araç sigortası',
          ),
          validator: (text) =>
              text == null || text.trim().isEmpty ? 'Bir ad gir.' : null,
        ),
        TextFormField(
          controller: amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Tahmini tutar',
            suffixText: '₺',
          ),
          validator: (text) =>
              parseMoney(text ?? '') == null ? 'Geçerli bir tutar gir.' : null,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: category,
          decoration: const InputDecoration(labelText: 'Gider kategorisi'),
          items: {...widget.store.expenseCategories, category}
              .map((name) => DropdownMenuItem(value: name, child: Text(name)))
              .toList(),
          onChanged: (value) {
            if (value != null) setState(() => category = value);
          },
        ),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            Icons.calendar_month_rounded,
            color: financeColors(context).gold,
          ),
          title: Text(
            'Her yıl ${due.day} ${months[due.month - 1]}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: const Text('Kısa aylarda son gün kullanılır'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () async {
            final now = day(DateTime.now());
            final chosen = await showDatePicker(
              context: context,
              initialDate: due.isBefore(now) ? now : due,
              firstDate: now,
              lastDate: DateTime(now.year + 5),
            );
            if (chosen != null) {
              setState(() {
                due = chosen;
                dateChanged = true;
              });
            }
          },
        ),
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: saving
              ? null
              : () async {
                  if (!form.currentState!.validate()) return;
                  setState(() => saving = true);
                  try {
                    await widget.store.change(() {
                      final plan = AnnualPlan(
                        id: widget.plan?.id ?? uid(),
                        title: title.text.trim(),
                        category: category,
                        amount: parseMoney(amount.text)!,
                        month: due.month,
                        dueDay: due.day,
                        startYear: widget.plan == null || dateChanged
                            ? due.year
                            : widget.plan!.startYear,
                      );
                      if (widget.plan == null) {
                        widget.store.annualPlans.add(plan);
                      } else {
                        final index = widget.store.annualPlans.indexWhere(
                          (p) => p.id == plan.id,
                        );
                        widget.store.annualPlans[index] = plan;
                      }
                    });
                    if (context.mounted) Navigator.pop(context, true);
                  } catch (_) {
                    if (mounted) {
                      setState(() {
                        saving = false;
                        error = 'Kaydedilemedi. Tekrar dene.';
                      });
                    }
                  }
                },
          icon: const Icon(Icons.check_rounded),
          label: Text(saving ? 'Kaydediliyor…' : 'Planı kaydet'),
        ),
      ],
    ),
  );
}
