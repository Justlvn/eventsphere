import 'package:flutter/material.dart';

// ─── Palette (réf. maquettes clair / sombre) ─────────────────────────────────

abstract final class AppColors {
  /// Violet principal (#5038ED).
  static const primary = Color(0xFF5038ED);

  /// Fonds violet très clair / pastels.
  static const lightPurple = Color(0xFFE8EAFE);

  /// En-tête tableau de bord (dark).
  static const homeHeaderDark = Color(0xFF222455);

  /// Accent navigation / primaire en dark (#7B61FF — proche maquette).
  static const primaryDark = Color(0xFF7B61FF);

  /// États & catégories.
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF97316);
  static const textMuted = Color(0xFF6B7280);
  static const textMutedDark = Color(0xFF8E9AAF);

  /// Dégradé auth / headers secondaires.
  static const gradientStart = Color(0xFF5038ED);
  static const gradientEnd = Color(0xFF7B61FF);

  /// Couleurs par catégorie d'événement.
  static const soiree = Color(0xFF5038ED);
  static const afterwork = Color(0xFFF97316);
  static const journee = Color(0xFF10B981);
  static const venteNourriture = Color(0xFFEF4444);
  static const sport = Color(0xFF10B981);
  static const culture = Color(0xFFEC4899);
  static const concert = Color(0xFFA855F7);
}

// ─── Ombres ─────────────────────────────────────────────────────────────────

abstract final class AppShadows {
  static final card = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.03),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> cardFor(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.45),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];
    }
    return card;
  }
}

// ─── Thème ──────────────────────────────────────────────────────────────────

abstract final class AppTheme {
  static ThemeData light() =>
      _build(brightness: Brightness.light, colorScheme: _lightScheme);

  static ThemeData dark() =>
      _build(brightness: Brightness.dark, colorScheme: _darkScheme);

  static final ColorScheme _lightScheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    surface: Colors.white,
    onSurface: const Color(0xFF111827),
    onSurfaceVariant: AppColors.textMuted,
    surfaceContainerHighest: const Color(0xFFF3F4F6),
    outlineVariant: const Color(0xFFE5E7EB),
  );

  static final ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.primaryDark,
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFF2D2659),
    onPrimaryContainer: const Color(0xFFE8E0FF),
    secondary: const Color(0xFF00C896),
    onSecondary: const Color(0xFF001A14),
    secondaryContainer: const Color(0xFF003D30),
    onSecondaryContainer: const Color(0xFF8FF5D4),
    tertiary: AppColors.primaryDark,
    onTertiary: Colors.white,
    error: const Color(0xFFF87171),
    onError: const Color(0xFF1F0707),
    errorContainer: const Color(0xFF5C1F1F),
    onErrorContainer: const Color(0xFFFFD4D4),
    surface: const Color(0xFF151B2D),
    onSurface: Colors.white,
    onSurfaceVariant: AppColors.textMutedDark,
    outline: const Color(0xFF3D4A63),
    outlineVariant: const Color(0xFF252F45),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: const Color(0xFFE8ECF5),
    onInverseSurface: const Color(0xFF151B2D),
    inversePrimary: AppColors.primary,
    surfaceTint: Colors.transparent,
  );

  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme colorScheme,
  }) {
    final isLight = brightness == Brightness.light;
    final scaffoldBg =
        isLight ? const Color(0xFFF9FAFB) : const Color(0xFF0A0E1A);

    final inputFillAlpha = isLight ? 0.5 : 0.42;
    final navShadowAlpha = isLight ? 0.06 : 0.0;

    final base = ThemeData(
      colorScheme: colorScheme,
      brightness: brightness,
      useMaterial3: true,
    );
    final t = base.textTheme;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBg,

      textTheme: t.copyWith(
        displayLarge: t.displayLarge?.copyWith(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        headlineLarge: t.headlineLarge?.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        headlineMedium: t.headlineMedium?.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        headlineSmall: t.headlineSmall?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        titleLarge: t.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        titleMedium: t.titleMedium?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
        ),
        titleSmall: t.titleSmall?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: t.bodyLarge?.copyWith(fontSize: 16, height: 1.5),
        bodyMedium: t.bodyMedium?.copyWith(fontSize: 14, height: 1.5),
        bodySmall: t.bodySmall?.copyWith(fontSize: 12, height: 1.4),
        labelLarge: t.labelLarge?.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
        labelSmall: t.labelSmall?.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
        ),
      ),

      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        backgroundColor: isLight ? Colors.white : scaffoldBg,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        shadowColor: Colors.transparent,
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight
            ? colorScheme.surfaceContainerHighest
                .withValues(alpha: inputFillAlpha)
            : const Color(0xFF1C2438),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: isLight
              ? BorderSide.none
              : BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.95),
                  width: 1,
                ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: isLight
              ? BorderSide.none
              : BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.95),
                  width: 1,
                ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isLight ? AppColors.primary : colorScheme.primary,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.error, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        prefixIconColor: WidgetStateColor.resolveWith((states) {
          if (states.contains(WidgetState.focused)) {
            return colorScheme.primary;
          }
          return colorScheme.onSurfaceVariant;
        }),
      ),

      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        elevation: 0,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: navShadowAlpha),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor:
            AppColors.primary.withValues(alpha: isLight ? 0.12 : 0.22),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final accent = isLight ? AppColors.primary : colorScheme.primary;
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: accent, size: 22);
          }
          return IconThemeData(
            color: colorScheme.onSurfaceVariant,
            size: 22,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final accent = isLight ? AppColors.primary : colorScheme.primary;
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: accent,
            );
          }
          return TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurfaceVariant,
          );
        }),
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
            letterSpacing: 0.1,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return isLight ? AppColors.primary : colorScheme.primary;
          }
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            final c = isLight ? AppColors.primary : colorScheme.primary;
            return c.withValues(alpha: 0.38);
          }
          return null;
        }),
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
