import 'dart:convert';

import 'finance_document.dart';
import 'store.dart';

const backupFormat = 'birikio-backup';

String createBackup(
  FinanceStore store, {
  DateTime? createdAt,
  String? appVersion,
}) {
  final timestamp = (createdAt ?? DateTime.now()).toUtc().toIso8601String();
  return const JsonEncoder.withIndent('  ').convert({
    'format': backupFormat,
    'schemaVersion': financeSchemaVersion,
    'createdAt': timestamp,
    if (appVersion case final String version) 'appVersion': version,
    'data': {...store.json(), 'lastBackupAt': timestamp},
  });
}

Map<String, dynamic> parseBackup(String raw) {
  final root = jsonDecode(raw);
  if (root is! Map<String, dynamic> || root['format'] != backupFormat) {
    throw const FormatException('Bu dosya Birikio yedeği değil.');
  }
  final version = root['schemaVersion'];
  if (version is! int ||
      version < 0 ||
      version > financeSchemaVersion ||
      DateTime.tryParse(root['createdAt']?.toString() ?? '') == null) {
    throw const FormatException('Yedek sürümü veya tarihi geçersiz.');
  }
  final data = root['data'];
  if (data is! Map<String, dynamic>) {
    throw const FormatException('Yedek verisi eksik.');
  }
  final migrated = migrateFinanceDocument(data);
  if (data['schemaVersion'] != null && data['schemaVersion'] != version) {
    throw const FormatException('Yedek sürümleri uyuşmuyor.');
  }
  void uniqueIds(String key) {
    final records = migrated[key];
    if (records is! List) throw FormatException('$key listesi eksik.');
    final ids = <String>{};
    for (final record in records) {
      if (record is! Map ||
          record['id'] is! String ||
          (record['id'] as String).isEmpty ||
          !ids.add(record['id'])) {
        throw FormatException('$key içinde geçersiz veya yinelenen kimlik.');
      }
    }
  }

  for (final key in [
    'entries',
    'rules',
    'goals',
    'transfers',
    'annualPlans',
    'scheduledExpenses',
  ]) {
    uniqueIds(key);
  }
  for (final item in migrated['entries'] as List) {
    if (item['amount'] is! int ||
        item['amount'] <= 0 ||
        item['income'] is! bool ||
        DateTime.tryParse(item['date']?.toString() ?? '') == null) {
      throw const FormatException('Geçersiz işlem tutarı, türü veya tarihi.');
    }
  }
  for (final item in migrated['rules'] as List) {
    if (item['amount'] is! int ||
        item['amount'] <= 0 ||
        item['frequency'] is! int ||
        item['frequency'] < 1 ||
        item['frequency'] > 4 ||
        item['cursor'] is! int ||
        item['cursor'] < 0 ||
        DateTime.tryParse(item['start']?.toString() ?? '') == null) {
      throw const FormatException('Geçersiz tekrar kuralı.');
    }
    final end = item['endDate'];
    if (end != null &&
        (DateTime.tryParse(end.toString()) == null ||
            DateTime.parse(
              end.toString(),
            ).isBefore(DateTime.parse(item['start'])))) {
      throw const FormatException('Geçersiz bitiş tarihi.');
    }
  }
  for (final item in migrated['scheduledExpenses'] as List) {
    if (item['title'] is! String ||
        item['category'] is! String ||
        item['amount'] is! int ||
        item['amount'] <= 0 ||
        DateTime.tryParse(item['due']?.toString() ?? '') == null ||
        (item['paidAt'] != null &&
            DateTime.tryParse(item['paidAt'].toString()) == null)) {
      throw const FormatException('Geçersiz ileri tarihli gider.');
    }
  }
  for (final item in migrated['goals'] as List) {
    if (item['target'] is! int || item['target'] <= 0) {
      throw const FormatException('Geçersiz hedef tutarı.');
    }
    final amount = item['monthlyContribution'];
    final dueDay = item['monthlyDueDay'];
    final planStart = item['monthlyPlanStart'];
    if ((amount != null && (amount is! int || amount <= 0)) ||
        (dueDay != null &&
            (dueDay is! int || dueDay < 1 || dueDay > 31 || amount == null)) ||
        (planStart != null &&
            DateTime.tryParse(planStart.toString()) == null) ||
        ((dueDay == null) != (planStart == null))) {
      throw const FormatException('Geçersiz aylık birikim planı.');
    }
  }
  for (final item in migrated['transfers'] as List) {
    if (item['amount'] is! int ||
        item['amount'] == 0 ||
        DateTime.tryParse(item['date']?.toString() ?? '') == null) {
      throw const FormatException('Geçersiz birikim aktarımı.');
    }
  }
  for (final item in migrated['annualPlans'] as List) {
    if (item['title'] is! String ||
        (item['title'] as String).trim().isEmpty ||
        item['category'] is! String ||
        (item['category'] as String).trim().isEmpty ||
        item['amount'] is! int ||
        item['amount'] <= 0 ||
        item['month'] is! int ||
        item['month'] < 1 ||
        item['month'] > 12 ||
        item['dueDay'] is! int ||
        item['dueDay'] < 1 ||
        item['dueDay'] > 31 ||
        item['startYear'] is! int ||
        item['startYear'] < 2000 ||
        item['startYear'] > 9999) {
      throw const FormatException('Geçersiz yıllık masraf planı.');
    }
    final end = item['endDate'];
    if (end != null &&
        (DateTime.tryParse(end.toString()) == null ||
            DateTime.parse(
              end.toString(),
            ).isBefore(DateTime(item['startYear'], item['month'], 1)))) {
      throw const FormatException('Geçersiz yıllık plan bitiş tarihi.');
    }
  }
  final budgets = migrated['budgets'];
  if (budgets is! Map || budgets.values.any((v) => v is! int || v <= 0)) {
    throw const FormatException('Geçersiz genel bütçe.');
  }
  final categoryBudgets = migrated['categoryBudgets'];
  if (categoryBudgets is! Map ||
      categoryBudgets.values.any(
        (monthly) =>
            monthly is! Map || monthly.values.any((v) => v is! int || v <= 0),
      )) {
    throw const FormatException('Geçersiz kategori bütçesi.');
  }
  if (migrated['lastBackupAt'] != null &&
      DateTime.tryParse(migrated['lastBackupAt'].toString()) == null) {
    throw const FormatException('Geçersiz yedek zamanı.');
  }
  return migrated;
}

Future<void> restoreBackup(FinanceStore store, String raw) async {
  final data = parseBackup(raw);
  final candidate = FinanceStore(read: () async => null, write: (_) async {});
  candidate.restore(data);
  await store.change(() {
    store.restore(data);
    store.lastBackupAt ??= DateTime.parse(
      (jsonDecode(raw) as Map)['createdAt'],
    );
  });
}

String createCsv(FinanceStore store) {
  String cell(String text) => '"${text.replaceAll('"', '""')}"';
  final lines = <String>['Tarih;Tür;Tutar (TL);Kategori;Başlık;Not'];
  for (final entry in store.sorted) {
    final amount = (entry.amount / 100).toStringAsFixed(2).replaceAll('.', ',');
    lines.add(
      [
        '${entry.date.year.toString().padLeft(4, '0')}-${entry.date.month.toString().padLeft(2, '0')}-${entry.date.day.toString().padLeft(2, '0')}',
        entry.income ? 'Gelir' : 'Gider',
        amount,
        cell(entry.category),
        cell(entry.title),
        cell(entry.note),
      ].join(';'),
    );
  }
  return '\uFEFF${lines.join('\r\n')}\r\n';
}
