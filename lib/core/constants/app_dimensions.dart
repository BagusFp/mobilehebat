import 'package:flutter/material.dart';

/// Skala Spacing & Radius resmi dari Google Stitch Design Tokens
abstract class AppDimensions {
  // Spacing
  static const double spaceXs = 4.0;
  static const double spaceSm = 8.0;
  static const double spaceMd = 16.0;
  static const double spaceLg = 24.0;
  static const double spaceXl = 32.0;
  static const double space2Xl = 48.0;

  // Margin & Padding Standar
  static const double margin = 20.0;
  static const double gutter = 16.0;
  static const EdgeInsets pagePadding = EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0);
  static const EdgeInsets cardPadding = EdgeInsets.all(16.0);
  static const EdgeInsets horizontalPagePadding = EdgeInsets.symmetric(horizontal: 20.0);

  // Border Radius
  static const double radiusXs = 4.0;
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 24.0;
  static const double radiusFull = 999.0;

  static const BorderRadius roundedSm = BorderRadius.all(Radius.circular(radiusSm));
  static const BorderRadius roundedMd = BorderRadius.all(Radius.circular(radiusMd));
  static const BorderRadius roundedLg = BorderRadius.all(Radius.circular(radiusLg));
  static const BorderRadius roundedXl = BorderRadius.all(Radius.circular(radiusXl));
  static const BorderRadius roundedFull = BorderRadius.all(Radius.circular(radiusFull));

  // Ketinggian Tombol & Input
  static const double buttonHeight = 52.0;
  static const double inputHeight = 52.0;
  static const double iconSizeSm = 16.0;
  static const double iconSizeMd = 20.0;
  static const double iconSizeLg = 24.0;
  static const double iconSizeXl = 32.0;
}
