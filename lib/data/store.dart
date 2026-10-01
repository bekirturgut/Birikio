import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'finance_document.dart';

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
const frequencies = ['Tek sefer', 'Günlük', 'Haftalık', 'Aylık', 'Yıllık'];
const defaultIncomeCategories = [
  'Maaş',
  'Serbest iş',
  'Yatırım',
  'Hediye',
  'Diğer',
];
const defaultExpenseCategories = [
  'Alışveriş',
  'Yeme içme',
  'Ulaşım',
  'Ev & faturalar',
  'Sağlık',
  'Eğlence',
  'Eğitim',
  'Diğer',
];
String uid() =>
    '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 32)}';
DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);
String dateLabel(DateTime d) => '${d.day} ${months[d.month - 1]} ${d.year}';
String money(int cents) {
  final parts = (cents.abs() / 100).toStringAsFixed(2).split('.');
  final grouped = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  return '${cents < 0 ? '−' : ''}$grouped,${parts[1]} ₺';
}

int? parseMoney(String input) {
  var s = input.trim().replaceAll('₺', '').replaceAll(' ', '');
  if (s.contains(',')) {
    s = s.replaceAll('.', '').replaceAll(',', '.');
  }
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(s)) return null;
  final v = double.tryParse(s);
  if (v == null || !v.isFinite || v <= 0 || v > 999999999) return null;
  return (v * 100).round();
}

class Entry {
  String id, title, category, note;
  int amount;
  bool income;
  DateTime date;
  String? rule;
  Entry({
    required this.id,
    required this.title,
    required this.amount,
    required this.income,
    required this.date,
    required this.category,
    this.note = '',
    this.rule,
  });
  Map<String, dynamic> json() => {
    'id': id,
    'title': title,
    'amount': amount,
    'income': income,
    'date': date.toIso8601String(),
    'category': category,
    'note': note,
    'rule': rule,
  };
  factory Entry.read(Map<String, dynamic> j) => Entry(
    id: j['id'],
    title: j['title'],
    amount: j['amount'],
    income: j['income'],
    date: DateTime.parse(j['date']),
    category: j['category'],
    note: j['note'],
    rule: j['rule'],
  );
}

class RepeatRule {
  String id, title, category, note;
  int amount, frequency, cursor;
  bool income, active;
  bool isBill, automaticPayment;
  Map<int, int> dueDayChanges;
  DateTime start;
  DateTime? endDate;
  RepeatRule({
    required this.id,
    required this.title,
    required this.amount,
    required this.income,
    required this.start,
    this.endDate,
    required this.category,
    required this.frequency,
    this.note = '',
    this.cursor = 0,
    this.active = true,
    this.isBill = false,
    this.automaticPayment = true,
    Map<int, int>? dueDayChanges,
  }) : dueDayChanges = dueDayChanges ?? {};
  DateTime occurrence(int index) {
    if (frequency == 1) {
      return DateTime(start.year, start.month, start.day + index);
    }
    if (frequency == 2) {
      return DateTime(start.year, start.month, start.day + 7 * index);
    }
    final base = DateTime(
      start.year + (frequency == 4 ? index : 0),
      start.month + (frequency == 3 ? index : 0),
    );
    final applicable =
        dueDayChanges.keys.where((period) => period <= index).toList()..sort();
    final dueDay = applicable.isEmpty
        ? start.day
        : dueDayChanges[applicable.last]!;
    return DateTime(
      base.year,
      base.month,
      min(dueDay, DateTime(base.year, base.month + 1, 0).day),
    );
  }

