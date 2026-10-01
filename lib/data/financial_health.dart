import 'dart:math' as math;

import 'goal_plan.dart';
import 'store.dart';

class HealthFactor {
  final String title;
  final int score;
  final int weight;
  final String explanation;

  const HealthFactor(this.title, this.score, this.weight, this.explanation);
}

class FinancialHealthReport {
  final int? score;
  final String dataQuality;
  final List<HealthFactor> factors;
  final List<String> observations;
  final String? attention;
  final String? topCategory;
  final int topCategoryShare;

  const FinancialHealthReport({
    required this.score,
    required this.dataQuality,
    required this.factors,
    required this.observations,
    required this.attention,
    required this.topCategory,
    required this.topCategoryShare,
  });
}

int _sum(Iterable<int> values) => values.fold(0, (sum, value) => sum + value);
int _score(num value) => value.round().clamp(0, 100);
DateTime _month(DateTime date, int offset) =>
    DateTime(date.year, date.month + offset);
int _firstPeriodNear(RepeatRule rule, DateTime start) {
  final days = start.difference(rule.start).inDays;
  return switch (rule.frequency) {
    1 => math.max(0, days - 2),
    2 => math.max(0, days ~/ 7 - 2),
    3 => math.max(
      0,
      (start.year - rule.start.year) * 12 + start.month - rule.start.month - 2,
    ),
    4 => math.max(0, start.year - rule.start.year - 2),
    _ => 0,
  };
}

bool _within(DateTime date, DateTime start, DateTime end) =>
    !date.isBefore(start) && date.isBefore(end);

