import 'package:flutter/material.dart';

/// Colori del branco: bosco di notte, giallo lupetto, cielo da campo.
class Palette {
  Palette._();
  static const bosco = Color(0xFF17402F);
  static const boscoNotte = Color(0xFF0E2A1F);
  static const prato = Color(0xFF2E7D4F);
  static const giallo = Color(0xFFF2B418);
  static const cielo = Color(0xFF2F6FA3);
  static const brace = Color(0xFFC4452D);
  static const carta = Color(0xFFF1F5EA);
  static const tela = Color(0xFFF4E7BC);
}

ColorScheme _schemaChiaro() => const ColorScheme(
      brightness: Brightness.light,
      primary: Palette.prato,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFD3E8D0),
      onPrimaryContainer: Palette.boscoNotte,
      secondary: Palette.giallo,
      onSecondary: Color(0xFF2A2000),
      secondaryContainer: Color(0xFFFFE7A3),
      onSecondaryContainer: Color(0xFF3B2D00),
      tertiary: Palette.cielo,
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFD5E6F5),
      onTertiaryContainer: Color(0xFF0B2D4A),
      error: Palette.brace,
      onError: Colors.white,
      errorContainer: Color(0xFFFBDAD3),
      onErrorContainer: Color(0xFF5A1409),
      surface: Palette.carta,
      onSurface: Color(0xFF17261E),
      onSurfaceVariant: Color(0xFF4A5A50),
      outline: Color(0xFF7D8F82),
      outlineVariant: Color(0xFFCBD6C5),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Color(0xFFF7F9F2),
      surfaceContainer: Color(0xFFEAF0E2),
      surfaceContainerHigh: Color(0xFFE1E9D8),
      surfaceContainerHighest: Color(0xFFD8E2CE),
      inverseSurface: Palette.bosco,
      onInverseSurface: Color(0xFFEAF4E8),
    );

ColorScheme _schemaScuro() => const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFF86D5A5),
      onPrimary: Color(0xFF003822),
      primaryContainer: Color(0xFF1F5E43),
      onPrimaryContainer: Color(0xFFD3EEDB),
      secondary: Palette.giallo,
      onSecondary: Color(0xFF2A2000),
      secondaryContainer: Color(0xFF5A4300),
      onSecondaryContainer: Color(0xFFFFE7A3),
      tertiary: Color(0xFF9CC7EA),
      onTertiary: Color(0xFF0B2D4A),
      tertiaryContainer: Color(0xFF1B4B73),
      onTertiaryContainer: Color(0xFFD5E6F5),
      error: Color(0xFFFF8F7C),
      onError: Color(0xFF4A0E05),
      errorContainer: Color(0xFF7A2415),
      onErrorContainer: Color(0xFFFBDAD3),
      surface: Color(0xFF0F1D16),
      onSurface: Color(0xFFE3EDE2),
      onSurfaceVariant: Color(0xFFB4C4B8),
      outline: Color(0xFF7F9486),
      outlineVariant: Color(0xFF2E4237),
      surfaceContainerLowest: Color(0xFF0A1510),
      surfaceContainerLow: Color(0xFF14241B),
      surfaceContainer: Color(0xFF182A20),
      surfaceContainerHigh: Color(0xFF1E3227),
      surfaceContainerHighest: Color(0xFF263C30),
      inverseSurface: Color(0xFFE3EDE2),
      onInverseSurface: Palette.bosco,
    );

TextTheme _testi(TextTheme t) {
  TextStyle? f(TextStyle? s, FontWeight w, {double? spacing, double? height}) =>
      s?.copyWith(fontWeight: w, letterSpacing: spacing, height: height);
  return t.copyWith(
    headlineLarge: f(t.headlineLarge, FontWeight.w800, spacing: -0.6, height: 1.1),
    headlineMedium: f(t.headlineMedium, FontWeight.w800, spacing: -0.5, height: 1.1),
    headlineSmall: f(t.headlineSmall, FontWeight.w800, spacing: -0.3, height: 1.15),
    titleLarge: f(t.titleLarge, FontWeight.w800, spacing: -0.2),
    titleMedium: f(t.titleMedium, FontWeight.w700),
    titleSmall: f(t.titleSmall, FontWeight.w700),
    labelLarge: f(t.labelLarge, FontWeight.w700),
    labelMedium: f(t.labelMedium, FontWeight.w600),
    bodyLarge: f(t.bodyLarge, FontWeight.w500, height: 1.35),
    bodyMedium: f(t.bodyMedium, FontWeight.w400, height: 1.35),
  );
}

ThemeData costruisciTema(Brightness b) {
  final s = b == Brightness.light ? _schemaChiaro() : _schemaScuro();
  final base = ThemeData(colorScheme: s, useMaterial3: true);
  final bordo = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
  return base.copyWith(
    scaffoldBackgroundColor: s.surface,
    textTheme: _testi(base.textTheme),
    appBarTheme: AppBarTheme(
      backgroundColor: s.surface,
      foregroundColor: s.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: _testi(base.textTheme).titleLarge?.copyWith(color: s.onSurface),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: s.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: s.outlineVariant),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      backgroundColor: s.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      indicatorColor: b == Brightness.light ? Palette.giallo : s.secondaryContainer,
      indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: s.onSurface),
      ),
      iconTheme: WidgetStateProperty.resolveWith((st) => IconThemeData(
            color: st.contains(WidgetState.selected)
                ? (b == Brightness.light ? Palette.boscoNotte : s.onSecondaryContainer)
                : s.onSurfaceVariant,
          )),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: bordo,
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: bordo,
        side: BorderSide(color: s.outline),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(textStyle: const TextStyle(fontWeight: FontWeight.w700)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: Palette.giallo,
      foregroundColor: const Color(0xFF2A2000),
      elevation: 2,
      extendedTextStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: s.surfaceContainerLowest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: s.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: s.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: s.primary, width: 2),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      side: BorderSide(color: s.outlineVariant),
      selectedColor: s.secondaryContainer,
      backgroundColor: s.surfaceContainerLowest,
      labelStyle: TextStyle(fontWeight: FontWeight.w600, color: s.onSurface),
      checkmarkColor: s.onSecondaryContainer,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
            (st) => st.contains(WidgetState.selected) ? s.primary : s.surfaceContainerLowest),
        foregroundColor: WidgetStateProperty.resolveWith(
            (st) => st.contains(WidgetState.selected) ? s.onPrimary : s.onSurface),
        side: WidgetStatePropertyAll(BorderSide(color: s.outlineVariant)),
        textStyle: const WidgetStatePropertyAll(TextStyle(fontWeight: FontWeight.w700)),
      ),
    ),
    searchBarTheme: SearchBarThemeData(
      elevation: const WidgetStatePropertyAll(0),
      backgroundColor: WidgetStatePropertyAll(s.surfaceContainerLowest),
      side: WidgetStatePropertyAll(BorderSide(color: s.outlineVariant)),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Palette.bosco,
      contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: s.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: s.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    dividerTheme: DividerThemeData(color: s.outlineVariant, space: 1),
    expansionTileTheme: const ExpansionTileThemeData(
      shape: Border(),
      collapsedShape: Border(),
    ),
  );
}