  Map<String, dynamic> json() => {
    'id': id,
    'title': title,
    'amount': amount,
    'income': income,
    'start': start.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'category': category,
    'frequency': frequency,
    'note': note,
    'cursor': cursor,
    'active': active,
    'isBill': isBill,
    'automaticPayment': automaticPayment,
    'dueDayChanges': dueDayChanges.map((key, value) => MapEntry('$key', value)),
  };
  factory RepeatRule.read(Map<String, dynamic> j) => RepeatRule(
    id: j['id'],
    title: j['title'],
    amount: j['amount'],
    income: j['income'],
    start: DateTime.parse(j['start']),
    endDate: j['endDate'] == null ? null : DateTime.parse(j['endDate']),
    category: j['category'],
    frequency: j['frequency'],
    note: j['note'],
    cursor: j['cursor'],
    active: j['active'],
    isBill: j['isBill'] as bool? ?? false,
    automaticPayment: j['automaticPayment'] as bool? ?? true,
    dueDayChanges: (j['dueDayChanges'] as Map? ?? {}).map(
      (key, value) => MapEntry(int.parse(key.toString()), value as int),
    ),
  );
}

class Goal {
  String id, title, icon;
  int target;
  DateTime? targetDate;
  int? monthlyContribution;
  int? monthlyDueDay;
  DateTime? monthlyPlanStart;
  Goal({
    required this.id,
    required this.title,
    required this.icon,
    required this.target,
    this.targetDate,
    this.monthlyContribution,
    this.monthlyDueDay,
    this.monthlyPlanStart,
  });
  Map<String, dynamic> json() => {
    'id': id,
    'title': title,
    'icon': icon,
    'target': target,
    'targetDate': targetDate?.toIso8601String(),
    'monthlyContribution': monthlyContribution,
    'monthlyDueDay': monthlyDueDay,
    'monthlyPlanStart': monthlyPlanStart?.toIso8601String(),
  };
  factory Goal.read(Map<String, dynamic> j) => Goal(
    id: j['id'],
    title: j['title'],
    icon: j['icon'],
    target: j['target'],
    targetDate: j['targetDate'] == null
        ? null
        : DateTime.parse(j['targetDate']),
    monthlyContribution: j['monthlyContribution'] as int?,
    monthlyDueDay: j['monthlyDueDay'] as int?,
    monthlyPlanStart: j['monthlyPlanStart'] == null
        ? null
        : DateTime.parse(j['monthlyPlanStart']),
  );
}

int monthsUntil(DateTime from, DateTime to) {
  if (!day(to).isAfter(day(from))) return 0;
  final difference = (to.year - from.year) * 12 + to.month - from.month;
  return difference + (to.day > from.day ? 1 : 0);
}

int? requiredMonthlySaving(Goal goal, int saved, DateTime now) {
  final date = goal.targetDate;
  if (date == null || saved >= goal.target) return null;
  final months = monthsUntil(now, date);
  if (months == 0) return null;
  return (goal.target - saved + months - 1) ~/ months;
}

DateTime? projectedGoalDate(Goal goal, int saved, DateTime now) {
  final monthly = goal.monthlyContribution;
  if (monthly == null || monthly <= 0 || saved >= goal.target) return null;
  final months = (goal.target - saved + monthly - 1) ~/ monthly;
  return DateTime(now.year, now.month + months, now.day);
}

class Transfer {
  String id, goal;
  int amount;
  DateTime date;
  Transfer({
    required this.id,
    required this.goal,
    required this.amount,
    required this.date,
  });
  Map<String, dynamic> json() => {
    'id': id,
    'goal': goal,
    'amount': amount,
    'date': date.toIso8601String(),
  };
  factory Transfer.read(Map<String, dynamic> j) => Transfer(
    id: j['id'],
    goal: j['goal'],
    amount: j['amount'],
    date: DateTime.parse(j['date']),
  );
}

class AnnualPlan {
  String id, title, category;
  int amount, month, dueDay, startYear;
  DateTime? endDate;
  AnnualPlan({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.month,
    required this.dueDay,
    required this.startYear,
    this.endDate,
  });
  DateTime dueIn(int year) =>
      DateTime(year, month, min(dueDay, DateTime(year, month + 1, 0).day));
  Map<String, dynamic> json() => {
    'id': id,
    'title': title,
    'category': category,
    'amount': amount,
    'month': month,
    'dueDay': dueDay,
    'startYear': startYear,
    'endDate': endDate?.toIso8601String(),
  };
  factory AnnualPlan.read(Map<String, dynamic> j) => AnnualPlan(
    id: j['id'],
    title: j['title'],
    category: j['category'],
    amount: j['amount'],
    month: j['month'],
    dueDay: j['dueDay'],
    startYear: j['startYear'],
    endDate: j['endDate'] == null ? null : DateTime.parse(j['endDate']),
  );
}

