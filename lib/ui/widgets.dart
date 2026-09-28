import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../data/store.dart';
import 'palette.dart';

const mint = Color(0xFF70E5BC);
const coral = Color(0xFFFF7D8C);
const lavender = Color(0xFFB9A3FF);
const ink = Color(0xFF0C101B);
const goalIcons = <String, IconData>{
  'Birikim': Icons.savings_rounded,
  'Motor': Icons.two_wheeler_rounded,
  'Araba': Icons.directions_car_rounded,
  'Ev': Icons.home_rounded,
  'Tatil': Icons.flight_rounded,
  'Teknoloji': Icons.devices_rounded,
  'Güvence': Icons.shield_rounded,
  'Eğitim': Icons.school_rounded,
  'İş': Icons.work_rounded,
  'Sağlık': Icons.favorite_rounded,
  'Düğün': Icons.diamond_rounded,
  'Çocuk': Icons.child_care_rounded,
  'Evcil dost': Icons.pets_rounded,
  'Spor': Icons.fitness_center_rounded,
  'Hobi': Icons.palette_rounded,
  'Bisiklet': Icons.pedal_bike_rounded,
  'Tekne': Icons.sailing_rounded,
  'Müzik': Icons.music_note_rounded,
  'Fotoğraf': Icons.camera_alt_rounded,
  'Oyun': Icons.sports_esports_rounded,
  'Yatırım': Icons.trending_up_rounded,
  'Diğer': Icons.auto_awesome_rounded,
};

class Panel extends StatelessWidget {
  final Widget child;
  final Color? color;
  final EdgeInsets padding;
  const Panel({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(20),
  });
  @override
  Widget build(BuildContext context) => Material(
    color: color ?? Theme.of(context).colorScheme.surfaceContainer,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(26),
      side: BorderSide(
        color: Theme.of(context).dividerColor.withValues(alpha: .08),
      ),
    ),
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: padding, child: child),
  );
}

class Eyebrow extends StatelessWidget {
  final String text;
  final Color? color;
  const Eyebrow(this.text, {super.key, this.color});
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 10,
      letterSpacing: 2,
      fontWeight: FontWeight.w700,
      color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

class Amount extends StatelessWidget {
  final int value;
  final double size;
  final Color? color;
  const Amount(this.value, {super.key, this.size = 28, this.color});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: value.toDouble()),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 650),
    curve: Curves.easeOutCubic,
    builder: (_, v, _) => FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        money(v.round()),
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w800,
          letterSpacing: -1,
          color: color,
        ),
      ),
    ),
  );
}

class EmptyState extends StatelessWidget {
  final String title, subtitle, action;
  final IconData icon;
  final VoidCallback onTap;
  const EmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    required this.action,
    required this.onTap,
    this.icon = Icons.auto_awesome_rounded,
  });
  @override
  Widget build(BuildContext context) => Panel(
    child: SizedBox(
      width: double.infinity,
      child: Column(
        children: [
          SizedBox(
            width: 116,
            height: 92,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: 7,
                  left: 12,
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 14,
                    color: financeColors(context).accent.withValues(alpha: .5),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  right: 10,
                  child: Icon(
                    Icons.circle,
                    size: 8,
                    color: financeColors(context).gold.withValues(alpha: .7),
                  ),
                ),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: .7, end: 1),
                  duration: Duration(
                    milliseconds: MediaQuery.disableAnimationsOf(context)
                        ? 0
                        : 650,
                  ),
                  curve: Curves.easeOutBack,
                  builder: (_, value, child) =>
                      Transform.scale(scale: value, child: child),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          financeColors(context).accent.withValues(alpha: .22),
                          financeColors(context).accent.withValues(alpha: .06),
                        ],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: financeColors(
                          context,
                        ).accent.withValues(alpha: .16),
                      ),
                    ),
                    child: Icon(
                      icon,
                      color: financeColors(context).accent,
                      size: 31,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(action),
          ),
        ],
      ),
    ),
  );
}

class GoalScene extends StatefulWidget {
  final String icon;
  final bool motion;
  final double height;
  const GoalScene({
    super.key,
    required this.icon,
    required this.motion,
    this.height = 115,
  });
  @override
  State<GoalScene> createState() => _GoalSceneState();
}

