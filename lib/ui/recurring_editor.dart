import 'package:flutter/material.dart';
import '../data/store.dart';
import 'forms.dart';
import 'palette.dart';
import 'money_input.dart';

Future<void> toggleRecurringRule(
  BuildContext context,
  FinanceStore store,
  RepeatRule rule,
) async {
  if (rule.active) {
    await store.change(() => rule.active = false);
    return;
  }
  final catchUp = await showDialog<bool>(
    context: context,
    builder: (c) => SimpleDialog(
      title: const Text('Seri nasıl devam etsin?'),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Bugünden devam et · duraklanan vadeleri atla'),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(c, true),
          child: Text(
            rule.isBill && !rule.automaticPayment
                ? 'Geçmiş bekleyen vadeleri de göster'
                : 'Eksik vadeleri tamamla · geçmişi de işle',
          ),
        ),
      ],
    ),
  );
  if (catchUp != null) {
    await store.change(() => store.resumeRule(rule, catchUpMissed: catchUp));
  }
}

Future<void> editRecurringRule(
  BuildContext context,
  FinanceStore store,
  RepeatRule rule,
) async {
  var title = rule.title;
  var amount = moneyInput(rule.amount);
  var category = rule.category;
  var note = rule.note;
  var frequency = rule.frequency;
  var automatic = rule.isBill ? rule.automaticPayment : true;
  var scheduleChanged = false;
  final today = day(DateTime.now());
  var nextStart = rule.occurrence(
    rule.isBill && !rule.automaticPayment
        ? store.firstUnpaidBillPeriod(rule)
        : rule.cursor,
  );
  if (nextStart.isBefore(today)) nextStart = today;
  DateTime? endDate = rule.endDate;
  final firstFuturePeriod = rule.isBill && !rule.automaticPayment
      ? store.firstUnpaidBillPeriod(rule)
      : rule.cursor;
  final applicableDueChanges =
      rule.dueDayChanges.keys
          .where((period) => period <= firstFuturePeriod)
          .toList()
        ..sort();
  var dueDay =
      (applicableDueChanges.isEmpty
              ? rule.start.day
              : rule.dueDayChanges[applicableDueChanges.last]!)
          .toString();
  var error = '';
  await sheet(
    context,
    StatefulBuilder(
      builder: (dialogContext, update) => FormShell(
        title: rule.income
            ? 'Düzenli geliri düzenle'
            : 'Düzenli ödemeyi düzenle',
        subtitle:
            'Geçmiş işlemler korunur. Sıklık, başlangıç veya ödeme türü değişirse gelecek seri yeni takvimle oluşturulur; eski gecikmiş manuel ödemeler korunur.',
        children: [
          TextFormField(
            initialValue: title,
            decoration: const InputDecoration(labelText: 'Ad'),
            onChanged: (value) => title = value,
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: const [MoneyInputFormatter()],
            decoration: const InputDecoration(
              labelText: 'Tutar',
              suffixText: '₺',
            ),
            onChanged: (value) => amount = value,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: category,
            decoration: const InputDecoration(labelText: 'Kategori'),
            items:
                {
                      category,
                      ...(rule.income
                          ? store.incomeCategories
                          : store.expenseCategories),
                    }
                    .map(
                      (name) =>
                          DropdownMenuItem(value: name, child: Text(name)),
                    )
                    .toList(),
            onChanged: (value) {
              if (value != null) category = value;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: note,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Not (isteğe bağlı)'),
            onChanged: (value) => note = value,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: frequency,
            decoration: const InputDecoration(labelText: 'Tekrarlama'),
            items: [
              for (var i = 1; i < frequencies.length; i++)
                DropdownMenuItem(value: i, child: Text(frequencies[i])),
            ],
            onChanged: (value) => update(() {
              frequency = value!;
              scheduleChanged = true;
            }),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Sonraki başlangıç: ${dateLabel(nextStart)}'),
            subtitle: const Text(
              'Takvim değişikliğinde yeni serinin ilk tarihi',
            ),
            trailing: const Icon(Icons.calendar_month_outlined),
            onTap: () async {
              final chosen = await showDatePicker(
                context: dialogContext,
                initialDate: nextStart,
                firstDate: today,
                lastDate: DateTime(2100),
              );
              if (chosen != null) {
                update(() {
                  nextStart = chosen;
                  dueDay = '${chosen.day}';
                  scheduleChanged = true;
                });
              }
            },
          ),
          if (!rule.income)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Otomatik gider kaydı'),
              subtitle: const Text('Kapalıysa ödeme manuel işaretlenir.'),
              value: automatic,
              onChanged: (value) => update(() {
                automatic = value;
                scheduleChanged = true;
              }),
            ),
          if (frequency == 3 || frequency == 4) ...[
            const SizedBox(height: 12),
            TextFormField(
              initialValue: dueDay,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Vade günü (1–31)',
                helperText: 'Kısa aylarda son güne uyarlanır.',
              ),
              onChanged: (value) => dueDay = value,
            ),
          ],
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              endDate == null
                  ? 'Bitiş tarihi yok'
                  : 'Bitiş: ${dateLabel(endDate!)}',
            ),
            subtitle: const Text('İsteğe bağlı'),
            onTap: () async {
              final chosen = await showDatePicker(
                context: dialogContext,
                initialDate: endDate ?? rule.start,
                firstDate: rule.start,
                lastDate: DateTime(2100),
              );
              if (chosen != null) update(() => endDate = chosen);
            },
            trailing: endDate == null
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => update(() => endDate = null),
                  ),
          ),
          if (error.isNotEmpty)
            Text(
              error,
              style: TextStyle(color: financeColors(context).negative),
            ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () async {
              final cents = parseMoney(amount);
              final parsedDay = int.tryParse(dueDay);
              if (title.trim().isEmpty ||
                  cents == null ||
                  parsedDay == null ||
                  parsedDay < 1 ||
                  parsedDay > 31) {
                update(() => error = 'Ad, tutar ve vade gününü kontrol et.');
                return;
              }
              final revisedStart = frequency == 3 || frequency == 4
                  ? DateTime(
                      nextStart.year,
                      nextStart.month,
                      parsedDay.clamp(
                        1,
                        DateTime(nextStart.year, nextStart.month + 1, 0).day,
                      ),
                    )
                  : nextStart;
              if (scheduleChanged &&
                  (revisedStart.isBefore(today) ||
                      (endDate != null && endDate!.isBefore(revisedStart)))) {
                update(
                  () => error = 'Bitiş tarihi yeni başlangıçtan önce olamaz.',
                );
                return;
              }
              try {
                await store.change(() {
                  final target = scheduleChanged
                      ? store.replaceRuleSchedule(
                          rule,
                          start: revisedStart,
                          frequency: frequency,
                          automaticPayment: automatic,
                          endDate: endDate,
                        )
                      : rule;
                  target.title = title.trim();
                  target.amount = cents;
                  target.category = category;
                  target.note = note.trim();
                  target.endDate = endDate;
                  if (scheduleChanged) {
                    if (frequency == 3 || frequency == 4) {
                      target.dueDayChanges[0] = parsedDay;
                    }
                  } else if (frequency == 3 || frequency == 4) {
                    rule.dueDayChanges[firstFuturePeriod] = parsedDay;
                  }
                  store.materialize(DateTime.now());
                });
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              } catch (_) {
                update(() => error = 'Kaydedilemedi.');
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    ),
  );
}