class ScheduledExpense {
  String id, title, category, note;
  int amount;
  DateTime due;
  DateTime? paidAt;
  ScheduledExpense({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.due,
    this.note = '',
    this.paidAt,
  });
  Map<String, dynamic> json() => {
    'id': id,
    'title': title,
    'category': category,
    'amount': amount,
    'due': due.toIso8601String(),
    'note': note,
    'paidAt': paidAt?.toIso8601String(),
  };
  factory ScheduledExpense.read(Map<String, dynamic> j) => ScheduledExpense(
    id: j['id'],
    title: j['title'],
    category: j['category'],
    amount: j['amount'],
    due: DateTime.parse(j['due']),
    note: j['note'] ?? '',
    paidAt: j['paidAt'] == null ? null : DateTime.parse(j['paidAt']),
  );
}

class FinanceStore extends ChangeNotifier {
  static const defaultDashboardSections = <String>[
    'goal',
    'summary',
    'activity',
    'overdue',
  ];
  static const availableDashboardSections = <String>[
    'goal',
    'summary',
    'balance',
    'cashflow',
    'activity',
    'overdue',
  ];
  // Keep the original key so the Birikio rename preserves all existing records.
  static const storageKey = 'pusula.local.v1';
  final Future<String?> Function() read;
  final Future<void> Function(String) write;
  FinanceStore({
    Future<String?> Function()? read,
    Future<void> Function(String)? write,
  }) : read = read ?? (() => SharedPreferencesAsync().getString(storageKey)),
       write =
           write ??
           ((value) => SharedPreferencesAsync().setString(storageKey, value));
  List<Entry> entries = [];
  List<RepeatRule> rules = [];
  List<Goal> goals = [];
  List<Transfer> transfers = [];
  List<AnnualPlan> annualPlans = [];
  List<ScheduledExpense> scheduledExpenses = [];
  Map<String, int> budgets = {};
  Map<String, Map<String, int>> categoryBudgets = {};
  bool notificationsEnabled = false;
  bool showWidgetBalance = false;
  DateTime? lastBackupAt;
  List<String> dashboardSections = [...defaultDashboardSections];
  Set<String> sentBudgetAlerts = {};
  List<String> incomeCategories = [...defaultIncomeCategories];
  List<String> expenseCategories = [...defaultExpenseCategories];
  Map<String, String> incomeCategoryIds = {
    for (final name in defaultIncomeCategories)
      name: 'income:${Uri.encodeComponent(name)}',
  };
  Map<String, String> expenseCategoryIds = {
    for (final name in defaultExpenseCategories)
      name: 'expense:${Uri.encodeComponent(name)}',
  };
  Map<String, String> categoryIdsFor(bool income) =>
      income ? incomeCategoryIds : expenseCategoryIds;
  String categoryIdFor(bool income, String name) =>
      categoryIdsFor(income)[name] ??
      '${income ? 'income' : 'expense'}:${Uri.encodeComponent(name)}';
  String generalBudgetId(DateTime month) =>
      'budget:${budgetKey(month)}:general';
  String categoryBudgetId(DateTime month, String category) =>
      'budget:${budgetKey(month)}:${categoryIdFor(false, category)}';
  List<String> categoriesFor(bool income) =>
      income ? incomeCategories : expenseCategories;
  void addCategory(bool income, String name) {
    final value = name.trim();
    if (value.isEmpty || value.length > 40) {
      throw ArgumentError('Kategori adı 1–40 karakter olmalı.');
    }
    final categories = categoriesFor(income);
    if (categories.any((c) => c.toLowerCase() == value.toLowerCase())) {
      throw ArgumentError('Bu kategori zaten var.');
    }
    categories.add(value);
    categoryIdsFor(income).putIfAbsent(value, uid);
  }

