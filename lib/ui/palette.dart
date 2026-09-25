import 'package:flutter/material.dart';

/// Semantic colors stay legible on both pale and dark surfaces.
class FinanceColors {
  final bool dark;
  const FinanceColors(this.dark);
  Color get positive =>
      dark ? const Color(0xFF70E5BC) : const Color(0xFF087653);
  Color get negative =>
      dark ? const Color(0xFFFF7D8C) : const Color(0xFFB42E48);
  Color get accent => dark ? const Color(0xFFB9A3FF) : const Color(0xFF6844B3);
  Color get gold => dark ? const Color(0xFFFFD780) : const Color(0xFF936000);
  Color get onAccent => dark ? const Color(0xFF101522) : Colors.white;
  Color get goalText =>
      dark ? const Color(0xFFF3EEFF) : const Color(0xFF292039);
  Color get goalMuted =>
      dark ? const Color(0xFFBDB4D1) : const Color(0xFF655876);
  List<Color> get goalBackground => dark
      ? const [Color(0xFF302747), Color(0xFF1B2539)]
      : const [Color(0xFFF0E9FF), Color(0xFFF9F7FF)];
  List<Color> get completedBackground => dark
      ? const [Color(0xFF173B32), Color(0xFF14282A)]
      : const [Color(0xFFE1F5E9), Color(0xFFF4FBF6)];
  Color get completedText =>
      dark ? const Color(0xFFE7FFF1) : const Color(0xFF173B2B);
  Color get completedMuted =>
      dark ? const Color(0xFFADCFBD) : const Color(0xFF426653);
}

FinanceColors financeColors(BuildContext context) =>
    FinanceColors(Theme.of(context).brightness == Brightness.dark);
