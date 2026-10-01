import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/store.dart';
import 'widgets.dart';
import 'palette.dart';
import 'money_input.dart';

Future<T?> sheet<T>(BuildContext context, Widget child) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : const AnimationStyle(
              duration: Duration(milliseconds: 560),
              reverseDuration: Duration(milliseconds: 360),
            ),
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (_) => child,
    );
Future<bool> confirm(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: coral,
              foregroundColor: ink,
            ),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    ) ??
    false;

class FormShell extends StatelessWidget {
  final String title, subtitle;
  final List<Widget> children;
  const FormShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
  });
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(
      24,
      8,
      24,
      MediaQuery.viewInsetsOf(context).bottom + 32,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -.7,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        ...children,
      ],
    ),
  );
}

class EntryForm extends StatefulWidget {
  final FinanceStore store;
  final bool income;
  final Entry? entry;
  const EntryForm({
    super.key,
    required this.store,
    required this.income,
    this.entry,
  });
  @override
  State<EntryForm> createState() => _EntryFormState();
}

class _EntryFormState extends State<EntryForm> {
  final key = GlobalKey<FormState>();
  late final title = TextEditingController(text: widget.entry?.title);
  late final amount = TextEditingController(
    text: widget.entry == null
        ? ''
        : (widget.entry!.amount / 100).toStringAsFixed(2).replaceAll('.', ','),
  );
  late final note = TextEditingController(text: widget.entry?.note);
  late DateTime date = widget.entry?.date ?? day(DateTime.now());
  late String category =
      widget.entry?.category ?? (widget.income ? 'Maaş' : 'Alışveriş');
  int frequency = 0;
  bool isBill = false;
  bool automaticPayment = true;
  DateTime? endDate;
  bool saving = false;
  String? error;
  @override
  void dispose() {
    title.dispose();
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!key.currentState!.validate()) return;
    var scope = 0;
    if (widget.entry?.rule != null) {
      final selected = await showDialog<int>(
        context: context,
        builder: (dialogContext) => SimpleDialog(
          title: const Text('Hangi kayıtlar değişsin?'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, 0),
              child: const Text('Yalnızca bu kayıt'),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, 1),
              child: const Text('Bu ve sonraki kayıtlar'),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, 2),
              child: const Text('Tüm seri'),
            ),
          ],
        ),
      );
      if (selected == null || !mounted) return;
      scope = selected;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.store.change(() {
        final e = Entry(
          id: widget.entry?.id ?? uid(),
          title: title.text.trim().isEmpty
              ? (widget.income ? 'Gelir' : 'Gider')
              : title.text.trim(),
          amount: parseMoney(amount.text)!,
          income: widget.income,
          date: scope == 0 ? date : widget.entry!.date,
          category: category,
          note: note.text.trim(),
          rule: widget.entry?.rule,
        );
        if (widget.entry != null) {
          widget.store.updateRecurringEntry(widget.entry!, e, scope);
        } else if (frequency == 0 && date.isAfter(day(DateTime.now()))) {
          widget.store.scheduledExpenses.add(
            ScheduledExpense(
              id: uid(),
              title: e.title,
              amount: e.amount,
              category: e.category,
              due: date,
              note: e.note,
              income: widget.income,
            ),
          );
        } else if (frequency == 0) {
          widget.store.entries.add(e);
        } else {
          widget.store.rules.add(
            RepeatRule(
              id: uid(),
              title: e.title,
              amount: e.amount,
              income: e.income,
              start: date,
              category: category,
              frequency: frequency,
              note: e.note,
              isBill: isBill,
              automaticPayment: automaticPayment,
              endDate: endDate,
            ),
          );
          widget.store.materialize(DateTime.now());
        }
      });
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          error = 'Kaydedilemedi. Lütfen tekrar dene.';
          saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = {
      ...widget.store.categoriesFor(widget.income),
      category,
    }.toList();
    return Form(
      key: key,
      child: FormShell(
        title:
            '${widget.income ? 'Gelir' : 'Gider'} ${widget.entry == null ? 'ekle' : 'düzenle'}',
        subtitle: widget.entry?.rule != null
            ? 'Kaydederken değişikliğin hangi dönemleri etkileyeceğini seçebilirsin. Tekrarın tarih ve sıklığı değişmez.'
            : 'Küçük kayıtlar, büyük bir farkındalık.',
        children: [
          TextFormField(
            controller: amount,
            autofocus: false,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: const [MoneyInputFormatter()],
            decoration: const InputDecoration(
              labelText: 'Tutar',
              suffixText: '₺',
              hintText: '0,00',
            ),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
            validator: (s) => parseMoney(s ?? '') == null
                ? 'Geçerli bir tutar gir (ör. 1.250,50).'
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: title,
            maxLength: 60,
            decoration: InputDecoration(
              labelText: widget.income ? 'Gelir kaynağı' : 'Gider adı',
              helperText: 'İsteğe bağlı',
              hintText: widget.income
                  ? 'Örn. Aylık maaş'
                  : 'Örn. Market alışverişi',
            ),
          ),
          DropdownButtonFormField<String>(
            key: ValueKey(category),
            initialValue: category,
            decoration: const InputDecoration(labelText: 'Kategori'),
            items: categories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => category = v!),
          ),
          TextButton.icon(
            onPressed: () async {
              var categoryName = '';
              final name = await showDialog<String>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Yeni kategori'),
                  content: TextField(
                    onChanged: (value) => categoryName = value,
                    maxLength: 40,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Kategori adı',
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Vazgeç'),
                    ),
                    FilledButton(
                      onPressed: () =>
                          Navigator.pop(dialogContext, categoryName),
                      child: const Text('Ekle'),
                    ),
                  ],
                ),
              );
              if (name == null || !mounted) return;
              try {
                await widget.store.change(
                  () => widget.store.addCategory(widget.income, name),
                );
                setState(() => category = name.trim());
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text('Kategori eklenemedi. Adı kontrol et.'),
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Yeni kategori ekle'),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today_rounded, size: 20),
            title: Text(dateLabel(date)),
            subtitle: const Text('Kayıt / başlangıç tarihi'),
            trailing: const Icon(Icons.chevron_right),
            onTap: widget.entry?.rule != null
                ? null
                : () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime(2000),
                      lastDate: widget.entry == null
                          ? DateTime(2100)
                          : DateTime.now(),
                    );
                    if (d != null) {
                      setState(() {
                        date = d;
                        if (endDate != null && endDate!.isBefore(d)) {
                          endDate = null;
                        }
                      });
                    }
                  },
          ),
          if (widget.entry == null) ...[
            if (!widget.income)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Düzenli ödeme'),
                subtitle: const Text('Ödeme tarihlerini takip et'),
                value: isBill,
                onChanged: (value) => setState(() {
                  isBill = value;
                  if (isBill && frequency == 0) frequency = 3;
                }),
              ),
            if (isBill)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Otomatik ödeniyor'),
                subtitle: const Text(
                  'Vadede otomatik gider kaydı oluşturulur; banka ödemesi doğrulanmaz.',
                ),
                value: automaticPayment,
                onChanged: (value) => setState(() => automaticPayment = value),
              ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: frequency,
              decoration: const InputDecoration(labelText: 'Tekrarlama'),
              items: List.generate(
                frequencies.length,
                (i) => DropdownMenuItem(value: i, child: Text(frequencies[i])),
              ),
              onChanged: (v) => setState(() {
                frequency = v!;
                if (isBill && frequency == 0) isBill = false;
              }),
            ),
            if (frequency > 0)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_busy_outlined),
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
                    initialDate: endDate ?? date,
                    firstDate: date,
                    lastDate: DateTime(2100),
                  );
                  if (chosen != null) setState(() => endDate = chosen);
                },
              ),
            if (frequency > 0)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Başlangıç tarihi dahil tekrarlanır. Uygulama kapalıyken geçen kayıtlar açılışta tamamlanır.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
          const SizedBox(height: 16),
          TextFormField(
            controller: note,
            maxLength: 240,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Not',
              hintText: 'Hatırlamak istediğin bir şey… (isteğe bağlı)',
            ),
          ),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: financeColors(context).negative),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: saving ? null : save,
            child: Text(saving ? 'Kaydediliyor…' : 'Kaydet'),
          ),
        ],
      ),
    );
  }
}