  void renameCategory(bool income, String oldName, String newName) {
    final categories = categoriesFor(income);
    final index = categories.indexOf(oldName);
    if (index < 0) throw ArgumentError('Kategori bulunamadı.');
    final value = newName.trim();
    if (value.isEmpty || value.length > 40) {
      throw ArgumentError('Kategori adı 1–40 karakter olmalı.');
    }
    if (categories.any(
      (c) => c != oldName && c.toLowerCase() == value.toLowerCase(),
    )) {
      throw ArgumentError('Bu kategori zaten var.');
    }
    if (oldName != value && categoryIdsFor(income).containsKey(value)) {
      throw ArgumentError('Bu ad geçmiş bir kategoriye ait.');
    }
    if (!income &&
        categoryBudgets.values.any(
          (monthly) =>
              monthly.containsKey(oldName) &&
              monthly.containsKey(value) &&
              oldName != value,
        )) {
      throw ArgumentError('Yeni adla bir kategori bütçesi zaten var.');
    }
    categories[index] = value;
    final ids = categoryIdsFor(income);
    ids[value] = ids.remove(oldName) ?? uid();
    for (final entry in entries.where(
      (e) => e.income == income && e.category == oldName,
    )) {
      entry.category = value;
    }
    for (final rule in rules.where(
      (r) => r.income == income && r.category == oldName,
    )) {
      rule.category = value;
    }
    if (!income) {
      for (final plan in annualPlans.where((p) => p.category == oldName)) {
        plan.category = value;
      }
      for (final plan in scheduledExpenses.where(
        (p) => p.category == oldName,
      )) {
        plan.category = value;
      }
    }
    if (!income) {
      for (final monthly in categoryBudgets.values) {
        if (monthly.containsKey(oldName)) {
          monthly[value] = monthly.remove(oldName)!;
        }
      }
    }
  }

  void removeCategory(bool income, String name) {
    if (!categoriesFor(income).remove(name)) {
      throw ArgumentError('Kategori bulunamadı.');
    }
    // Historical entries and recurrence rules keep their original label.
    // Their edit forms include that label even if it is no longer selectable
    // for new entries.
  }

  bool dark = true, followSystem = true, motion = true, busy = false;
  String? pinned;
  int get income =>
      entries.where((e) => e.income).fold(0, (v, e) => v + e.amount);
  int get expense =>
      entries.where((e) => !e.income).fold(0, (v, e) => v + e.amount);
  int get savings => transfers.fold(0, (v, e) => v + e.amount);
  int get balance => income - expense - savings;
  int saved(Goal g) =>
      transfers.where((e) => e.goal == g.id).fold(0, (v, e) => v + e.amount);
  List<Entry> get sorted => [...entries]
    ..sort((a, b) {
      final c = b.date.compareTo(a.date);
      return c == 0 ? b.id.compareTo(a.id) : c;
    });
  Goal? get featured => goals.isEmpty
      ? null
      : goals.firstWhere((g) => g.id == pinned, orElse: () => goals.first);
  String budgetKey(DateTime d) => '${d.year}-${d.month}';
  int categorySpent(DateTime month, String category) => entries
      .where(
        (e) =>
            !e.income &&
            e.category == category &&
            e.date.year == month.year &&
            e.date.month == month.month,
      )
      .fold(0, (sum, entry) => sum + entry.amount);
  void updateRecurringEntry(Entry original, Entry replacement, int scope) {
    final ruleId = original.rule;
    if (scope < 0 || scope > 2) {
      throw ArgumentError('Geçersiz düzenleme kapsamı.');
    }
    if (scope == 0 || ruleId == null) {
      final index = entries.indexWhere((e) => e.id == original.id);
      if (index < 0) throw StateError('Kayıt bulunamadı.');
      entries[index] = replacement;
      return;
    }
    for (final entry in entries.where(
      (e) =>
          e.rule == ruleId && (scope == 2 || !e.date.isBefore(original.date)),
    )) {
      entry.title = replacement.title;
      entry.amount = replacement.amount;
      entry.category = replacement.category;
      entry.note = replacement.note;
    }
    final rule = rules.where((r) => r.id == ruleId).firstOrNull;
    if (rule != null) {
      rule.title = replacement.title;
      rule.amount = replacement.amount;
      rule.category = replacement.category;
      rule.note = replacement.note;
    }
  }

