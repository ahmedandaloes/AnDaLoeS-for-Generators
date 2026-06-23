import 'package:flutter/material.dart';

class AppTheme {
  // "Premium B2B / Trust" design language: a confident blue conveys trust
  // (primary), green signals verified / energy / success (secondary). Light,
  // professional, data-forward surfaces.
  static const Color _primary = Color(0xFF1D4ED8); // blue-700 — trust
  static const Color _verified = Color(0xFF15803D); // green-700 — verified/energy

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _primary,
      brightness: Brightness.light,
    ).copyWith(
      secondary: _verified,
      tertiary: _verified,
    );
    return _base(scheme);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _primary,
      brightness: Brightness.dark,
    ).copyWith(
      secondary: const Color(0xFF22C55E),
      tertiary: const Color(0xFF22C55E),
    );
    return _base(scheme);
  }

  static ThemeData _base(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    // Cool, professional light grey (B2B procurement feel), not a tinted one.
    final scaffold = isDark ? scheme.surface : const Color(0xFFF4F6FA);
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: scaffold,
      // Kill Material 3's primary-colored tint on elevated surfaces so cards,
      // app bars and sheets stay crisp and neutral instead of muddy/green.
      textTheme: _textTheme(scheme),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        backgroundColor: scaffold,
        foregroundColor: scheme.onSurface,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: isDark ? scheme.surfaceContainerHigh : Colors.white,
        clipBehavior: Clip.antiAlias,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          side: BorderSide(color: scheme.outline.withValues(alpha: 0.4)),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? scheme.surfaceContainerHighest
            : scheme.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        prefixIconColor: WidgetStateColor.resolveWith((states) {
          if (states.contains(WidgetState.focused)) return scheme.primary;
          return scheme.onSurfaceVariant;
        }),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.5),
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      // Floating, dark, rounded snackbars — clean and out of the way.
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 2,
        backgroundColor: isDark ? scheme.surfaceContainerHighest : scheme.inverseSurface,
        contentTextStyle: TextStyle(
          color: isDark ? scheme.onSurface : scheme.onInverseSurface,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      // Clean bottom sheets: rounded top, no surface tint, hairline barrier.
      bottomSheetTheme: BottomSheetThemeData(
        surfaceTintColor: Colors.transparent,
        backgroundColor: isDark ? scheme.surfaceContainerLow : Colors.white,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dialogTheme: DialogThemeData(
        surfaceTintColor: Colors.transparent,
        backgroundColor: isDark ? scheme.surfaceContainerHigh : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  // A deliberate, restrained type scale: bold tight-tracked headings for
  // hierarchy, calm readable body — the backbone of a clean, Uber-grade look.
  static TextTheme _textTheme(ColorScheme scheme) {
    final onSurface = scheme.onSurface;
    final muted = scheme.onSurfaceVariant;
    return TextTheme(
      headlineLarge: TextStyle(
        fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: onSurface),
      headlineMedium: TextStyle(
        fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: onSurface),
      titleLarge: TextStyle(
        fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: onSurface),
      titleMedium: TextStyle(
        fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: onSurface),
      bodyLarge: TextStyle(
        fontSize: 15, fontWeight: FontWeight.w400, height: 1.4, color: onSurface),
      bodyMedium: TextStyle(
        fontSize: 14, fontWeight: FontWeight.w400, height: 1.4, color: onSurface),
      bodySmall: TextStyle(
        fontSize: 12.5, fontWeight: FontWeight.w400, height: 1.35, color: muted),
      labelLarge: TextStyle(
        fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1, color: onSurface),
    );
  }
}
