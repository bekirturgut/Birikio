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
  'Motor': Icons.two_wheeler_rounded,
  'Araba': Icons.directions_car_rounded,
  'Ev': Icons.home_rounded,
  'Tatil': Icons.flight_rounded,
  'Teknoloji': Icons.devices_rounded,
  'Güvence': Icons.shield_rounded,
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
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: financeColors(context).accent.withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: financeColors(context).accent, size: 30),
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
      builder: (_, _) => CustomPaint(
        painter: ScenePainter(
          controller.value,
          widget.icon,
          financeColors(context).accent,
        ),
        child: Center(
          child: Transform.translate(
            offset: Offset(
              widget.icon == 'Tatil'
                  ? math.sin(controller.value * math.pi * 2) * 18
                  : 0,
              math.sin(
                    controller.value *
                        math.pi *
                        (widget.icon == 'Motor' ? 16 : 2),
                  ) *
                  (widget.icon == 'Motor' ? 1.6 : 5),
            ),
            child: Transform.rotate(
              angle: widget.icon == 'Tatil' ? -.5 : 0,
              child: widget.icon == 'Motor'
                  ? RacingMotor(phase: controller.value)
                  : Icon(
                      goalIcons[widget.icon],
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
    final moving = icon == 'Motor' || icon == 'Araba';
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
    if (moving) {
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
    if (icon == 'Güvence' || icon == 'Ev') {
      canvas.drawCircle(
        center,
        38 + t * 25,
        Paint()
          ..color = accent.withValues(alpha: .25 * (1 - t))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    if (icon == 'Teknoloji') {
      canvas.drawLine(
        Offset(center.dx - 50, t * size.height),
        Offset(center.dx + 50, t * size.height),
        Paint()
          ..color = accent.withValues(alpha: .4)
          ..strokeWidth = 2,
      );
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
    duration: const Duration(milliseconds: 1300),
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
      builder: (_, _) => LayoutBuilder(
        builder: (_, box) => Stack(
          children: List.generate(9, (i) {
            final t = Curves.easeOutCubic.transform(c.value);
            final direction = widget.adding ? 1 - t : t;
            final angle = i * math.pi * 2 / 9;
            return Positioned(
              left:
                  box.maxWidth / 2 -
                  20 +
                  math.cos(angle) * direction * box.maxWidth * .65,
              top:
                  box.maxHeight * .4 +
                  math.sin(angle) * direction * 220 -
                  t * (widget.adding ? 0 : 150),
              child: Opacity(
                opacity: (math.sin(c.value * math.pi) * 1.5).clamp(0, 1),
                child: Transform.rotate(
                  angle: direction * (i - 4) * .35,
                  child: Container(
                    width: 45,
                    height: 27,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: widget.adding ? mint : coral,
                      borderRadius: BorderRadius.circular(5),
                      boxShadow: [
                        BoxShadow(
                          color: (widget.adding ? mint : coral).withValues(
                            alpha: .4,
                          ),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: const Text(
                      '₺',
                      style: TextStyle(
                        color: ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    ),
  );
}

/// The fairing, low handlebars, raised tail and tucked rider form a sport bike.
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
    final paint = Paint()..isAntiAlias = true;
    Path polygon(List<Offset> points) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final p in points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      return path..close();
    }

    void shape(List<Offset> points, Color color) => canvas.drawPath(
      polygon(points),
      paint
        ..color = color
        ..style = PaintingStyle.fill,
    );
    canvas.drawOval(
      const Rect.fromLTWH(13, 91, 139, 8),
      paint
        ..color = lavender.withValues(alpha: .28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    paint.maskFilter = null;
    // Tires, machined rims, rotating spokes and brake discs.
    for (final center in [const Offset(34, 78), const Offset(131, 78)]) {
      canvas.drawCircle(center, 21, paint..color = const Color(0xFF111626));
      canvas.drawCircle(
        center,
        17,
        paint
          ..color = const Color(0xFFB9A3FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
      canvas.drawCircle(
        center,
        11,
        paint
          ..color = const Color(0xFF554C76)
          ..strokeWidth = 1,
      );
      for (var i = 0; i < 6; i++) {
        final angle = i * math.pi / 3 + phase * math.pi * 40;
        canvas.drawLine(
          center,
          center + Offset(math.cos(angle) * 15, math.sin(angle) * 15),
          paint
            ..color = const Color(0xFF9D8ECA)
            ..strokeWidth = 1.6,
        );
      }
      canvas.drawCircle(
        center,
        3,
        paint
          ..style = PaintingStyle.fill
          ..color = const Color(0xFFE5DDFF),
      );
    }
    // Swingarm, front fork and underbody.
    canvas.drawLine(
      const Offset(34, 78),
      const Offset(79, 69),
      paint
        ..color = const Color(0xFF8B80AB)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      const Offset(113, 41),
      const Offset(131, 78),
      paint
        ..color = const Color(0xFFE2CE9B)
        ..strokeWidth = 3,
    );
    shape(const [
      Offset(54, 56),
      Offset(111, 55),
      Offset(99, 83),
      Offset(75, 84),
    ], const Color(0xFF615682));
    // Raised race tail and sculpted fuel tank.
    shape(const [
      Offset(15, 40),
      Offset(27, 36),
      Offset(55, 45),
      Offset(66, 52),
      Offset(42, 52),
    ], const Color(0xFFCABBFF));
    shape(const [
      Offset(45, 43),
      Offset(64, 45),
      Offset(70, 49),
      Offset(50, 50),
    ], const Color(0xFF151928));
    shape(const [
      Offset(61, 49),
      Offset(71, 37),
      Offset(91, 35),
      Offset(108, 45),
      Offset(92, 63),
    ], const Color(0xFFDDD3FF));
    // Aerodynamic nose, windshield and full racing fairing.
    shape(const [
      Offset(105, 31),
      Offset(119, 35),
      Offset(130, 47),
      Offset(114, 47),
    ], const Color(0xFF789DAF));
    shape(const [
      Offset(103, 43),
      Offset(128, 44),
      Offset(142, 53),
      Offset(126, 60),
      Offset(110, 72),
      Offset(98, 86),
      Offset(73, 83),
      Offset(80, 64),
    ], const Color(0xFFB6A0FF));
    shape(const [
      Offset(87, 65),
      Offset(125, 51),
      Offset(110, 66),
      Offset(98, 81),
      Offset(78, 78),
    ], const Color(0xFF8B72DB));
    shape(const [
      Offset(104, 51),
      Offset(132, 50),
      Offset(119, 55),
      Offset(99, 59),
    ], const Color(0xFFF0E9FF));
    shape(const [
      Offset(99, 64),
      Offset(111, 59),
      Offset(107, 65),
      Offset(96, 70),
    ], const Color(0xFF29223F));
    shape(const [
      Offset(94, 71),
      Offset(104, 67),
      Offset(100, 73),
      Offset(90, 77),
    ], const Color(0xFF29223F));
    // Headlight and front fender.
    canvas.drawLine(
      const Offset(130, 48),
      const Offset(138, 52),
      paint
        ..color = mint
        ..strokeWidth = 2,
    );
    canvas.drawArc(
      const Rect.fromLTWH(108, 54, 44, 40),
      math.pi * 1.05,
      math.pi * .72,
      false,
      paint
        ..style = PaintingStyle.stroke
        ..color = lavender
        ..strokeWidth = 4,
    );
    paint.style = PaintingStyle.fill;
    // Tucked rider and helmet: deliberately low, forward racing posture.
    shape(const [
      Offset(47, 41),
      Offset(56, 26),
      Offset(76, 22),
      Offset(94, 31),
      Offset(84, 38),
      Offset(66, 36),
      Offset(62, 46),
    ], const Color(0xFF8B85AE));
    shape(const [
      Offset(62, 44),
      Offset(79, 52),
      Offset(65, 67),
      Offset(78, 71),
      Offset(76, 76),
      Offset(54, 70),
      Offset(62, 55),
      Offset(49, 48),
    ], const Color(0xFFDDD2F5));
    canvas.drawLine(
      const Offset(80, 33),
      const Offset(98, 46),
      paint
        ..color = const Color(0xFFD8D0F0)
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      const Offset(98, 46),
      const Offset(111, 43),
      paint..strokeWidth = 4,
    );
    canvas.drawOval(
      const Rect.fromLTWH(84, 15, 24, 22),
      paint..color = const Color(0xFFE3DAFF),
    );
    shape(const [
      Offset(98, 20),
      Offset(107, 22),
      Offset(110, 28),
      Offset(98, 29),
      Offset(94, 25),
    ], const Color(0xFF233947));
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
