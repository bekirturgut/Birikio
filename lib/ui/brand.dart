import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'palette.dart';

/// The B combines two stacked savings pockets and a coin arriving at the top.
class BirikioMark extends StatelessWidget {
  final double size, progress;
  const BirikioMark({super.key, this.size = 48, this.progress = 1});
  @override
  Widget build(BuildContext context) {
    final colors = financeColors(context);
    return Semantics(
      label: 'Birikio logosu',
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: BirikioMarkPainter(
            progress,
            colors.positive,
            colors.accent,
            colors.gold,
          ),
        ),
      ),
    );
  }
}

class BirikioMarkPainter extends CustomPainter {
  final double progress;
  final Color green, purple, gold;
  BirikioMarkPainter(this.progress, this.green, this.purple, this.gold);
  double segment(double start, double end) =>
      ((progress - start) / (end - start)).clamp(0, 1);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final paint = Paint()..isAntiAlias = true;
    final lower = Curves.easeOutCubic.transform(segment(0, .48));
    final upper = Curves.easeOutCubic.transform(segment(.13, .62));
    final coin = Curves.easeOutBack.transform(segment(.38, .9));
    final bottom = Path()
      ..fillType = PathFillType.evenOdd
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(22, 47, 59, 36),
          const Radius.circular(18),
        ),
      )
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(39, 58, 27, 13),
          const Radius.circular(6.5),
        ),
      );
    final top = Path()
      ..fillType = PathFillType.evenOdd
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(22, 23, 53, 35),
          const Radius.circular(17.5),
        ),
      )
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(39, 34, 21, 12),
          const Radius.circular(6),
        ),
      );
    canvas.save();
    canvas.translate((1 - lower) * -32, (1 - lower) * 16);
    canvas.drawPath(bottom, paint..color = purple.withValues(alpha: lower));
    canvas.restore();
    canvas.save();
    canvas.translate((1 - upper) * 32, (1 - upper) * -14);
    canvas.drawPath(top, paint..color = green.withValues(alpha: upper));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(22, 23, 15, 60),
        const Radius.circular(6),
      ),
      paint..color = green.withValues(alpha: upper),
    );
    canvas.restore();
    canvas.save();
    canvas.translate(78, 17 - (1 - coin) * 42);
    canvas.scale(coin.clamp(0.0, 1.15));
    canvas.drawCircle(Offset.zero, 9, paint..color = gold);
    canvas.drawLine(
      const Offset(0, -4),
      const Offset(0, 4),
      paint
        ..color = const Color(0xFF0C101B)
        ..strokeWidth = 1.7
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(const Offset(-3, 0), const Offset(3, 0), paint);
    canvas.restore();
    final flare = math.sin(segment(.7, 1) * math.pi);
    if (flare > 0) {
      paint
        ..color = gold.withValues(alpha: flare)
        ..strokeWidth = 1.5;
      for (var i = 0; i < 5; i++) {
        final a = i * math.pi * 2 / 5;
        final radius = 12 + (1 - flare) * 8;
        canvas.drawLine(
          Offset(78 + math.cos(a) * radius, 17 + math.sin(a) * radius),
          Offset(
            78 + math.cos(a) * (radius + 4),
            17 + math.sin(a) * (radius + 4),
          ),
          paint,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(BirikioMarkPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.green != green ||
      oldDelegate.purple != purple ||
      oldDelegate.gold != gold;
}
