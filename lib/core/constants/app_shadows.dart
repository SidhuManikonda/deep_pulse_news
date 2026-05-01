import 'package:flutter/material.dart';

/// Elevation-based shadow tokens as a ThemeData extension.
/// Usage: Theme.of(context).shadowSm
extension AppShadowsExtension on ThemeData {
  /// Subtle — cards, input fields
  List<BoxShadow> get shadowSm => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  /// Medium — modals, dropdowns, bottom bars
  List<BoxShadow> get shadowMd => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  /// Strong — floating panels, drawers
  List<BoxShadow> get shadowLg => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.12),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  /// Upward — bottom sheets, input bars that sit above content
  List<BoxShadow> get shadowUp => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 10,
      offset: const Offset(0, -2),
    ),
  ];
}
