import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Tipografi resmi MeraTrip: Plus Jakarta Sans untuk judul & Inter untuk body text
abstract class AppTypography {
  // Headlines (Plus Jakarta Sans)
  static TextStyle displayLarge = GoogleFonts.plusJakartaSans(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    color: AppColors.onSurface,
    letterSpacing: -0.5,
  );

  static TextStyle headlineLarge = GoogleFonts.plusJakartaSans(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.onSurface,
    letterSpacing: -0.3,
  );

  static TextStyle headlineMedium = GoogleFonts.plusJakartaSans(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.onSurface,
  );

  static TextStyle headlineSmall = GoogleFonts.plusJakartaSans(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.onSurface,
  );

  // Titles
  static TextStyle titleLarge = GoogleFonts.plusJakartaSans(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.onSurface,
  );

  static TextStyle titleMedium = GoogleFonts.plusJakartaSans(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.onSurface,
  );

  static TextStyle titleSmall = GoogleFonts.plusJakartaSans(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.onSurface,
  );

  // Body Text (Inter)
  static TextStyle bodyLarge = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.onSurface,
    height: 1.5,
  );

  static TextStyle bodyMedium = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.onSurfaceVariant,
    height: 1.45,
  );

  static TextStyle bodySmall = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.onSurfaceVariant,
    height: 1.4,
  );

  // Labels & Badges
  static TextStyle labelLarge = GoogleFonts.plusJakartaSans(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: AppColors.onPrimary,
  );

  static TextStyle labelMedium = GoogleFonts.plusJakartaSans(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.onSurface,
  );

  static TextStyle labelSmall = GoogleFonts.plusJakartaSans(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
  );

  // Google Stitch Design Tokens Aliases
  static TextStyle get headlineLg => headlineLarge;
  static TextStyle get headlineMd => headlineMedium;
  static TextStyle get headlineSm => headlineSmall;
  static TextStyle get titleLg => titleLarge;
  static TextStyle get titleMd => titleMedium;
  static TextStyle get titleSm => titleSmall;
  static TextStyle get bodyLg => bodyLarge;
  static TextStyle get bodyMd => bodyMedium;
  static TextStyle get bodySm => bodySmall;
  static TextStyle get labelLg => labelLarge;
  static TextStyle get labelMd => labelMedium;
  static TextStyle get labelSm => labelSmall;
}