/// A local, descriptive score based only on records the user entered.
/// Missing dimensions are excluded and the remaining weights are normalized.
FinancialHealthReport financialHealthReport(FinanceStore store, DateTime now) {
  final start = _month(now, -3);
  final end = day(now).add(const Duration(days: 1));
  final recentEntries = store.entries
      .where((e) => _within(e.date, start, end))
      .toList();
  final recentTransfers = store.transfers
      .where((t) => _within(t.date, start, end))
      .toList();
  final income = _sum(
    recentEntries.where((e) => e.income).map((e) => e.amount),
  );
  final expense = _sum(
    recentEntries.where((e) => !e.income).map((e) => e.amount),
  );
  final deposits = _sum(
    recentTransfers.where((t) => t.amount > 0).map((t) => t.amount),
  );
  final withdrawals = _sum(
    recentTransfers.where((t) => t.amount < 0).map((t) => -t.amount),
  );
  final withdrawalCount = recentTransfers.where((t) => t.amount < 0).length;
  final factors = <HealthFactor>[];
  final observations = <String>[];
  final alerts = <(int, String)>[];
  void alert(int priority, String message) {
    observations.add(message);
    alerts.add((priority, message));
  }

  if (income > 0 || expense > 0) {
    final ratio = income == 0 ? 2.0 : expense / income;
    factors.add(
      HealthFactor(
        'Gelir–gider dengesi',
        _score(105 - ratio * 65),
        25,
        income == 0
            ? 'İncelenen dönemde gider var, kayıtlı gelir yok.'
            : 'İncelenen dönemde giderler gelirlerin %${(ratio * 100).round()} kadarına ulaştı.',
      ),
    );
    if (expense > income) {
      alert(70, 'İncelenen dönemin giderleri gelirlerini aştı.');
    }
  }

  final key = store.budgetKey(now);
  final budgetRatios = <double>[];
  final general = store.budgets[key] ?? 0;
  if (general > 0) {
    final spent = _sum(
      recentEntries
          .where(
            (e) =>
                !e.income &&
                e.date.year == now.year &&
                e.date.month == now.month,
          )
          .map((e) => e.amount),
    );
    budgetRatios.add(spent / general);
  }
  for (final limit in (store.categoryBudgets[key] ?? {}).entries) {
    if (limit.value > 0) {
      budgetRatios.add(store.categorySpent(now, limit.key) / limit.value);
    }
  }
  if (budgetRatios.isNotEmpty) {
    final average = budgetRatios.reduce((a, b) => a + b) / budgetRatios.length;
    final highest = budgetRatios.reduce(math.max);
    factors.add(
      HealthFactor(
        'Bütçe sınırları',
        _score(
          95 - math.max(0, average - .8) * 110 - math.max(0, highest - 1) * 25,
        ),
        15,
        '${budgetRatios.length} limitin ortalama %${(average * 100).round()} kullanıldı.',
      ),
    );
    if (highest > 1) alert(65, 'En az bir bütçe limitin aşıldı.');
  }

  if (store.goals.isNotEmpty || recentTransfers.isNotEmpty) {
    final depositRate = income > 0 ? deposits / income : 0.0;
    final withdrawalRatio = deposits > 0
        ? withdrawals / deposits
        : (withdrawals > 0 ? 1.0 : 0.0);
    factors.add(
      HealthFactor(
        'Birikim hareketleri',
        _score(
          45 +
              math.min(depositRate, .2) * 200 -
              math.min(withdrawalRatio, 1.5) * 38 -
              math.max(0, withdrawalCount - 1) * 8 -
              (withdrawals > deposits ? 12 : 0),
        ),
        20,
        'İncelenen dönemde ${money(deposits)} yatırıldı, ${money(withdrawals)} çekildi.',
      ),
    );
    if (withdrawalCount >= 2) {
      alert(
        60,
        'Birikiminden incelenen dönemde $withdrawalCount kez para çektin; hedefe ayrılan para sık kullanılıyor.',
      );
    } else if (withdrawals > deposits && withdrawals > 0) {
      alert(55, 'Birikiminden yatırdığından daha fazla para çektin.');
    } else if (deposits > 0 && withdrawals == 0) {
      observations.add('Birikimine para ekledin ve bu dönemde çekim yapmadın.');
    }
  }

  var dueCount = 0, onTime = 0, late = 0, overdue = 0;
  for (final rule in store.rules.where((r) => r.isBill && r.active)) {
    final first = _firstPeriodNear(rule, start);
    for (var period = first; period < first + 400; period++) {
      final due = rule.occurrence(period);
      if (rule.endDate != null && due.isAfter(day(rule.endDate!))) break;
      if (!due.isBefore(end)) break;
      if (due.isBefore(start)) continue;
      final payment = store.entries
          .where((e) => e.id == '${rule.id}:$period')
          .firstOrNull;
      if (payment == null && !due.isBefore(day(now))) continue;
      dueCount++;
      if (payment == null) {
        overdue++;
      } else if (day(payment.date).isAfter(day(due))) {
        late++;
      } else {
        onTime++;
      }
    }
  }
  if (dueCount > 0) {
    factors.add(
      HealthFactor(
        'Fatura düzeni',
        _score((onTime * 100 + late * 50) / dueCount),
        15,
        '$dueCount vadeden $onTime tanesi zamanında, $late tanesi geç kaydedildi; $overdue ödeme açık.',
      ),
    );
    if (overdue > 0) {
      alert(
        100,
        '$overdue düzenli ödemenin vadesi geçti ve ödenmiş görünmüyor.',
      );
    } else if (late > 0) {
      alert(50, '$late düzenli ödeme vadesinden sonra kaydedildi.');
    }
  }

  final planScores = <double>[];
  var currentMissing = 0;
  var latePlans = 0;
  for (final goal in store.goals) {
    for (var offset = -3; offset <= 0; offset++) {
      final status = monthlyGoalStatus(
        goal,
        store.transfers,
        _month(now, offset),
        now: now,
      );
      if (status == null || !status.duePassed) continue;
      planScores.add(
        status.onTimeSatisfied
            ? 1
            : ((status.onTimeDeposited / status.required).clamp(0, 1) * .7 +
                  (status.netDeposited / status.required).clamp(0, 1) * .3),
      );
      if (offset == 0) currentMissing += status.missing;
      if (status.late) latePlans++;
    }
  }
  if (planScores.isNotEmpty) {
    final average = planScores.reduce((a, b) => a + b) / planScores.length;
    factors.add(
      HealthFactor(
        'Aylık birikim sözü',
        _score(average * 100),
        15,
        '${planScores.length} vadesi gelen aylık planda ortalama %${(average * 100).round()} birikim yapıldı.',
      ),
    );
    if (currentMissing > 0) {
      alert(
        90,
        'Bu ay birikim planına ${money(currentMissing)} eksik yatırdın.',
      );
    } else if (latePlans > 0) {
      alert(
        45,
        '$latePlans aylık birikim sözü vade gününden sonra tamamlandı.',
      );
    }
  }

  final completedMonths = [
    for (var offset = -3; offset <= -1; offset++) _month(now, offset),
  ];
  int monthTotal(DateTime month, bool isIncome) => _sum(
    store.entries
        .where(
          (e) =>
              e.income == isIncome &&
              e.date.year == month.year &&
              e.date.month == month.month,
        )
        .map((e) => e.amount),
  );
  final monthlyIncome = completedMonths
      .map((m) => monthTotal(m, true))
      .toList();
  final monthlyExpense = completedMonths
      .map((m) => monthTotal(m, false))
      .toList();
  final incomeMonths = monthlyIncome.where((v) => v > 0).toList();
  if (incomeMonths.length >= 2) {
    final highest = incomeMonths.reduce(math.max);
    final lowest = incomeMonths.reduce(math.min);
    final recurringIncome =
        store.entries
            .where(
              (e) =>
                  e.income &&
                  e.rule != null &&
                  _within(e.date, _month(now, -3), _month(now, 0)),
            )
            .length >=
        2;
    factors.add(
      HealthFactor(
        'Gelir düzeni',
        _score(
          100 - (highest - lowest) / highest * 70 + (recurringIncome ? 5 : 0),
        ),
        10,
        'Tamamlanan ${incomeMonths.length} ayda gelir ${money(lowest)}–${money(highest)} arasında. ${recurringIncome ? 'Tekrarlayan gelir kaydı var.' : ''}',
      ),
    );
  }
  if (monthlyIncome[1] > 0 && monthlyIncome[2] > 0) {
    final previousRatio = monthlyExpense[1] / monthlyIncome[1];
    final latestRatio = monthlyExpense[2] / monthlyIncome[2];
    factors.add(
      HealthFactor(
        'Aylık gidişat',
        _score(65 + (previousRatio - latestRatio) * 75),
        7,
        'Son tamamlanan ayda gider/gelir oranı %${(latestRatio * 100).round()}; önceki ay %${(previousRatio * 100).round()}.',
      ),
    );
    if (latestRatio > previousRatio + .15) {
      alert(40, 'Giderlerinin gelirine oranı önceki aya göre yükseldi.');
    }
  }

  if (expense > 0) {
    final elapsedDays = math.max(1, day(now).difference(start).inDays + 1);
    final monthlyPace = expense * 30 / elapsedDays;
    factors.add(
      HealthFactor(
        'Bakiye tamponu',
        _score(store.balance / monthlyPace / 3 * 100),
        5,
        'Kullanılabilir bakiye, son dönem harcama hızının yaklaşık ${((store.balance / monthlyPace) * 10).round() / 10} aylık karşılığı.',
      ),
    );
  }

  final categories = <String, int>{};
  for (final entry in recentEntries.where((e) => !e.income)) {
    categories[entry.category] =
        (categories[entry.category] ?? 0) + entry.amount;
  }
  final top = categories.entries.isEmpty
      ? null
      : (categories.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .first;
  final topShare = top == null || expense == 0
      ? 0
      : (top.value / expense * 100).round();
  if (categories.length >= 2 && top != null) {
    factors.add(
      HealthFactor(
        'Harcama dağılımı',
        _score(100 - math.max(0, topShare - 50) * .8),
        3,
        'En yüksek harcama ${top.key} kategorisinde: toplam giderin %$topShare kadarı.',
      ),
    );
  }
  if (top != null) {
    observations.add(
      'En çok ${top.key} kategorisinde harcadın: ${money(top.value)} (%$topShare).',
    );
  }

  final totalWeight = _sum(factors.map((f) => f.weight));
  final score =
      totalWeight == 0 ||
          (recentEntries.isEmpty &&
              recentTransfers.isEmpty &&
              dueCount == 0 &&
              planScores.isEmpty)
      ? null
      : _score(
          factors.fold<int>(0, (sum, f) => sum + f.score * f.weight) /
              totalWeight,
        );
  final activeMonths = <String>{
    for (final entry in recentEntries) '${entry.date.year}-${entry.date.month}',
    for (final transfer in recentTransfers)
      '${transfer.date.year}-${transfer.date.month}',
  }.length;
  final dataQuality = activeMonths < 2 || factors.length < 3
      ? 'İlk veriler'
      : activeMonths < 3 || factors.length < 5
      ? 'Gelişen görünüm'
      : 'Kapsamlı görünüm';
  if (observations.isEmpty && score != null) {
    observations.add(
      'Kayıtların dengeli görünüyor; birkaç ay daha izledikçe yorumlar zenginleşecek.',
    );
  }
  return FinancialHealthReport(
    score: score,
    dataQuality: dataQuality,
    factors: factors,
    observations: observations,
    attention: alerts.isEmpty
        ? null
        : (alerts..sort((a, b) => b.$1.compareTo(a.$1))).first.$2,
    topCategory: top?.key,
    topCategoryShare: topShare,
  );
}
