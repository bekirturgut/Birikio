import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/store.dart';
import 'brand.dart';
import 'palette.dart';

class BirikioLaunch extends StatefulWidget {
  final FinanceStore store;
  final Widget home;
  const BirikioLaunch({super.key, required this.store, required this.home});
  @override
  State<BirikioLaunch> createState() => _BirikioLaunchState();
}

class _BirikioLaunchState extends State<BirikioLaunch>
    with SingleTickerProviderStateMixin {
  late final AnimationController animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2300),
  );
  bool ready = false, finished = false, failed = false, started = false;
  @override
  void initState() {
    super.initState();
    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => finished = true);
      }
    });
    load();
  }

  Future<void> load() async {
    if (mounted) setState(() => failed = false);
    try {
      await widget.store.load();
      if (mounted) setState(() => ready = true);
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      animation.stop();
      finished = true;
    } else if (!started) {
      started = true;
      animation.forward();
    }
  }

  @override
  void dispose() {
    animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final colors = financeColors(context);
    return AnimatedSwitcher(
      duration: Duration(milliseconds: reduced ? 0 : 650),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (child, a) => FadeTransition(
        opacity: a,
        child: ScaleTransition(
          scale: Tween<double>(begin: 1.04, end: 1).animate(a),
          child: child,
        ),
      ),
      child: ready && finished
          ? KeyedSubtree(
              key: const ValueKey('birikio-home'),
              child: widget.home,
            )
          : Scaffold(
              key: const ValueKey('birikio-launch'),
              body: SafeArea(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: const Alignment(0, -.15),
                            radius: .85,
                            colors: [
                              colors.accent.withValues(alpha: .1),
                              Theme.of(context).colorScheme.surface,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(32),
                        child: AnimatedBuilder(
                          animation: animation,
                          builder: (_, _) {
                            final t = reduced ? 1.0 : animation.value;
                            final reveal = Curves.easeOutCubic.transform(
                              ((t - .4) / .35).clamp(0, 1),
                            );
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox.square(
                                  dimension: 180,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Transform.scale(
                                        scale: .7 + t * .4,
                                        child: Container(
                                          width: 160,
                                          height: 160,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: colors.accent.withValues(
                                                alpha:
                                                    math.sin(t * math.pi) * .23,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        width: 138,
                                        height: 138,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            40,
                                          ),
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.surfaceContainer,
                                          boxShadow: [
                                            BoxShadow(
                                              color: colors.positive.withValues(
                                                alpha: .1,
                                              ),
                                              blurRadius: 48,
                                              spreadRadius: 5,
                                            ),
                                          ],
                                        ),
                                        child: BirikioMark(
                                          size: 138,
                                          progress: (t / .78).clamp(0, 1),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 22),
                                Opacity(
                                  opacity: reveal,
                                  child: Transform.translate(
                                    offset: Offset(0, (1 - reveal) * 18),
                                    child: Column(
                                      children: [
                                        const Text(
                                          'Birikio',
                                          style: TextStyle(
                                            fontSize: 44,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -2,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Biriktir. Büyüt. Hayaline ulaş.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                            letterSpacing: .3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 36),
                                if (failed) ...[
                                  const Text(
                                    'Kayıtların açılamadı. Verilerin korunuyor; tekrar deneyebilirsin.',
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  FilledButton(
                                    onPressed: load,
                                    child: const Text('Tekrar dene'),
                                  ),
                                ] else
                                  SizedBox(
                                    width: 56,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: LinearProgressIndicator(
                                        value: ready ? t : null,
                                        minHeight: 3,
                                        color: colors.positive,
                                        backgroundColor: colors.positive
                                            .withValues(alpha: .12),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 22,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Sadece senin cihazında.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