  Map<String, dynamic> json() => {
    'schemaVersion': financeSchemaVersion,
    'entries': entries.map((e) => e.json()).toList(),
    'rules': rules.map((e) => e.json()).toList(),
    'goals': goals.map((e) => e.json()).toList(),
    'transfers': transfers.map((e) => e.json()).toList(),
    'annualPlans': annualPlans.map((e) => e.json()).toList(),
    'scheduledExpenses': scheduledExpenses.map((e) => e.json()).toList(),
    'budgets': budgets,
    'categoryBudgets': categoryBudgets,
    'notificationsEnabled': notificationsEnabled,
    'showWidgetBalance': showWidgetBalance,
    'lastBackupAt': lastBackupAt?.toIso8601String(),
    'dashboardSections': dashboardSections,
    'sentBudgetAlerts': sentBudgetAlerts.toList(),
    'incomeCategories': incomeCategories,
    'expenseCategories': expenseCategories,
    'incomeCategoryIds': incomeCategoryIds,
    'expenseCategoryIds': expenseCategoryIds,
    'dark': dark,
    'followSystem': followSystem,
    'motion': motion,
    'pinned': pinned,
  };
  void restore(Map<String, dynamic> j) {
    final document = migrateFinanceDocument(j);
    // Parse every field before replacing any live state.
    final nextEntries = (document['entries'] as List)
        .map((e) => Entry.read(Map<String, dynamic>.from(e)))
        .toList();
    final nextRules = (document['rules'] as List)
        .map((e) => RepeatRule.read(Map<String, dynamic>.from(e)))
        .toList();
    final nextGoals = (document['goals'] as List)
        .map((e) => Goal.read(Map<String, dynamic>.from(e)))
        .toList();
    final nextTransfers = (document['transfers'] as List)
        .map((e) => Transfer.read(Map<String, dynamic>.from(e)))
        .toList();
    final nextAnnualPlans = (document['annualPlans'] as List)
        .map((e) => AnnualPlan.read(Map<String, dynamic>.from(e)))
        .toList();
    final nextScheduledExpenses = (document['scheduledExpenses'] as List)
        .map((e) => ScheduledExpense.read(Map<String, dynamic>.from(e)))
        .toList();
    final nextBudgets = Map<String, int>.from(document['budgets']);
    final nextCategoryBudgets = (document['categoryBudgets'] as Map).map(
      (key, value) =>
          MapEntry(key as String, Map<String, int>.from(value as Map)),
    );
    final nextNotificationsEnabled =
        document['notificationsEnabled'] as bool? ?? false;
    final nextShowWidgetBalance =
        document['showWidgetBalance'] as bool? ?? false;
    final nextLastBackupAt = document['lastBackupAt'] == null
        ? null
        : DateTime.parse(document['lastBackupAt'] as String);
    final rawDashboardSections = document['dashboardSections'];
    final nextDashboardSections = rawDashboardSections == null
        ? [...defaultDashboardSections]
        : List<String>.from(
            rawDashboardSections as List,
          ).toSet().where(availableDashboardSections.contains).toList();
    final nextSentBudgetAlerts = Set<String>.from(
      document['sentBudgetAlerts'] as List? ?? const <String>[],
    );
    final nextIncomeCategories = List<String>.from(
      document['incomeCategories'] ?? defaultIncomeCategories,
    );
    final nextExpenseCategories = List<String>.from(
      document['expenseCategories'] ?? defaultExpenseCategories,
    );
    Map<String, String> readCategoryIds(String key, bool income) {
      final raw = document[key];
      final ids = raw == null
          ? <String, String>{}
          : Map<String, String>.from(raw as Map);
      final labels = <String>{
        ...income ? nextIncomeCategories : nextExpenseCategories,
        ...nextEntries.where((e) => e.income == income).map((e) => e.category),
        ...nextRules.where((r) => r.income == income).map((r) => r.category),
        if (!income) ...nextAnnualPlans.map((p) => p.category),
        if (!income) ...nextScheduledExpenses.map((p) => p.category),
        if (!income)
          ...nextCategoryBudgets.values.expand((monthly) => monthly.keys),
      };
      for (final label in labels) {
        ids.putIfAbsent(
          label,
          () =>
              '${income ? 'income' : 'expense'}:${Uri.encodeComponent(label)}',
        );
      }
      if (ids.values.toSet().length != ids.length ||
          ids.values.any((id) => id.isEmpty)) {
        throw const FormatException('Kategori kimlikleri geçersiz.');
      }
      return ids;
    }

    final nextIncomeCategoryIds = readCategoryIds('incomeCategoryIds', true);
    final nextExpenseCategoryIds = readCategoryIds('expenseCategoryIds', false);
    final nextDark = document['dark'] as bool;
    final nextFollowSystem = document['followSystem'] as bool? ?? true;
    final nextMotion = document['motion'] as bool;
    final nextPinned = document['pinned'] as String?;
    entries = nextEntries;
    rules = nextRules;
    goals = nextGoals;
    transfers = nextTransfers;
    annualPlans = nextAnnualPlans;
    scheduledExpenses = nextScheduledExpenses;
    budgets = nextBudgets;
    categoryBudgets = nextCategoryBudgets;
    notificationsEnabled = nextNotificationsEnabled;
    showWidgetBalance = nextShowWidgetBalance;
    lastBackupAt = nextLastBackupAt;
    dashboardSections = nextDashboardSections;
    sentBudgetAlerts = nextSentBudgetAlerts;
    incomeCategories = nextIncomeCategories;
    expenseCategories = nextExpenseCategories;
    incomeCategoryIds = nextIncomeCategoryIds;
    expenseCategoryIds = nextExpenseCategoryIds;
    dark = nextDark;
    followSystem = nextFollowSystem;
    motion = nextMotion;
    pinned = nextPinned;
  }

