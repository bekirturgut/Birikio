import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/money_journey.dart';
import '../data/store.dart';
import 'forms.dart';
import 'palette.dart';
import 'widgets.dart';

class MoneyJourneyCard extends StatelessWidget {
  final FinanceStore store;
  final DateTime start, end;
  const MoneyJourneyCard({
    super.key,
    required this.store,
    required this.start,
    required this.end,
  });

  Color _color(BuildContext context, FlowKind kind) => switch (kind) {
    FlowKind.income => financeColors(context).positive,
    FlowKind.withdrawal => financeColors(context).gold,
    FlowKind.priorBalance => financeColors(context).negative,
    FlowKind.expense => financeColors(context).negative,
    FlowKind.deposit => financeColors(context).accent,
    FlowKind.remaining => financeColors(context).positive,
  };

  Color _lineColor(BuildContext context, _FlowLine line) =>
      line.buckets.length > 1
      ? financeColors(context).accent
      : _color(context, line.buckets.first.kind);

  List<_FlowLine> _lines(List<FlowBucket> buckets) {
    if (buckets.length <= 5) {
      return [
        for (final bucket in buckets)
          _FlowLine(bucket.label, bucket.amount, [bucket]),
      ];
    }
    return [
      for (final bucket in buckets.take(4))
        _FlowLine(bucket.label, bucket.amount, [bucket]),
      _FlowLine(
        'Diğer akışlar',
        buckets.skip(4).fold(0, (sum, bucket) => sum + bucket.amount),
        buckets.skip(4).toList(),
      ),
    ];
  }

