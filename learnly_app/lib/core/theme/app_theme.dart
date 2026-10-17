import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Material 3 theme for Learnly.
///
/// Every colour comes from a [ColorScheme] generated from a single brand seed,
/// plus [StatusColors] for success / warning states that M3 doesn't define.
/// Widgets should read colours via `context.colors` / `context.status` and
/// text styles via `context.text` instead of hardcoding values.
class AppTheme {
  static const Color seed = Color(0xFF4F46E5); // Indigo

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    final status = brightness == Brightness.light
        ? StatusColors.light
        : StatusColors.dark;

    final base = ThemeData(colorScheme: scheme, useMaterial3: true).textTheme;
    final body = GoogleFonts.interTextTheme(base);
    final textTheme = body.copyWith(
      displayLarge: GoogleFonts.outfit(textStyle: base.displayLarge),
      displayMedium: GoogleFonts.outfit(textStyle: base.displayMedium),
      displaySmall: GoogleFonts.outfit(textStyle: base.displaySmall),
      headlineLarge: GoogleFonts.outfit(
        textStyle: base.headlineLarge,
        fontWeight: FontWeight.w600,
      ),
      headlineMedium: GoogleFonts.outfit(
        textStyle: base.headlineMedium,
        fontWeight: FontWeight.w600,
      ),
      headlineSmall: GoogleFonts.outfit(
        textStyle: base.headlineSmall,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: GoogleFonts.outfit(
        textStyle: base.titleLarge,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: body.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: body.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: body.bodyLarge?.copyWith(height: 1.5),
      bodyMedium: body.bodyMedium?.copyWith(height: 1.45),
    );

    const radius12 = BorderRadius.all(Radius.circular(12));
    const buttonPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 14);
    final buttonText = textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: scheme.surface,
      extensions: [status],
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: scheme.surfaceTint,
        scrolledUnderElevation: 3,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: buttonPadding,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: buttonPadding,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(textStyle: buttonText),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        extendedTextStyle: buttonText,
      ),
      chipTheme: ChipThemeData(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: textTheme.labelLarge?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: textTheme.bodyLarge?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        border: const OutlineInputBorder(
          borderRadius: radius12,
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: radius12,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius12,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      searchBarTheme: SearchBarThemeData(
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerHigh),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 12),
        ),
        hintStyle: WidgetStatePropertyAll(
          textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelMedium),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        showDragHandle: true,
        clipBehavior: Clip.antiAlias,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        titleTextStyle: textTheme.bodyLarge?.copyWith(color: scheme.onSurface),
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        linearTrackColor: scheme.surfaceContainerHighest,
        linearMinHeight: 6,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

/// Success / warning roles, shaped like the M3 colour roles they sit beside.
@immutable
class StatusColors extends ThemeExtension<StatusColors> {
  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;
  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color onWarningContainer;

  const StatusColors({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
  });

  static const light = StatusColors(
    success: Color(0xFF006D3B),
    onSuccess: Color(0xFFFFFFFF),
    successContainer: Color(0xFF98F7B5),
    onSuccessContainer: Color(0xFF00210E),
    warning: Color(0xFF7C5800),
    onWarning: Color(0xFFFFFFFF),
    warningContainer: Color(0xFFFFDEA6),
    onWarningContainer: Color(0xFF271900),
  );

  static const dark = StatusColors(
    success: Color(0xFF7CDA9B),
    onSuccess: Color(0xFF00391C),
    successContainer: Color(0xFF00522A),
    onSuccessContainer: Color(0xFF98F7B5),
    warning: Color(0xFFF8BD2A),
    onWarning: Color(0xFF412D00),
    warningContainer: Color(0xFF5E4200),
    onWarningContainer: Color(0xFFFFDEA6),
  );

  @override
  StatusColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? onWarningContainer,
  }) {
    return StatusColors(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
    );
  }

  @override
  StatusColors lerp(StatusColors? other, double t) {
    if (other == null) return this;
    return StatusColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      onSuccessContainer: Color.lerp(
        onSuccessContainer,
        other.onSuccessContainer,
        t,
      )!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      onWarningContainer: Color.lerp(
        onWarningContainer,
        other.onWarningContainer,
        t,
      )!,
    );
  }
}

extension ThemeContext on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
  StatusColors get status {
    final theme = Theme.of(this);
    return theme.extension<StatusColors>() ??
        (theme.brightness == Brightness.light
            ? StatusColors.light
            : StatusColors.dark);
  }
}

/// Semantic colour pairings used by tags, badges and icon chips.
enum Tone { primary, secondary, tertiary, success, warning, error, neutral }

extension ToneColors on Tone {
  /// (container background, content colour on that container)
  (Color, Color) containerPair(BuildContext context) {
    final c = context.colors;
    final s = context.status;
    switch (this) {
      case Tone.primary:
        return (c.primaryContainer, c.onPrimaryContainer);
      case Tone.secondary:
        return (c.secondaryContainer, c.onSecondaryContainer);
      case Tone.tertiary:
        return (c.tertiaryContainer, c.onTertiaryContainer);
      case Tone.success:
        return (s.successContainer, s.onSuccessContainer);
      case Tone.warning:
        return (s.warningContainer, s.onWarningContainer);
      case Tone.error:
        return (c.errorContainer, c.onErrorContainer);
      case Tone.neutral:
        return (c.surfaceContainerHighest, c.onSurfaceVariant);
    }
  }

  /// Solid accent colour for icons / progress on a plain surface.
  Color accent(BuildContext context) {
    final c = context.colors;
    final s = context.status;
    switch (this) {
      case Tone.primary:
        return c.primary;
      case Tone.secondary:
        return c.secondary;
      case Tone.tertiary:
        return c.tertiary;
      case Tone.success:
        return s.success;
      case Tone.warning:
        return s.warning;
      case Tone.error:
        return c.error;
      case Tone.neutral:
        return c.onSurfaceVariant;
    }
  }
}