  Future<void> load() async {
    final raw = await read();
    if (raw != null) restore(decodeFinanceDocument(raw));
    await catchUp();
    notifyListeners();
  }

  Future<void> change(VoidCallback action) async {
    if (busy) throw StateError('Önceki işlem kaydediliyor.');
    final before = jsonEncode(json());
    busy = true;
    try {
      action();
      await write(jsonEncode(json()));
      notifyListeners();
    } catch (_) {
      restore(jsonDecode(before));
      rethrow;
    } finally {
      busy = false;
    }
  }

  void materialize(DateTime now) {
    for (final r in rules.where(
      (r) => r.active && (!r.isBill || r.automaticPayment),
    )) {
      while (!r.occurrence(r.cursor).isAfter(day(now))) {
        final date = r.occurrence(r.cursor);
        if (r.endDate != null && date.isAfter(day(r.endDate!))) break;
        final id = '${r.id}:${r.cursor}';
        if (!entries.any((e) => e.id == id)) {
          entries.add(
            Entry(
              id: id,
              title: r.title,
              amount: r.amount,
              income: r.income,
              date: date,
              category: r.category,
              note: r.note,
              rule: r.id,
            ),
          );
        }
        r.cursor++;
      }
    }
  }

  Future<void> catchUp({DateTime? now}) async {
    final today = now ?? DateTime.now();
    if (!busy &&
        rules.any(
          (r) =>
              r.active &&
              (!r.isBill || r.automaticPayment) &&
              !r.occurrence(r.cursor).isAfter(day(today)) &&
              (r.endDate == null ||
                  !r.occurrence(r.cursor).isAfter(day(r.endDate!))),
        )) {
      await change(() => materialize(today));
    }
  }

