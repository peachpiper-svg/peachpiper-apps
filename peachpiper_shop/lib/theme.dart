import 'package:flutter/material.dart';

/// Peach Piper brand – the same colours and type as peachpiper.com
/// (Cormorant Garamond headings, Hanken Grotesk text, wine + coral on cream, thin gold lines).
const wine = Color(0xFF4A1823);
const wineSoft = Color(0xFF6E3A44);
const coral = Color(0xFFFF767C);
const coralDark = Color(0xFFE85A62);
const blush = Color(0xFFFFF0EE);
const cream = Color(0xFFFFFBF8);
const sand = Color(0xFFF5EBDA);
const gold = Color(0xFFB8893A);
const goldSoft = Color(0xFFE9D3A8);
const ink = Color(0xFF2B1419);
const muted = Color(0xFF8B7275);
const line = Color(0xFFEEDDD8);
const emerald = Color(0xFF1E6B4E);

const kSerif = 'Cormorant';
const kSans = 'Hanken';

TextStyle serif(double size, {FontWeight weight = FontWeight.w600, Color color = wine, bool italic = false, double height = 1.1}) =>
    TextStyle(fontFamily: kSerif, fontSize: size, fontWeight: weight, color: color, fontStyle: italic ? FontStyle.italic : FontStyle.normal, height: height);

TextStyle sans(double size, {FontWeight weight = FontWeight.w500, Color color = ink, double height = 1.35, double spacing = 0}) =>
    TextStyle(fontFamily: kSans, fontSize: size, fontWeight: weight, color: color, height: height, letterSpacing: spacing);

/// small uppercase label above a heading ("NEW FESTIVE COLLECTION")
TextStyle kicker({Color color = gold, double size = 11}) => TextStyle(fontFamily: kSans, fontSize: size, letterSpacing: 1.8, fontWeight: FontWeight.w700, color: color);

ThemeData ppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: kSans,
    colorScheme: ColorScheme.fromSeed(seedColor: wine, primary: wine, secondary: coral, surface: Colors.white, brightness: Brightness.light),
  );
  final btnText = const TextStyle(fontFamily: kSans, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1.2);
  final r6 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(6));
  return base.copyWith(
    scaffoldBackgroundColor: cream,
    textTheme: base.textTheme.apply(fontFamily: kSans, bodyColor: ink, displayColor: wine),
    appBarTheme: AppBarTheme(
      backgroundColor: cream,
      foregroundColor: wine,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      titleTextStyle: serif(24),
      iconTheme: const IconThemeData(color: wine),
    ),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(backgroundColor: wine, foregroundColor: cream, disabledBackgroundColor: line, minimumSize: const Size(48, 52), shape: r6, textStyle: btnText)),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(foregroundColor: wine, minimumSize: const Size(48, 52), side: const BorderSide(color: wine, width: 1.2), shape: r6, textStyle: btnText)),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: wine, textStyle: const TextStyle(fontFamily: kSans, fontWeight: FontWeight.w700))),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      labelStyle: sans(14, color: muted),
      hintStyle: sans(14, color: muted),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: wine, width: 1.4)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: Colors.white,
      selectedColor: wine,
      side: const BorderSide(color: line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      labelStyle: sans(13, weight: FontWeight.w600, color: wine),
      secondaryLabelStyle: sans(13, weight: FontWeight.w600, color: cream),
      checkmarkColor: cream,
    ),
    dividerTheme: const DividerThemeData(color: line, thickness: 1, space: 1),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: wine,
      contentTextStyle: sans(14, color: cream, weight: FontWeight.w600),
      actionTextColor: coral,
      behavior: SnackBarBehavior.floating,
      shape: r6,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: cream,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: line,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    ),
    expansionTileTheme: const ExpansionTileThemeData(
      shape: Border(),
      collapsedShape: Border(),
      iconColor: wine,
      collapsedIconColor: wine,
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.only(bottom: 14),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: wine),
    dialogTheme: DialogThemeData(backgroundColor: cream, surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), titleTextStyle: serif(24)),
  );
}

/// thin gold line with a small diamond in the middle – the ornament used across the website
class Ornament extends StatelessWidget {
  final double width;
  final Color color;
  const Ornament({super.key, this.width = 110, this.color = gold});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Row(children: [
        Expanded(child: Container(height: 1, color: color.withValues(alpha: .7))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Transform.rotate(angle: 0.785398, child: Container(width: 6, height: 6, decoration: BoxDecoration(border: Border.all(color: color, width: 1)))),
        ),
        Expanded(child: Container(height: 1, color: color.withValues(alpha: .7))),
      ]),
    );
  }
}

/// section heading: optional kicker, serif title, ornament, optional "View all"
class SectionTitle extends StatelessWidget {
  final String title;
  final String? kickerText;
  final VoidCallback? onAll;
  final EdgeInsets padding;
  const SectionTitle(this.title, {super.key, this.kickerText, this.onAll, this.padding = const EdgeInsets.fromLTRB(18, 34, 18, 16)});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(children: [
        if (kickerText != null && kickerText!.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(kickerText!.toUpperCase(), style: kicker())),
        Text(title, textAlign: TextAlign.center, style: serif(30)),
        const SizedBox(height: 10),
        const Ornament(),
        if (onAll != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: InkWell(
              onTap: onAll,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: Text('VIEW ALL', style: kicker(color: wineSoft, size: 11).copyWith(decoration: TextDecoration.underline, decorationColor: goldSoft)),
              ),
            ),
          ),
      ]),
    );
  }
}
