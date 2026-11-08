import 'package:flutter/material.dart';

const _seed = Color(0xFF1F4E8C); // a deep academic blue

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: brightness == Brightness.light
        ? const Color(0xFFF4F6FA)
        : scheme.surface,
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLowest,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
    ),
    chipTheme: const ChipThemeData(showCheckmark: false),
    appBarTheme: const AppBarTheme(centerTitle: false),
  );
}

/// Colors for deadline urgency, readable in light and dark mode.
class UrgencyColors {
  const UrgencyColors(this.background, this.foreground);

  final Color background;
  final Color foreground;

  static UrgencyColors of(BuildContext context, {int? daysLeft}) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    if (daysLeft == null) {
      return UrgencyColors(
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      );
    }
    if (daysLeft < 0) {
      return UrgencyColors(
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      );
    }
    if (daysLeft <= 7) {
      return dark
          ? const UrgencyColors(Color(0xFF5C1A1A), Color(0xFFFFB4AB))
          : const UrgencyColors(Color(0xFFFFE1DD), Color(0xFF9C1C12));
    }
    if (daysLeft <= 21) {
      return dark
          ? const UrgencyColors(Color(0xFF4D3A00), Color(0xFFFFD877))
          : const UrgencyColors(Color(0xFFFFF0C2), Color(0xFF7A5300));
    }
    return dark
        ? const UrgencyColors(Color(0xFF113D24), Color(0xFF8EDBA8))
        : const UrgencyColors(Color(0xFFDDF4E4), Color(0xFF14653A));
  }
}