  int firstUnpaidBillPeriod(RepeatRule rule) {
    var index = 0;
    while (entries.any((entry) => entry.id == '${rule.id}:$index')) {
      index++;
    }
    return index;
  }

  Future<void> markBillPaid(
    RepeatRule rule,
    int period, {
    DateTime? paidAt,
    int? amount,
  }) => change(() {
    if (!rule.isBill || rule.automaticPayment || period < 0) {
      throw StateError('Bu ödeme manuel fatura değil.');
    }
    if (amount != null && amount <= 0) throw ArgumentError.value(amount);
    final due = rule.occurrence(period);
    if (rule.endDate != null && due.isAfter(day(rule.endDate!))) {
      throw StateError('Bu ödeme sona erdi.');
    }
    final paymentDate = paidAt ?? DateTime.now();
    final id = '${rule.id}:$period';
    if (entries.any((entry) => entry.id == id)) {
      throw StateError('Bu fatura zaten ödendi.');
    }
    entries.add(
      Entry(
        id: id,
        title: rule.title,
        amount: amount ?? rule.amount,
        income: false,
        date: day(paymentDate),
        category: rule.category,
        note: rule.note,
        rule: rule.id,
      ),
    );
  });

  Future<void> markScheduledExpensePaid(
    ScheduledExpense plan, {
    DateTime? paidAt,
    int? amount,
  }) => change(() {
    if (plan.paidAt != null) throw StateError('Ödeme zaten kaydedildi.');
    final date = day(paidAt ?? DateTime.now());
    if (amount != null && amount <= 0) throw ArgumentError.value(amount);
    plan.paidAt = date;
    entries.add(
      Entry(
        id: 'scheduled:${plan.id}',
        title: plan.title,
        amount: amount ?? plan.amount,
        income: false,
        date: date,
        category: plan.category,
        note: plan.note,
      ),
    );
  });

  Future<void> markAnnualPlanPaid(
    AnnualPlan plan,
    int year, {
    DateTime? paidAt,
    int? amount,
  }) => change(() {
    if (amount != null && amount <= 0) throw ArgumentError.value(amount);
    final id = 'annual:${plan.id}:$year';
    if (entries.any((entry) => entry.id == id)) {
      throw StateError('Ödeme zaten kaydedildi.');
    }
    entries.add(
      Entry(
        id: id,
        title: plan.title,
        amount: amount ?? plan.amount,
        income: false,
        date: day(paidAt ?? DateTime.now()),
        category: plan.category,
      ),
    );
  });

  void removeEntry(String id) {
    entries.removeWhere((entry) => entry.id == id);
    if (id.startsWith('scheduled:')) {
      final planId = id.substring('scheduled:'.length);
      for (final plan in scheduledExpenses.where((p) => p.id == planId)) {
        plan.paidAt = null;
      }
    }
  }

  Future<void> move(Goal goal, int amount) => change(() {
    if (amount > 0 && amount > balance) {
      throw StateError('Kullanılabilir bakiyen yeterli değil.');
    }
    if (amount < 0 && -amount > saved(goal)) {
      throw StateError('Birikiminden daha fazla çekemezsin.');
    }
    transfers.add(
      Transfer(id: uid(), goal: goal.id, amount: amount, date: DateTime.now()),
    );
  });
  Future<void> clear() => change(() {
    entries.clear();
    rules.clear();
    scheduledExpenses.clear();
    annualPlans.clear();
    goals.clear();
    transfers.clear();
    budgets.clear();
    categoryBudgets.clear();
    sentBudgetAlerts.clear();
    incomeCategories = [...defaultIncomeCategories];
    expenseCategories = [...defaultExpenseCategories];
    incomeCategoryIds = {
      for (final name in defaultIncomeCategories)
        name: 'income:${Uri.encodeComponent(name)}',
    };
    expenseCategoryIds = {
      for (final name in defaultExpenseCategories)
        name: 'expense:${Uri.encodeComponent(name)}',
    };
    pinned = null;
  });
}
