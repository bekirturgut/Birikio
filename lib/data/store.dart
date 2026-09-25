import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  DateTime start;
  RepeatRule({
    required this.id,
    required this.title,
    required this.amount,
    required this.income,
    required this.start,
    required this.category,
    required this.frequency,
    this.note = '',
    this.cursor = 0,
    this.active = true,
  });
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
    return DateTime(
      base.year,
      base.month,
      min(start.day, DateTime(base.year, base.month + 1, 0).day),
    );
  }

  Map<String, dynamic> json() => {
    'id': id,
    'title': title,
    'amount': amount,
    'income': income,
    'start': start.toIso8601String(),
    'category': category,
    'frequency': frequency,
    'note': note,
    'cursor': cursor,
    'active': active,
  };
  factory RepeatRule.read(Map<String, dynamic> j) => RepeatRule(
    id: j['id'],
    title: j['title'],
    amount: j['amount'],
    income: j['income'],
    start: DateTime.parse(j['start']),
    category: j['category'],
    frequency: j['frequency'],
    note: j['note'],
    cursor: j['cursor'],
    active: j['active'],
  );
}

class Goal {
  String id, title, icon;
  int target;
  Goal({
    required this.id,
    required this.title,
    required this.icon,
    required this.target,
  });
  Map<String, dynamic> json() => {
    'id': id,
    'title': title,
    'icon': icon,
    'target': target,
  };
  factory Goal.read(Map<String, dynamic> j) => Goal(
    id: j['id'],
    title: j['title'],
    icon: j['icon'],
    target: j['target'],
  );
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

class FinanceStore extends ChangeNotifier {
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
  Map<String, int> budgets = {};
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
  Map<String, dynamic> json() => {
    'entries': entries.map((e) => e.json()).toList(),
    'rules': rules.map((e) => e.json()).toList(),
    'goals': goals.map((e) => e.json()).toList(),
    'transfers': transfers.map((e) => e.json()).toList(),
    'budgets': budgets,
    'dark': dark,
    'followSystem': followSystem,
    'motion': motion,
    'pinned': pinned,
  };
  void restore(Map<String, dynamic> j) {
    entries = (j['entries'] as List)
        .map((e) => Entry.read(Map<String, dynamic>.from(e)))
        .toList();
    rules = (j['rules'] as List)
        .map((e) => RepeatRule.read(Map<String, dynamic>.from(e)))
        .toList();
    goals = (j['goals'] as List)
        .map((e) => Goal.read(Map<String, dynamic>.from(e)))
        .toList();
    transfers = (j['transfers'] as List)
        .map((e) => Transfer.read(Map<String, dynamic>.from(e)))
        .toList();
    budgets = Map<String, int>.from(j['budgets']);
    dark = j['dark'];
    followSystem = j['followSystem'] ?? true;
    motion = j['motion'];
    pinned = j['pinned'];
  }

  Future<void> load() async {
    final raw = await read();
    if (raw != null) restore(jsonDecode(raw));
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
    for (final r in rules.where((r) => r.active)) {
      while (!r.occurrence(r.cursor).isAfter(day(now))) {
        final date = r.occurrence(r.cursor);
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
          (r) => r.active && !r.occurrence(r.cursor).isAfter(day(today)),
        )) {
      await change(() => materialize(today));
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
    goals.clear();
    transfers.clear();
    budgets.clear();
    pinned = null;
  });
}
