import 'package:flutter/material.dart';
import '../data/annual_radar.dart';
import '../data/store.dart';
import 'forms.dart';
import 'palette.dart';
import 'widgets.dart';
import 'money_input.dart';
import 'recurring_editor.dart';

class AnnualRadar extends StatefulWidget {
  final FinanceStore store;
  const AnnualRadar({super.key, required this.store});
  @override
  State<AnnualRadar> createState() => _AnnualRadarState();
}

class _AnnualRadarState extends State<AnnualRadar> {
  int year = DateTime.now().year;
  int selectedMonth = DateTime.now().month;

  Future<void> recordPayment(RadarExpense item) async {
    final controller = TextEditingController(text: moneyInput(item.amount));
    final amount = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${item.title} ödendi'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: const [MoneyInputFormatter()],
          decoration: const InputDecoration(
            labelText: 'Ödenen tutar',
            suffixText: '₺',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = parseMoney(controller.text);
              if (parsed != null) Navigator.pop(dialogContext, parsed);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (amount == null) return;
    try {
      if (item.scheduled) {
        final expense = widget.store.scheduledExpenses.firstWhere(
          (e) => e.id == item.id,
        );
        await widget.store.markScheduledExpensePaid(expense, amount: amount);
      } else if (item.fromRule) {
        final rule = widget.store.rules.firstWhere((r) => r.id == item.id);
        await widget.store.markBillPaid(rule, item.period!, amount: amount);
      } else {
        final plan = widget.store.annualPlans.firstWhere(
          (p) => p.id == item.id,
        );
        await widget.store.markAnnualPlanPaid(plan, year, amount: amount);
      }
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Ödeme kaydedilemedi.')));
      }
    }
  }

  Future<void> editScheduled(ScheduledExpense expense) async {
    await sheet<bool>(
      context,
      EntryForm(
        store: widget.store,
        income: expense.income,
        scheduled: expense,
      ),
    );
  }

