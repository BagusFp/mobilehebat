import 'package:flutter/material.dart';

/// Palet warna resmi MeraTrip yang diekstrak langsung dari Google Stitch Design System
/// Tema: Nature Adventure & Volcanic Eco-Tourism
abstract class AppColors {
  // Brand & Primary
  static const Color primary = Color(0xFF04432F); // Deep Forest Pine Green
  static const Color primaryContainer = Color(0xFF245B45); // Slate Forest Green
  static const Color primaryFixed = Color(0xFFB5EFD2);
  static const Color primaryFixedDim = Color(0xFF9AD3B7);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFF98D1B5);

  // Secondary & Accents
  static const Color secondary = Color(0xFF48663D); // Moss / Fern Green
  static const Color secondaryContainer = Color(0xFFC9EDB8);
  static const Color secondaryFixed = Color(0xFFC9EDB8);
  static const Color secondaryFixedDim = Color(0xFFAED09E);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color onSecondaryContainer = Color(0xFF4E6C43);
  static const Color onSecondaryFixed = Color(0xFF062102);

  // Tertiary
  static const Color tertiary = Color(0xFF353C32);
  static const Color tertiaryContainer = Color(0xFF4C5349);
  static const Color tertiaryFixed = Color(0xFFDEE5D7);
  static const Color onTertiary = Color(0xFFFFFFFF);

  // Background & Surfaces
  static const Color background = Color(0xFFEAFEF0); // Pale Mint Mist
  static const Color onBackground = Color(0xFF0E1F17); // Deep Pine Charcoal
  static const Color surface = Color(0xFFEAFEF0);
  static const Color surfaceVariant = Color(0xFFD3E7DA);
  static const Color onSurface = Color(0xFF0E1F17);
  static const Color onSurfaceVariant = Color(0xFF404944); // Muted Sage Grey

  // Surface Containers (Hierarki Card & Sheet)
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF); // Card putih bersih
  static const Color surfaceContainerLow = Color(0xFFE4F9EB);
  static const Color surfaceContainer = Color(0xFFDFF3E5); // Standar container
  static const Color surfaceContainerHigh = Color(0xFFD9EDDF);
  static const Color surfaceContainerHighest = Color(0xFFD3E7DA); // Input field background

  // Borders & Outlines
  static const Color outline = Color(0xFF707973);
  static const Color outlineVariant = Color(0xFFC0C9C2);

  // Status & Indikator Alam
  static const Color volcanoStatusWaspada = Color(0xFFD97706); // Amber Siaga Level II
  static const Color volcanoStatusWaspadaBg = Color(0xFFFEF3C7);
  static const Color safeRadius = Color(0xFF16A34A); // Hijau Zona Aman >3 km
  static const Color safeRadiusBg = Color(0xFFDCFCE7);

  // Functional States
  static const Color success = Color(0xFF15803D);
  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);
  static const Color warning = Color(0xFFB45309);
  static const Color info = Color(0xFF0284C7);
  static const Color offline = Color(0xFF475569);
  static const Color offlineBg = Color(0xFFE2E8F0);
}
