import 'package:flutter/material.dart';

/// Bigma style B "Bingkai": navy tinted L frame around a white work sheet.
class C {
  static const navy = Color(0xFF0F2A5C);
  static const navy700 = Color(0xFF1C3B73);
  static const navy50 = Color(0xFFEEF2F8);
  static const navy100 = Color(0xFFDFE6F2);
  static const navy200 = Color(0xFFC3D0E6);
  static const navy300 = Color(0xFF9FB1D2);
  static const frame = Color(0xFFE9EEF6);
  static const frameHover = Color(0xFFDDE5F1);
  static const orange = Color(0xFFF26B1D);
  static const orangeInk = Color(0xFFA8460F);
  static const orange50 = Color(0xFFFDEEE3);
  static const ink = Color(0xFF111827);
  static const muted = Color(0xFF596275);
  static const line = Color(0xFFE3E7EF);
  static const rule = Color(0xFFEEF1F6);
  static const ok = Color(0xFF1F7A4D);
  static const okBg = Color(0xFFE1F5EA);
  static const bad = Color(0xFFB4232A);
  static const badBg = Color(0xFFFDECEB);
  static const warnBg = Color(0xFFFFF6E0);
  static const warnInk = Color(0xFF8A5300);
}

/// Course cover art: four navy based gradients, no stock imagery.
const courseArt = <List<Color>>[
  [Color(0xFF0F2A5C), Color(0xFF2B5BA8)],
  [Color(0xFF13385F), Color(0xFF2E8C88)],
  [Color(0xFF2A2F6B), Color(0xFF6A5FC1)],
  [Color(0xFF0F2A5C), Color(0xFFF26B1D)],
];

const _f = 'PlusJakartaSans';

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: _f,
    colorScheme: ColorScheme.fromSeed(seedColor: C.navy, primary: C.navy, secondary: C.orange, surface: Colors.white),
    scaffoldBackgroundColor: C.frame,
  );
  final text = base.textTheme.apply(bodyColor: C.ink, displayColor: C.ink);
  final pill = RoundedRectangleBorder(borderRadius: BorderRadius.circular(999));
  return base.copyWith(
    textTheme: text,
    dividerColor: C.line,
    dividerTheme: const DividerThemeData(color: C.line, space: 1, thickness: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: C.navy,
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFFE5E8EE),
        disabledForegroundColor: const Color(0xFF6B7385),
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        shape: pill,
        textStyle: TextStyle(fontFamily: _f, fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: C.navy,
        backgroundColor: Colors.white,
        side: const BorderSide(color: C.navy200),
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        shape: pill,
        textStyle: TextStyle(fontFamily: _f, fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: C.navy,
        textStyle: TextStyle(fontFamily: _f, fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.navy100)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.navy, width: 1.6)),
      labelStyle: const TextStyle(color: C.muted),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? C.navy : Colors.white),
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? C.navy : C.navy100),
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: C.ink,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}

TextStyle h1(BuildContext c) => TextStyle(fontFamily: _f, fontSize: 24, fontWeight: FontWeight.w700, color: C.ink, height: 1.25);
TextStyle h2(BuildContext c) => TextStyle(fontFamily: _f, fontSize: 18, fontWeight: FontWeight.w700, color: C.ink, height: 1.3);
TextStyle h3(BuildContext c) => TextStyle(fontFamily: _f, fontSize: 15, fontWeight: FontWeight.w700, color: C.ink, height: 1.35);
const muted = TextStyle(color: C.muted);
const small = TextStyle(color: C.muted, fontSize: 12);
const tabular = [FontFeature.tabularFigures()];
