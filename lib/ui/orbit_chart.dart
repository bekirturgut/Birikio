import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/store.dart';

class ChartSlice {
  final String label;
  final int amount;
  final Color color;
  const ChartSlice(this.label, this.amount, this.color);
}

class OrbitChart extends StatefulWidget {
  final List<ChartSlice> slices;
  final String centerLabel;
  const OrbitChart({
    super.key,
    required this.slices,
    required this.centerLabel,
  });
  @override
  State<OrbitChart> createState() => _OrbitChartState();
}

class _OrbitChartState extends State<OrbitChart> {
  int selected = 0;
  @override
  void didUpdateWidget(OrbitChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (selected >= widget.slices.where((slice) => slice.amount > 0).length) {
      selected = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final slices = widget.slices.where((slice) => slice.amount > 0).toList();
    if (slices.isEmpty) return const SizedBox.shrink();
    final total = slices.fold(0, (sum, slice) => sum + slice.amount);
    final active = slices[selected.clamp(0, slices.length - 1)];
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Column(
      children: [
        Center(
          child: SizedBox(
            width: 202,
            height: 202,
            child: Stack(
              alignment: Alignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: reduced ? 1 : 0, end: 1),
                  duration: Duration(milliseconds: reduced ? 0 : 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, progress, _) => GestureDetector(
                    onTapUp: (details) {
                      final delta =
                          details.localPosition - const Offset(101, 101);
                      final distance = delta.distance;
                      if (distance < 58 || distance > 104) return;
                      final angle =
                          (math.atan2(delta.dy, delta.dx) +
                              math.pi / 2 +
                              math.pi * 2) %
                          (math.pi * 2);
                      var cursor = 0.0;
                      for (var i = 0; i < slices.length; i++) {
                        cursor += slices[i].amount / total * math.pi * 2;
                        if (angle <= cursor) {
                          setState(() => selected = i);
                          break;
                        }
                      }
                    },
                    child: CustomPaint(
                      size: const Size(202, 202),
                      painter: _OrbitPainter(slices, total, selected, progress),
                    ),
                  ),
                ),
                IgnorePointer(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.centerLabel,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '%${(active.amount / total * 100).round()}',
                        style: TextStyle(
                          color: active.color,
                          fontSize: 33,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.4,
                        ),
                      ),
                      Text(
                        active.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        money(active.amount),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 15),
        ...List.generate(slices.length, (index) {
          final slice = slices[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => selected = index),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
                child: Row(
                  children: [
                    Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: slice.color,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: selected == index
                            ? [
                                BoxShadow(
                                  color: slice.color.withValues(alpha: .45),
                                  blurRadius: 9,
                                ),
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        slice.label,
                        style: TextStyle(
                          fontWeight: selected == index
                              ? FontWeight.w800
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      '%${(slice.amount / total * 100).round()}',
                      style: TextStyle(
                        color: slice.color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      money(slice.amount),
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _OrbitPainter extends CustomPainter {
  final List<ChartSlice> slices;
  final int total, selected;
  final double progress;
  _OrbitPainter(this.slices, this.total, this.selected, this.progress);
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final base = Paint()
      ..color = slices.first.color.withValues(alpha: .08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22;
    canvas.drawCircle(center, 76, base);
    var angle = -math.pi / 2;
    for (var i = 0; i < slices.length; i++) {
      final sweep = slices[i].amount / total * math.pi * 2 * progress;
      if (sweep <= 0) continue;
      final rect = Rect.fromCircle(center: center, radius: 76);
      final gap = math.min(.026, sweep / 5);
      canvas.drawArc(
        rect,
        angle + gap,
        math.max(0, sweep - gap * 2),
        false,
        Paint()
          ..color = slices[i].color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 22
          ..strokeCap = StrokeCap.butt,
      );
      if (i == selected && progress > .9) {
        final end = angle + sweep / 2;
        canvas.drawCircle(
          center + Offset(math.cos(end), math.sin(end)) * 76,
          3,
          Paint()..color = Colors.white,
        );
      }
      angle += sweep;
    }
  }

  @override
  bool shouldRepaint(_OrbitPainter old) =>
      old.progress != progress ||
      old.selected != selected ||
      old.total != total ||
      old.slices != slices;
}