  Widget _totalPill(bool income, int amount) {
    final color = income
        ? financeColors(context).positive
        : financeColors(context).negative;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                income ? Icons.south_west_rounded : Icons.north_east_rounded,
                size: 14,
                color: color,
              ),
              const SizedBox(width: 5),
              Text(
                income ? 'Gelir' : 'Gider',
                style: TextStyle(fontSize: 11, color: color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${income ? '+' : '−'} ${money(amount)}',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: color,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

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
    final colors = financeColors(context);
    int total(bool income, [int? month]) => items
        .where(
          (e) => e.income == income && (month == null || e.due.month == month),
        )
        .fold<int>(0, (sum, e) => sum + (e.paidAmount ?? e.amount));
    final peak = List.generate(
      12,
      (i) => total(true, i + 1) + total(false, i + 1),
    ).fold<int>(1, (a, b) => a > b ? a : b);
    final monthItems = items
        .where((e) => e.due.month == selectedMonth)
        .toList();
    const months = [
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FeatureCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const IconBadge(Icons.calendar_month_rounded),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Eyebrow('YILIN GÖRÜNÜMÜ'),
                        SizedBox(height: 4),
                        Text(
                          'Yıllık radar',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const InfoButton(
                    title: 'Yıllık radar',
                    message:
                        'Gerçekleşen ve bekleyen gelir ile giderler. Ay seçerek ayrıntıları gör. Yıllık net, bekleyen planları da içerir; kullanılabilir bakiye değildir.',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Önceki yıl',
                    onPressed: () => setState(() => year--),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      '$year',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Sonraki yıl',
                    onPressed: () => setState(() => year++),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Eyebrow('YILLIK NET'),
              const SizedBox(height: 6),
              Amount(
                total(true) - total(false),
                size: 32,
                color: colors.accent,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(child: _totalPill(true, total(true))),
                  const SizedBox(width: 10),
                  Expanded(child: _totalPill(false, total(false))),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) => GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: constraints.maxWidth < 300 ? 2 : 3,
              mainAxisExtent: 108,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: 12,
            itemBuilder: (context, index) {
              final m = index + 1;
              final selected = selectedMonth == m;
              return InkWell(
                onTap: () => setState(() => selectedMonth = m),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: selected
                        ? colors.accent.withValues(alpha: .14)
                        : Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected ? colors.accent : Colors.transparent,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        months[index],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: selected ? colors.accent : null,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: total(true, m) / peak,
                                minHeight: 4,
                                color: colors.positive,
                                backgroundColor: colors.positive.withValues(
                                  alpha: .1,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: total(false, m) / peak,
                                minHeight: 4,
                                color: colors.negative,
                                backgroundColor: colors.negative.withValues(
                                  alpha: .1,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          total(true, m) == 0
                              ? '+ —'
                              : '+ ${money(total(true, m))}',
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.positive,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          total(false, m) == 0
                              ? '− —'
                              : '− ${money(total(false, m))}',
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.negative,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        SectionCard(
          title: '${months[selectedMonth - 1]} · ${monthItems.length} kayıt',
          icon: Icons.view_agenda_outlined,
          child: Row(
            children: [
              Expanded(child: _totalPill(true, total(true, selectedMonth))),
              const SizedBox(width: 10),
              Expanded(child: _totalPill(false, total(false, selectedMonth))),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (monthItems.isEmpty)
          const EmptyState(
            title: 'Bu ay için kayıt yok',
            subtitle: 'Gelir ve giderlerin burada bir araya gelecek.',
            icon: Icons.event_available_outlined,
          ),
        ...monthItems.take(5).map(radarRecordCard),
        if (monthItems.length > 5)
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => RecordListPage<RadarExpense>(
                  store: widget.store,
                  title: 'Takvim kayıtları',
                  scope: '${months[selectedMonth - 1]} $year',
                  items: () => annualRadarItems(
                    widget.store,
                    year,
                  ).where((e) => e.due.month == selectedMonth).toList(),
                  itemBuilder: radarRecordCard,
                ),
              ),
            ),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text('Tümünü gör (${monthItems.length})'),
          ),
      ],
    );
  }

  Widget radarRecordCard(RadarExpense item) {
    final colors = financeColors(context);

    final rule = item.fromRule
        ? widget.store.rules.where((r) => r.id == item.id).firstOrNull
        : null;
    final canPay =
        !item.income &&
        !item.paid &&
        (item.scheduled ||
            (!item.fromRule) ||
            (rule?.isBill == true && rule?.automaticPayment == false));
    final late = !item.paid && item.due.isBefore(day(DateTime.now()));
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Panel(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconBadge(
                  item.income
                      ? Icons.south_west_rounded
                      : Icons.north_east_rounded,
                  color: item.income ? colors.positive : colors.negative,
                  size: 34,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  '${item.income ? '+' : '−'}${money(item.paidAmount ?? item.amount)}',
                  style: TextStyle(
                    color: item.income ? colors.positive : colors.negative,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${dateLabel(item.due)} · ${item.category}',
              style: const TextStyle(fontSize: 12),
            ),
            if (item.paid &&
                item.plannedDue != null &&
                day(item.plannedDue!) != day(item.due))
              Text(
                'Vade: ${dateLabel(item.plannedDue!)} · İşlem: ${dateLabel(item.due)}',
                style: const TextStyle(fontSize: 12),
              ),
            const SizedBox(height: 6),
            Text(
              item.paid
                  ? (item.income ? 'Alındı' : 'Ödendi')
                  : late
                  ? 'Gecikti'
                  : item.income
                  ? 'Beklenen gelir'
                  : 'Bekliyor',
              style: TextStyle(
                fontSize: 12,
                color: item.paid
                    ? colors.positive
                    : late
                    ? colors.negative
                    : colors.accent,
              ),
            ),
            if (canPay || (!item.recorded && !item.fromRule))
              Wrap(
                alignment: WrapAlignment.end,
                children: [
                  if (canPay)
                    TextButton(
                      onPressed: () => recordPayment(item),
                      child: const Text('Ödendi olarak kaydet'),
                    ),
                  if (!item.recorded && !item.fromRule)
                    PopupMenuButton<String>(
                      tooltip: 'Plan seçenekleri',
                      onSelected: (action) async {
                        if (item.scheduled) {
                          final p = widget.store.scheduledExpenses.firstWhere(
                            (p) => p.id == item.id,
                          );
                          if (action == 'edit') {
                            await editScheduled(p);
                          } else if (await confirm(
                            context,
                            'Plan silinsin mi?',
                            'Geçmiş kayıtlar korunur.',
                          )) {
                            await widget.store.change(
                              () => widget.store.scheduledExpenses.removeWhere(
                                (e) => e.id == p.id,
                              ),
                            );
                          }
                        } else {
                          final p = widget.store.annualPlans.firstWhere(
                            (p) => p.id == item.id,
                          );
                          if (action == 'edit') {
                            await edit(p);
                          } else {
                            await delete(p);
                          }
                        }
                        if (mounted) setState(() {});
                      },
                      itemBuilder: (_) => [
                        if (!item.paid)
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Düzenle'),
                          ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Planı sil'),
                        ),
                      ],
                    ),
                ],
              ),
            if (!item.paid && rule != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () =>
                      editRecurringRule(context, widget.store, rule),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Düzenle'),
                ),
              ),
          ],
        ),
      ),
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
    text: widget.plan == null ? '' : moneyInput(widget.plan!.amount),
  );
  late String category =
      widget.plan?.category ??
      widget.store.expenseCategories.firstOrNull ??
      'Diğer';
  late DateTime due = widget.plan == null
      ? DateTime(DateTime.now().year, DateTime.now().month + 1, 1)
      : nextAnnualPlanDue(widget.plan!, DateTime.now());
  late DateTime? endDate = widget.plan?.endDate;
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
          inputFormatters: const [MoneyInputFormatter()],
          decoration: const InputDecoration(
            labelText: 'Tahmini tutar',
            suffixText: '₺',
          ),
          validator: (text) =>
              parseMoney(text ?? '') == null ? 'Geçerli bir tutar gir.' : null,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          isExpanded: true,
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
                if (endDate != null && endDate!.isBefore(chosen)) {
                  endDate = null;
                }
              });
            }
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            endDate == null
                ? 'Bitiş tarihi yok'
                : 'Bitiş: ${dateLabel(endDate!)}',
          ),
          subtitle: const Text('İsteğe bağlı'),
          trailing: endDate == null
              ? const Icon(Icons.chevron_right)
              : IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => endDate = null),
                ),
          onTap: () async {
            final chosen = await showDatePicker(
              context: context,
              initialDate: endDate ?? due,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (chosen != null) setState(() => endDate = chosen);
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
                  if (endDate != null && endDate!.isBefore(due)) {
                    setState(
                      () => error = 'Bitiş tarihi ilk vadeden önce olamaz.',
                    );
                    return;
                  }
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
                        endDate: endDate,
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