class _GoalSceneState extends State<GoalScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );
  @override
  void initState() {
    super.initState();
    if (widget.motion) controller.repeat();
  }

  @override
  void didUpdateWidget(GoalScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.motion) {
      if (!controller.isAnimating) controller.repeat();
    } else {
      controller.stop();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: widget.height,
    child: AnimatedBuilder(
      animation: controller,
      builder: (_, _) {
        final phase = controller.value * math.pi * 2;
        final travelling = {'Tatil', 'Bisiklet', 'Tekne'}.contains(widget.icon);
        final pulsing = {
          'Sağlık',
          'Çocuk',
          'Evcil dost',
          'Düğün',
        }.contains(widget.icon);
        return CustomPaint(
          painter: ScenePainter(
            controller.value,
            widget.icon,
            financeColors(context).accent,
          ),
          child: Center(
            child: Transform.translate(
              offset: Offset(
                travelling ? math.sin(phase) * 13 : 0,
                math.sin(phase * (widget.icon == 'Motor' ? 8 : 1)) *
                    (widget.icon == 'Motor' ? 1.6 : 4),
              ),
              child: Transform.scale(
                scale: pulsing ? 1 + .07 * math.sin(phase) : 1,
                child: Transform.rotate(
                  angle: widget.icon == 'Tatil'
                      ? -.38
                      : widget.icon == 'Müzik' || widget.icon == 'Hobi'
                      ? math.sin(phase) * .08
                      : 0,
                  child: widget.icon == 'Motor'
                      ? RacingMotor(phase: controller.value)
                      : Icon(
                          goalIcons[widget.icon] ?? Icons.auto_awesome_rounded,
                          size: 88,
                          color: financeColors(context).accent,
                          shadows: [
                            Shadow(
                              color: lavender.withValues(alpha: .6),
                              blurRadius: 36,
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class ScenePainter extends CustomPainter {
  final double t;
  final String icon;
  final Color accent;
  ScenePainter(this.t, this.icon, this.accent);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(
      center,
      size.height * .48,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                accent.withValues(alpha: .19),
                accent.withValues(alpha: 0),
              ],
            ).createShader(
              Rect.fromCircle(center: center, radius: size.height * .48),
            ),
    );
    final moving = {
      'Motor',
      'Araba',
      'Bisiklet',
      'Tekne',
      'Tatil',
    }.contains(icon);
    for (var i = 0; i < 15; i++) {
      final x = ((i * 43.7 - t * (moving ? 650 : 60)) % size.width);
      final y = (i * 29.3) % size.height;
      final p = Paint()
        ..color = accent.withValues(alpha: .09 + (i % 3) * .07)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      if (moving) {
        canvas.drawLine(Offset(x, y), Offset(x + 12 + i % 4 * 6, y), p);
      } else {
        canvas.drawCircle(
          Offset(x, y),
          1.5 + math.sin(t * math.pi * 2 + i).abs(),
          p,
        );
      }
    }
    if ({'Motor', 'Araba', 'Bisiklet'}.contains(icon)) {
      final p = Paint()
        ..color = accent.withValues(alpha: .3)
        ..strokeWidth = 2;
      for (var i = 0; i < 8; i++) {
        final x = (i * 65 - t * 800) % size.width;
        canvas.drawLine(
          Offset(x, size.height - 10),
          Offset(x + 30, size.height - 10),
          p,
        );
      }
    }
    if ({'Güvence', 'Ev', 'Düğün', 'Çocuk', 'Evcil dost'}.contains(icon)) {
      canvas.drawCircle(
        center,
        38 + t * 25,
        Paint()
          ..color = accent.withValues(alpha: .25 * (1 - t))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    if (icon == 'Teknoloji' || icon == 'Fotoğraf') {
      canvas.drawLine(
        Offset(center.dx - 50, t * size.height),
        Offset(center.dx + 50, t * size.height),
        Paint()
          ..color = accent.withValues(alpha: .4)
          ..strokeWidth = 2,
      );
    }
    final phase = t * math.pi * 2;
    final detail = Paint()
      ..color = accent.withValues(alpha: .5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    if ({'Eğitim', 'İş', 'Yatırım'}.contains(icon)) {
      for (var i = 0; i < 4; i++) {
        final height = 9.0 + i * 7 + math.sin(phase + i) * 4;
        final x = center.dx - 57 + i * 13;
        canvas.drawLine(
          Offset(x, size.height - 10),
          Offset(x, size.height - 10 - height),
          detail,
        );
      }
    } else if ({'Sağlık', 'Spor'}.contains(icon)) {
      final y = size.height * .82;
      final shift = math.sin(phase) * 3;
      final path = Path()
        ..moveTo(center.dx - 55, y)
        ..lineTo(center.dx - 25, y)
        ..lineTo(center.dx - 17, y - 8 - shift)
        ..lineTo(center.dx - 9, y + 8)
        ..lineTo(center.dx, y - 15 - shift)
        ..lineTo(center.dx + 10, y)
        ..lineTo(center.dx + 55, y);
      canvas.drawPath(path, detail);
    } else if ({'Hobi', 'Müzik', 'Oyun', 'Diğer'}.contains(icon)) {
      for (var i = 0; i < 8; i++) {
        final angle = i * math.pi / 4 + phase * .12;
        final radius = 44 + math.sin(phase + i) * 5;
        final start =
            center + Offset(math.cos(angle), math.sin(angle)) * radius;
        final end =
            center +
            Offset(math.cos(angle), math.sin(angle)) *
                (radius + (i.isEven ? 9 : 5));
        canvas.drawLine(start, end, detail);
      }
    } else if (icon == 'Birikim') {
      for (var i = 0; i < 5; i++) {
        final angle = phase * .55 + i * math.pi * 2 / 5;
        canvas.drawCircle(
          center + Offset(math.cos(angle) * 58, math.sin(angle) * 36),
          2.5 + (i.isEven ? 1 : 0),
          Paint()..color = accent.withValues(alpha: .5),
        );
      }
    } else if (icon == 'Tekne') {
      for (var i = 0; i < 3; i++) {
        final y = size.height - 9.0 - i * 8;
        final path = Path()..moveTo(center.dx - 55, y);
        for (var x = -54.0; x <= 55; x += 5) {
          path.lineTo(center.dx + x, y + math.sin(x * .12 + phase + i) * 2);
        }
        canvas.drawPath(path, detail);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(ScenePainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.icon != icon ||
      oldDelegate.accent != accent;
}

class MoneyBurst extends StatefulWidget {
  final bool adding;
  final VoidCallback onEnd;
  const MoneyBurst({super.key, required this.adding, required this.onEnd});
  @override
  State<MoneyBurst> createState() => _MoneyBurstState();
}

class _MoneyBurstState extends State<MoneyBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..forward().whenComplete(widget.onEnd);
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: c,
      builder: (_, _) {
        final t = c.value;
        final color = widget.adding ? mint : coral;
        final reveal = Curves.easeOutBack.transform((t / .55).clamp(0, 1));
        final opacity = ((1 - t) / .24).clamp(0.0, 1.0);
        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _MoneyMomentPainter(t, color, widget.adding),
              ),
            ),
            Positioned.fill(
              child: Center(
                child: Opacity(
                  opacity: opacity,
                  child: Transform.scale(
                    scale: reveal.clamp(0.0, 1.18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: color.withValues(alpha: .55)),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: .25),
                            blurRadius: 32,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            widget.adding
                                ? Icons.south_west_rounded
                                : Icons.north_east_rounded,
                            color: color,
                            size: 26,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            widget.adding
                                ? 'GELİR KAYDEDİLDİ'
                                : 'GİDER KAYDEDİLDİ',
                            style: TextStyle(
                              color: color,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: .6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _MoneyMomentPainter extends CustomPainter {
  final double t;
  final Color color;
  final bool income;
  _MoneyMomentPainter(this.t, this.color, this.income);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final fade = math.sin(t * math.pi).clamp(0.0, 1.0);
    final halo = Paint()
      ..color = color.withValues(alpha: .16 * fade)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 32);
    canvas.drawCircle(center, 85 + t * 50, halo);
    final line = Paint()..strokeCap = StrokeCap.round;
    for (var i = 0; i < 18; i++) {
      final angle = i * math.pi * 2 / 18 + (income ? -.3 : .3);
      final progress = Curves.easeOutCubic.transform(t);
      final distance = income ? (1 - progress) * 240 + 65 : progress * 260 + 55;
      final point =
          center +
          Offset(math.cos(angle) * distance, math.sin(angle) * distance * .7);
      line.color = color.withValues(alpha: fade * (i.isEven ? .8 : .45));
      line.strokeWidth = i.isEven ? 3 : 2;
      final direction = Offset(math.cos(angle), math.sin(angle) * .7);
      canvas.drawLine(point, point - direction * (i.isEven ? 18 : 9), line);
      if (i % 3 == 0) {
        canvas.drawCircle(
          point,
          3 + 2 * fade,
          Paint()..color = color.withValues(alpha: fade),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_MoneyMomentPainter old) =>
      old.t != t || old.color != color || old.income != income;
}

/// A compact side profile with a long fairing and a raised race tail.
class RacingMotor extends StatelessWidget {
  final double phase;
  final double width;
  const RacingMotor({super.key, this.phase = 0, this.width = 112});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: width * .7,
    child: CustomPaint(painter: RacingMotorPainter(phase)),
  );
}

class RacingMotorPainter extends CustomPainter {
  final double phase;
  RacingMotorPainter(this.phase);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 164, size.height / 112);
    final fill = Paint()..isAntiAlias = true;
    final stroke = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    void panel(List<Offset> points, Color color) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path..close(), fill..color = color);
    }

    void line(Offset start, Offset end, Color color, double width) =>
        canvas.drawLine(
          start,
          end,
          stroke
            ..color = color
            ..strokeWidth = width,
        );

    const ink = Color(0xFF171829);
    const metal = Color(0xFF8C95B3);
    const violet = Color(0xFF8668E8);
    const highlight = Color(0xFFE7DEFF);
    const wheelCenters = [Offset(34, 80), Offset(132, 80)];

    canvas.drawOval(
      const Rect.fromLTWH(15, 99, 137, 5),
      fill..color = lavender.withValues(alpha: .22),
    );
    for (final center in wheelCenters) {
      canvas.drawCircle(center, 22, fill..color = ink);
      canvas.drawCircle(
        center,
        19,
        stroke
          ..color = const Color(0xFF4E4A67)
          ..strokeWidth = 2.5,
      );
      canvas.drawCircle(
        center,
        16,
        stroke
          ..color = const Color(0xFFCED0E1)
          ..strokeWidth = 1.5,
      );
      canvas.drawCircle(center, 9, fill..color = const Color(0xFF37364D));
      for (var i = 0; i < 5; i++) {
        final angle = i * math.pi * 2 / 5 + phase * math.pi * 24;
        line(
          center,
          center + Offset(math.cos(angle) * 15, math.sin(angle) * 15),
          metal,
          1.8,
        );
      }
      canvas.drawCircle(center, 3.5, fill..color = highlight);
    }

    // Exposed frame, swingarm, fork and low exhaust keep the silhouette legible.
    line(const Offset(34, 80), const Offset(75, 68), metal, 5);
    line(const Offset(75, 68), const Offset(92, 83), metal, 4);
    line(const Offset(116, 39), const Offset(132, 80), highlight, 4);
    line(const Offset(121, 43), const Offset(136, 78), violet, 3);
    panel(const [
      Offset(64, 78),
      Offset(96, 78),
      Offset(91, 89),
      Offset(69, 89),
    ], const Color(0xFF50536D));
    panel(const [
      Offset(54, 79),
      Offset(71, 82),
      Offset(91, 86),
      Offset(82, 91),
      Offset(58, 88),
    ], metal);

    // High, pointed tail and a single continuous, angular sport fairing.
    panel(const [
      Offset(11, 39),
      Offset(33, 36),
      Offset(58, 48),
      Offset(65, 57),
      Offset(38, 53),
      Offset(25, 47),
    ], highlight);
    panel(const [
      Offset(31, 40),
      Offset(52, 46),
      Offset(68, 47),
      Offset(62, 53),
      Offset(40, 49),
    ], ink);
    panel(const [
      Offset(55, 50),
      Offset(73, 36),
      Offset(96, 36),
      Offset(109, 47),
      Offset(92, 58),
      Offset(69, 57),
    ], const Color(0xFFBBA6FF));
    panel(const [
      Offset(73, 55),
      Offset(106, 42),
      Offset(131, 43),
      Offset(151, 55),
      Offset(131, 61),
      Offset(117, 73),
      Offset(105, 87),
      Offset(76, 86),
      Offset(57, 74),
      Offset(61, 61),
    ], violet);
    panel(const [
      Offset(91, 57),
      Offset(130, 45),
      Offset(146, 54),
      Offset(119, 59),
      Offset(103, 68),
      Offset(85, 67),
    ], highlight);
    panel(const [
      Offset(71, 67),
      Offset(103, 68),
      Offset(124, 59),
      Offset(109, 82),
      Offset(84, 84),
      Offset(62, 74),
    ], const Color(0xFF4B3B82));
    panel(const [
      Offset(106, 64),
      Offset(120, 60),
      Offset(107, 79),
      Offset(95, 80),
    ], const Color(0xFF27233E));
    line(const Offset(75, 61), const Offset(112, 50), highlight, 2);
    panel(const [
      Offset(106, 38),
      Offset(114, 29),
      Offset(124, 31),
      Offset(134, 42),
    ], const Color(0xFF71839E));
    line(const Offset(107, 37), const Offset(100, 34), metal, 2);
    line(const Offset(137, 51), const Offset(146, 53), mint, 2.5);
    canvas.drawArc(
      const Rect.fromLTWH(111, 57, 41, 39),
      math.pi * 1.12,
      math.pi * .7,
      false,
      stroke
        ..color = violet
        ..strokeWidth = 3.5,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(RacingMotorPainter oldDelegate) =>
      oldDelegate.phase != phase;
}

/// A visible depth transition with a travelling mint/lilac light band.
class CinematicPageTransition extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;
  const CinematicPageTransition({
    super.key,
    required this.animation,
    required this.child,
  });
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation,
    child: child,
    builder: (context, child) {
      final t = animation.value.clamp(0.0, 1.0);
      if (t >= 1 || MediaQuery.disableAnimationsOf(context)) return child!;
      final progress = Curves.easeOutQuart.transform(t);
      final light = math.sin(t * math.pi);
      return ClipRect(
        child: LayoutBuilder(
          builder: (_, constraints) => Stack(
            children: [
              Opacity(
                opacity: Curves.easeOut.transform(t),
                child: Transform.translate(
                  offset: Offset(
                    (1 - progress) * constraints.maxWidth * .28,
                    (1 - progress) * 34,
                  ),
                  child: Transform.scale(
                    scale: .91 + .09 * progress,
                    alignment: Alignment.topCenter,
                    child: ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(
                        sigmaX: (1 - progress) * 5,
                        sigmaY: (1 - progress) * 5,
                      ),
                      child: child,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: light * .32,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment(-2.5 + t * 4, -1),
                          end: Alignment(-1.1 + t * 4, 1),
                          colors: [
                            Colors.transparent,
                            lavender.withValues(alpha: .07),
                            lavender.withValues(alpha: .45),
                            mint.withValues(alpha: .14),
                            Colors.transparent,
                          ],
                          stops: const [0, .35, .5, .6, 1],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class AchievementScene extends StatefulWidget {
  final bool motion;
  const AchievementScene({super.key, required this.motion});
  @override
  State<AchievementScene> createState() => _AchievementSceneState();
}

class _AchievementSceneState extends State<AchievementScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );
  @override
  void initState() {
    super.initState();
    if (widget.motion) controller.repeat();
  }

  @override
  void didUpdateWidget(AchievementScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.motion && !controller.isAnimating) controller.repeat();
    if (!widget.motion) controller.stop();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = financeColors(context);
    return Semantics(
      label: 'Hedef tamamlandı, başarı kupası',
      child: SizedBox(
        width: 110,
        height: 108,
        child: AnimatedBuilder(
          animation: controller,
          builder: (_, _) => CustomPaint(
            painter: AchievementPainter(controller.value, colors.gold),
            child: Center(
              child: Transform.translate(
                offset: Offset(
                  0,
                  widget.motion
                      ? math.sin(controller.value * math.pi * 2) * 3
                      : 0,
                ),
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        colors.gold.withValues(alpha: .25),
                        colors.gold.withValues(alpha: .06),
                      ],
                    ),
                    border: Border.all(
                      color: colors.gold.withValues(alpha: .4),
                    ),
                  ),
                  child: Icon(
                    Icons.emoji_events_rounded,
                    color: colors.gold,
                    size: 43,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AchievementPainter extends CustomPainter {
  final double phase;
  final Color color;
  AchievementPainter(this.phase, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4 - math.pi / 8;
      final radius = 43 + math.sin(phase * math.pi * 2 + i) * 3;
      final point =
          center + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
      final length = 2 + math.sin(phase * math.pi * 2 + i).abs() * 2;
      final p = Paint()
        ..color = color.withValues(
          alpha: .4 + .5 * math.sin(phase * math.pi + i).abs(),
        )
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(point - Offset(length, 0), point + Offset(length, 0), p);
      canvas.drawLine(point - Offset(0, length), point + Offset(0, length), p);
    }
  }

  @override
  bool shouldRepaint(AchievementPainter oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.color != color;
}