class GoalForm extends StatefulWidget {
  final FinanceStore store;
  final Goal? goal;
  const GoalForm({super.key, required this.store, this.goal});
  @override
  State<GoalForm> createState() => _GoalFormState();
}

class _GoalFormState extends State<GoalForm> {
  final key = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.goal?.title);
  late final amount = TextEditingController(
    text: widget.goal == null
        ? ''
        : (widget.goal!.target / 100).toStringAsFixed(2).replaceAll('.', ','),
  );
  late String icon = widget.goal?.icon ?? 'Birikim';
  late DateTime? targetDate = widget.goal?.targetDate;
  late final monthly = TextEditingController(
    text: widget.goal?.monthlyContribution == null
        ? ''
        : (widget.goal!.monthlyContribution! / 100)
              .toStringAsFixed(2)
              .replaceAll('.', ','),
  );
  late int? monthlyDueDay = widget.goal?.monthlyDueDay;
  bool saving = false;
  String? error;

  Future<void> chooseIcon() async {
    final choice = await sheet<String>(
      context,
      FractionallySizedBox(
        heightFactor: .78,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Birikim kategorisi',
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 5),
              Text(
                'Hayaline uygun olanı seç; görseli hedefinle birlikte canlansın.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: GridView.builder(
                  itemCount: goalIcons.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.05,
                  ),
                  itemBuilder: (sheetContext, index) {
                    final entry = goalIcons.entries.elementAt(index);
                    final selected = icon == entry.key;
                    final colors = financeColors(sheetContext);
                    return Material(
                      color: selected
                          ? colors.accent.withValues(alpha: .2)
                          : Theme.of(sheetContext).colorScheme.surfaceContainer,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: colors.accent.withValues(
                            alpha: selected ? .75 : .13,
                          ),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => Navigator.pop(sheetContext, entry.key),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(entry.value, size: 31, color: colors.accent),
                            const SizedBox(height: 8),
                            Text(
                              entry.key,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.goalText,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice != null && mounted) setState(() => icon = choice);
  }

  @override
  void dispose() {
    name.dispose();
    amount.dispose();
    monthly.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: key,
    child: FormShell(
      title: widget.goal == null ? 'Bir hayalle başla.' : 'Hedefini düzenle',
      subtitle: 'Bir isim, bir kategori ve seni heyecanlandıran bir hedef.',
      children: [
        GoalScene(
          icon: icon,
          motion:
              widget.store.motion && !MediaQuery.disableAnimationsOf(context),
        ),
        Material(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: chooseIcon,
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: financeColors(
                        context,
                      ).accent.withValues(alpha: .16),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      goalIcons[icon] ?? Icons.auto_awesome_rounded,
                      color: financeColors(context).accent,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          icon,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'Kategoriyi değiştir · ${goalIcons.length} seçenek',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 17),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        TextFormField(
          controller: name,
          maxLength: 40,
          decoration: const InputDecoration(
            labelText: 'Hedef adı',
            helperText: 'İsteğe bağlı · boş bırakırsan kategori adı kullanılır',
            hintText: 'Örn. İlk motorum',
          ),
        ),
        TextFormField(
          controller: amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: const [MoneyInputFormatter()],
          decoration: const InputDecoration(
            labelText: 'Hedef tutar',
            suffixText: '₺',
          ),
          validator: (v) =>
              parseMoney(v ?? '') == null ? 'Geçerli bir tutar gir.' : null,
        ),
        const SizedBox(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event_rounded),
          title: Text(
            targetDate == null ? 'Hedef tarihi ekle' : dateLabel(targetDate!),
          ),
          subtitle: const Text('İsteğe bağlı'),
          trailing: targetDate == null
              ? const Icon(Icons.chevron_right_rounded)
              : IconButton(
                  tooltip: 'Hedef tarihini kaldır',
                  onPressed: () => setState(() => targetDate = null),
                  icon: const Icon(Icons.close_rounded),
                ),
          onTap: () async {
            final now = day(DateTime.now());
            final date = await showDatePicker(
              context: context,
              initialDate: targetDate != null && targetDate!.isAfter(now)
                  ? targetDate!
                  : DateTime(now.year, now.month + 1, now.day),
              firstDate: now,
              lastDate: DateTime(now.year + 50),
            );
            if (date != null) setState(() => targetDate = date);
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: monthly,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: const [MoneyInputFormatter()],
          decoration: const InputDecoration(
            labelText: 'Planlanan aylık birikim',
            helperText: 'Tahmini bitiş ve aylık takip için kullanılır',
            suffixText: '₺',
          ),
          validator: (value) =>
              value == null || value.trim().isEmpty || parseMoney(value) != null
              ? null
              : 'Geçerli bir tutar gir.',
        ),
        const SizedBox(height: 12),
        FormField<int>(
          initialValue: monthlyDueDay,
          validator: (_) => monthlyDueDay != null && monthly.text.trim().isEmpty
              ? 'Önce aylık birikim tutarını gir.'
              : null,
          builder: (field) {
            final now = DateTime.now();
            final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
            final colors = financeColors(context);
            final scheme = Theme.of(context).colorScheme;
            final effectiveDay = monthlyDueDay?.clamp(1, daysInMonth);
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: colors.goalBackground),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: colors.accent.withValues(alpha: .22)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ayın kaçıncı günü?',
                    style: TextStyle(
                      color: colors.goalText,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Bu ay $daysInMonth gün · kısa aylarda son gün geçerlidir',
                    style: TextStyle(color: colors.goalMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      field.didChange(null);
                      setState(() => monthlyDueDay = null);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: monthlyDueDay == null
                            ? colors.accent.withValues(alpha: .2)
                            : scheme.surface.withValues(alpha: .45),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: monthlyDueDay == null
                              ? colors.accent.withValues(alpha: .65)
                              : colors.accent.withValues(alpha: .12),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            monthlyDueDay == null
                                ? Icons.check_circle_rounded
                                : Icons.event_busy_rounded,
                            size: 18,
                            color: colors.accent,
                          ),
                          const SizedBox(width: 9),
                          Text(
                            'Gün sınırı yok',
                            style: TextStyle(
                              color: colors.goalText,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 6,
                          crossAxisSpacing: 6,
                          childAspectRatio: 1,
                        ),
                    itemCount: daysInMonth,
                    itemBuilder: (context, index) {
                      final dayNumber = index + 1;
                      final selected = effectiveDay == dayNumber;
                      return Semantics(
                        label: 'Ayın $dayNumber. günü',
                        selected: selected,
                        button: true,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            field.didChange(dayNumber);
                            setState(() => monthlyDueDay = dayNumber);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: selected
                                  ? colors.accent
                                  : scheme.surface.withValues(alpha: .55),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected
                                    ? colors.accent
                                    : colors.accent.withValues(alpha: .13),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$dayNumber',
                              style: TextStyle(
                                color: selected
                                    ? colors.onAccent
                                    : colors.goalText,
                                fontWeight: selected
                                    ? FontWeight.w900
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  if (monthlyDueDay != null &&
                      monthlyDueDay! > daysInMonth) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Kayıtlı ${monthlyDueDay!}. gün bu ayın son günü olan $daysInMonth olarak uygulanır.',
                      style: TextStyle(color: colors.goalMuted, fontSize: 12),
                    ),
                  ],
                  if (field.hasError) ...[
                    const SizedBox(height: 10),
                    Text(
                      field.errorText!,
                      style: TextStyle(color: scheme.error, fontSize: 12),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: financeColors(context).negative),
          ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: saving
              ? null
              : () async {
                  if (!key.currentState!.validate()) return;
                  setState(() => saving = true);
                  try {
                    await widget.store.change(() {
                      final g = Goal(
                        id: widget.goal?.id ?? uid(),
                        title: name.text.trim().isEmpty
                            ? '$icon hedefim'
                            : name.text.trim(),
                        icon: icon,
                        target: parseMoney(amount.text)!,
                        targetDate: targetDate,
                        monthlyContribution: monthly.text.trim().isEmpty
                            ? null
                            : parseMoney(monthly.text),
                        monthlyDueDay: monthly.text.trim().isEmpty
                            ? null
                            : monthlyDueDay,
                        monthlyPlanStart:
                            monthly.text.trim().isEmpty || monthlyDueDay == null
                            ? null
                            : widget.goal?.monthlyDueDay == monthlyDueDay &&
                                  widget.goal?.monthlyContribution ==
                                      parseMoney(monthly.text)
                            ? widget.goal?.monthlyPlanStart ??
                                  day(DateTime.now())
                            : day(DateTime.now()),
                      );
                      if (widget.goal == null) {
                        widget.store.goals.add(g);
                        widget.store.pinned ??= g.id;
                      } else {
                        widget.store.goals[widget.store.goals.indexWhere(
                              (x) => x.id == g.id,
                            )] =
                            g;
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
          child: Text(
            saving
                ? 'Kaydediliyor…'
                : widget.goal == null
                ? 'Hedefimi oluştur'
                : 'Değişiklikleri kaydet',
          ),
        ),
      ],
    ),
  );
}

class TransferForm extends StatefulWidget {
  final FinanceStore store;
  final Goal goal;
  final bool adding;
  const TransferForm({
    super.key,
    required this.store,
    required this.goal,
    required this.adding,
  });
  @override
  State<TransferForm> createState() => _TransferFormState();
}

class _TransferFormState extends State<TransferForm> {
  final amount = TextEditingController();
  String? error;
  bool busy = false;
  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FormShell(
    title: widget.adding ? 'Hayaline bir adım daha.' : 'Birikimden para çek',
    subtitle:
        '${widget.goal.title}\n${widget.adding ? 'Kullanılabilir bakiye' : 'Birikimdeki tutar'}: ${money(widget.adding ? widget.store.balance : widget.store.saved(widget.goal))}',
    children: [
      TextField(
        controller: amount,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: const [MoneyInputFormatter()],
        decoration: InputDecoration(
          labelText: 'Tutar',
          suffixText: '₺',
          errorText: error,
        ),
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 16),
      Text(
        widget.adding
            ? 'Bu tutar bakiyenden birikimine aktarılır. Gider olarak sayılmaz.'
            : 'Çektiğin tutar kullanılabilir bakiyene geri döner. Gelir olarak sayılmaz.',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          height: 1.5,
        ),
      ),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: busy
            ? null
            : () async {
                final value = parseMoney(amount.text);
                if (value == null) {
                  setState(() => error = 'Geçerli bir tutar gir.');
                  return;
                }
                if (value >
                    (widget.adding
                        ? widget.store.balance
                        : widget.store.saved(widget.goal))) {
                  setState(() => error = 'Yeterli bakiye yok.');
                  return;
                }
                setState(() => busy = true);
                try {
                  await widget.store.move(
                    widget.goal,
                    widget.adding ? value : -value,
                  );
                  HapticFeedback.heavyImpact();
                  if (context.mounted) Navigator.pop(context, true);
                } catch (_) {
                  if (mounted) {
                    setState(() {
                      busy = false;
                      error = 'İşlem kaydedilemedi.';
                    });
                  }
                }
              },
        child: Text(
          busy
              ? 'Kaydediliyor…'
              : widget.adding
              ? 'Birikime aktar'
              : 'Bakiyeme geri al',
        ),
      ),
    ],
  );
}
