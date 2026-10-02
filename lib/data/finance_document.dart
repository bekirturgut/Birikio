import 'dart:convert';

/// Disk format version. The original, unversioned document is version 0.
const financeSchemaVersion = 14;

Map<String, dynamic> decodeFinanceDocument(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Finans verisi bir JSON nesnesi olmalı.');
  }
  return migrateFinanceDocument(decoded);
}

Map<String, dynamic> migrateFinanceDocument(Map<String, dynamic> document) {
  final version = document['schemaVersion'] ?? 0;
  if (version is! int || version < 0 || version > financeSchemaVersion) {
    throw const FormatException('Desteklenmeyen finans verisi sürümü.');
  }
  final migrated = {...document};
  if (version < 2) {
    // Version 2 stores editable category lists. Older records keep their labels.
    migrated['incomeCategories'] ??= [
      'Maaş',
      'Serbest iş',
      'Yatırım',
      'Hediye',
      'Diğer',
    ];
    migrated['expenseCategories'] ??= [
      'Alışveriş',
      'Yeme içme',
      'Ulaşım',
      'Ev & faturalar',
      'Sağlık',
      'Eğlence',
      'Eğitim',
      'Diğer',
    ];
  }
  if (version < 3) migrated['categoryBudgets'] ??= <String, dynamic>{};
  if (version < 12) migrated['annualPlans'] ??= <dynamic>[];
  if (version < 13) migrated['scheduledExpenses'] ??= <dynamic>[];
  if (version < 14) migrated['sentPaymentAlerts'] ??= <String>[];
  migrated['schemaVersion'] = financeSchemaVersion;
  return migrated;
}