  Future<void> _showDetail(BuildContext context, _FlowLine line) async {
    final entries = <Entry>[];
    final transfers = <Transfer>[];
    for (final bucket in line.buckets) {
      if (bucket.kind == FlowKind.income || bucket.kind == FlowKind.expense) {
        entries.addAll(
          store.entries.where(
            (entry) =>
                !entry.date.isBefore(start) &&
                entry.date.isBefore(end) &&
                entry.income == (bucket.kind == FlowKind.income) &&
                entry.category == bucket.category,
          ),
        );
      } else if (bucket.kind == FlowKind.deposit ||
          bucket.kind == FlowKind.withdrawal) {
        transfers.addAll(
          store.transfers.where(
            (transfer) =>
                !transfer.date.isBefore(start) &&
                transfer.date.isBefore(end) &&
                transfer.goal == bucket.goalId &&
                (transfer.amount > 0) == (bucket.kind == FlowKind.deposit),
          ),
        );
      }
    }
    entries.sort((a, b) => b.date.compareTo(a.date));
    transfers.sort((a, b) => b.date.compareTo(a.date));
    await sheet(
      context,
      FormShell(
        title: line.label,
        subtitle: '${money(line.amount)} · seçili dönemin akışı',
        children: [
          if (entries.isEmpty && transfers.isEmpty)
            Text(
              line.buckets.first.kind == FlowKind.remaining
                  ? 'Bu tutar seçili dönemde gelir ve birikimden çekilen paradan, giderler ve birikime yatırılan para çıkarılınca kalan artıştır. Toplam hesap bakiyesi değildir.'
                  : 'Bu dönemin çıkışları, dönem içi girişleri aşıyor. Fark önceki birikmiş bakiyeden karşılanmış veya hesapta açık oluşmuş olabilir.',
              style: const TextStyle(height: 1.5),
            ),
          ...entries.map(
            (entry) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(entry.title),
              subtitle: Text('${dateLabel(entry.date)} · ${entry.category}'),
              trailing: Text(money(entry.amount)),
            ),
          ),
          ...transfers.map(
            (transfer) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                store.goals
                        .where((g) => g.id == transfer.goal)
                        .map((g) => g.title)
                        .firstOrNull ??
                    'Eski hedef',
              ),
              subtitle: Text(dateLabel(transfer.date)),
              trailing: Text(money(transfer.amount.abs())),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final journey = calculateMoneyJourney(store, start, end);
    final sources = _lines(journey.sources);
    final destinations = _lines(journey.destinations);
    final colors = financeColors(context);
    if (journey.total == 0) {
      return Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('PARANIN YOLCULUĞU'),
            const SizedBox(height: 13),
            Center(
              child: SizedBox(
                width: 195,
                height: 70,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(
                    milliseconds: MediaQuery.disableAnimationsOf(context)
                        ? 0
                        : 850,
                  ),
                  builder: (_, progress, _) => CustomPaint(
                    painter: _EmptyFlowPainter(
                      progress,
                      colors.accent,
                      colors.positive,
                      colors.negative,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'İlk akışını bekliyor',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 5),
            Text(
              'Bu döneme gelir veya gider eklediğinde paranın yolu burada canlanacak.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }
    return FeatureCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              IconBadge(Icons.route_rounded, size: 36),
              SizedBox(width: 10),
              Expanded(child: Eyebrow('PARANIN YOLCULUĞU')),
              InfoButton(
                title: 'Akış hesabı',
                message:
                    'Akışa dokunarak kayıtları açabilirsin. Birikime yatırma gider, birikimden çekme gelir sayılmaz. Akışlar dönem toplamıdır; belirli bir gelirin hangi gideri ödediği varsayılmaz.',
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Nereden geldi, nereye aktı?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Akışa dokun, içindeki kayıtları gör.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'KAYNAKLAR',
            style: TextStyle(
              color: colors.goalMuted,
              fontSize: 10,
              letterSpacing: 1.3,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final line in sources)
                ActionChip(
                  avatar: Icon(
                    Icons.south_west_rounded,
                    size: 15,
                    color: _lineColor(context, line),
                  ),
                  label: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 230),
                    child: Text(
                      '${line.label} · ${money(line.amount)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  onPressed: () => _showDetail(context, line),
                ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: destinations.length * 58 + 34,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final reduced = MediaQuery.disableAnimationsOf(context);
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: reduced ? 1 : 0, end: 1),
                  duration: Duration(milliseconds: reduced ? 0 : 850),
                  curve: Curves.easeOutCubic,
                  builder: (context, progress, _) => Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _FlowRibbonPainter(
                            amounts: [
                              for (final line in destinations) line.amount,
                            ],
                            colors: [
                              for (final line in destinations)
                                _lineColor(context, line),
                            ],
                            total: journey.total,
                            progress: progress,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        left: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: colors.accent.withValues(alpha: .18),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'ORTAK HAVUZ  ${money(journey.total)}',
                            style: TextStyle(
                              color: colors.accent,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      for (var i = 0; i < destinations.length; i++)
                        Positioned(
                          top: 34 + i * 58.0,
                          left: 69,
                          right: 0,
                          child: Material(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainer
                                .withValues(alpha: .95),
                            borderRadius: BorderRadius.circular(13),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(13),
                              onTap: () =>
                                  _showDetail(context, destinations[i]),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 4,
                                      height: 26,
                                      decoration: BoxDecoration(
                                        color: _lineColor(
                                          context,
                                          destinations[i],
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        destinations[i].label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      money(destinations[i].amount),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _FlowLine {
  final String label;
  final int amount;
  final List<FlowBucket> buckets;
  const _FlowLine(this.label, this.amount, this.buckets);
}

class _FlowRibbonPainter extends CustomPainter {
  final List<int> amounts;
  final List<Color> colors;
  final int total;
  final double progress;
  _FlowRibbonPainter({
    required this.amounts,
    required this.colors,
    required this.total,
    required this.progress,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final origin = const Offset(28, 25);
    for (var i = 0; i < amounts.length; i++) {
      final end = Offset(size.width - 12, 56 + i * 58.0);
      final path = Path()
        ..moveTo(origin.dx, origin.dy)
        ..cubicTo(70, origin.dy + i * 7.0, 58, end.dy, end.dx, end.dy);
      final metric = path.computeMetrics().first;
      final revealed = metric.extractPath(0, metric.length * progress);
      final width = 3.0 + math.sqrt(amounts[i] / total) * 15;
      canvas.drawPath(
        revealed,
        Paint()
          ..shader = LinearGradient(
            colors: [
              colors[i].withValues(alpha: .18),
              colors[i].withValues(alpha: .62),
            ],
          ).createShader(Offset.zero & size)
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawCircle(
      origin,
      9,
      Paint()..color = colors.first.withValues(alpha: .85),
    );
    canvas.drawCircle(
      origin,
      16,
      Paint()..color = colors.first.withValues(alpha: .13),
    );
  }

  @override
  bool shouldRepaint(_FlowRibbonPainter old) =>
      old.progress != progress ||
      old.total != total ||
      old.amounts != amounts ||
      old.colors != colors;
}

class _EmptyFlowPainter extends CustomPainter {
  final double progress;
  final Color centerColor, incomeColor, expenseColor;
  _EmptyFlowPainter(
    this.progress,
    this.centerColor,
    this.incomeColor,
    this.expenseColor,
  );
  @override
  void paint(Canvas canvas, Size size) {
    final start = Offset(22, size.height / 2);
    final center = Offset(size.width / 2, size.height / 2);
    final upper = Offset(size.width - 22, 15);
    final lower = Offset(size.width - 22, size.height - 15);
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(56, start.dy, center.dx, center.dy)
      ..quadraticBezierTo(size.width - 57, 15, upper.dx, upper.dy)
      ..moveTo(center.dx, center.dy)
      ..quadraticBezierTo(
        size.width - 57,
        size.height - 15,
        lower.dx,
        lower.dy,
      );
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(
        metric.extractPath(0, metric.length * progress),
        Paint()
          ..color = centerColor.withValues(alpha: .58)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }
    for (final point in [start, center, upper, lower]) {
      canvas.drawCircle(
        point,
        point == center ? 8 : 5,
        Paint()
          ..color = point == upper
              ? expenseColor
              : point == lower
              ? centerColor
              : incomeColor,
      );
    }
  }

  @override
  bool shouldRepaint(_EmptyFlowPainter old) =>
      old.progress != progress ||
      old.centerColor != centerColor ||
      old.incomeColor != incomeColor ||
      old.expenseColor != expenseColor;
}
