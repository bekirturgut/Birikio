import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/store.dart';
import 'widgets.dart';
import 'palette.dart';

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
          date: date,
          category: category,
          note: note.text.trim(),
          rule: widget.entry?.rule,
        );
        if (widget.entry != null) {
          widget.store.entries[widget.store.entries.indexWhere(
                (x) => x.id == e.id,
              )] =
              e;
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
    final categories = widget.income
        ? ['Maaş', 'Serbest iş', 'Yatırım', 'Hediye', 'Diğer']
        : [
            'Alışveriş',
            'Yeme içme',
            'Ulaşım',
            'Ev & faturalar',
            'Sağlık',
            'Eğlence',
            'Eğitim',
            'Diğer',
          ];
    return Form(
      key: key,
      child: FormShell(
        title:
            '${widget.income ? 'Gelir' : 'Gider'} ${widget.entry == null ? 'ekle' : 'düzenle'}',
        subtitle: widget.entry?.rule != null
            ? 'Bu değişiklik yalnızca seçili kaydı etkiler. Gelecek tekrarları kayıt listesinden yönetebilirsin.'
            : 'Küçük kayıtlar, büyük bir farkındalık.',
        children: [
          TextFormField(
            controller: amount,
            autofocus: false,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
            initialValue: category,
            decoration: const InputDecoration(labelText: 'Kategori'),
            items: categories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => category = v!),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today_rounded, size: 20),
            title: Text(dateLabel(date)),
            subtitle: const Text('Kayıt / başlangıç tarihi'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2000),
                lastDate: widget.entry == null && frequency != 0
                    ? DateTime(2100)
                    : DateTime.now(),
              );
              if (d != null) setState(() => date = d);
            },
          ),
          if (widget.entry == null) ...[
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
                if (frequency == 0 && date.isAfter(DateTime.now())) {
                  date = day(DateTime.now());
                }
              }),
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
  late String icon = widget.goal?.icon ?? 'Motor';
  bool saving = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: key,
    child: FormShell(
      title: widget.goal == null ? 'Bir hayalle başla.' : 'Hedefini düzenle',
      subtitle: 'Bir isim, bir simge ve seni heyecanlandıran bir hedef.',
      children: [
        GoalScene(
          icon: icon,
          motion:
              widget.store.motion && !MediaQuery.disableAnimationsOf(context),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: goalIcons.entries
              .map(
                (e) => ChoiceChip(
                  selected: icon == e.key,
                  avatar: e.key == 'Motor'
                      ? const RacingMotor(width: 24)
                      : Icon(e.value, size: 18),
                  label: Text(e.key),
                  onSelected: (_) => setState(() => icon = e.key),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 24),
        TextFormField(
          controller: name,
          maxLength: 40,
          decoration: const InputDecoration(
            labelText: 'Hedef adı',
            helperText: 'İsteğe bağlı · boş bırakırsan simge adı kullanılır',
            hintText: 'Örn. İlk motorum',
          ),
        ),
        TextFormField(
          controller: amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Hedef tutar',
            suffixText: '₺',
          ),
          validator: (v) =>
              parseMoney(v ?? '') == null ? 'Geçerli bir tutar gir.' : null,
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
