import 'package:flutter/material.dart';

/// Extension on ThemeData to provide theme-aware colors
/// Usage: Theme.of(context).appPrimary
extension AppColorsExtension on ThemeData {
  bool get _isLight => brightness == Brightness.light;

  // Primary Colors (same for both themes)
  Color get appPrimary => const Color(0xFFC62828);
  Color get appPrimaryDark => const Color(0xFFC53030);
  Color get appPrimaryLight => const Color(0xFFFC8181);

  // Background Colors (theme-aware)
  Color get appBackground =>
      _isLight ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
  Color get appSurface =>
      _isLight ? const Color(0xFFF7FAFC) : const Color(0xFF1A1A1A);

  // Text Colors (theme-aware)
  Color get appTextPrimary =>
      _isLight ? const Color(0xFF2D3748) : const Color(0xFFFFFFFF);
  Color get appTextSecondary =>
      _isLight ? const Color(0xFF718096) : const Color(0xFFA0AEC0);
  Color get appTextLight =>
      _isLight ? const Color(0xFFA0AEC0) : const Color(0xFF718096);
  Color get appTextWhite => const Color(0xFFFFFFFF);

  // Additional Text Colors (theme-aware)
  Color get appTextHeader => appTextPrimary;
  Color get appTextBody => appTextSecondary;
  Color get appTextCaption => appTextLight;

  // Error Colors (theme-aware variants)
  Color get appErrorLight => const Color(0xFFFC8181);
  Color get appErrorMedium => const Color(0xFFF56565);

  // Selection Colors (theme-aware)
  Color get appSelectionPrimary => const Color(0xFF2196F3);
  Color get appSelectionBackground => appSelectionPrimary.withOpacity(0.1);

  // Category Colors (same for both themes)
  Color get appTrending => const Color(0xFFE53E3E);
  Color get appSports => const Color(0xFF38A169);
  Color get appPolitics => const Color(0xFF3182CE);
  Color get appEntertainment => const Color(0xFF9F7AEA);
  Color get appTechnology => const Color(0xFF00B5D8);
  Color get appBusiness => const Color(0xFFD69E2E);
  Color get appHealth => const Color(0xFFFF6B6B);
  Color get appLifestyle => const Color(0xFFED8936);

  // Neutral Colors (theme-aware)
  Color get appGrey50 =>
      _isLight ? const Color(0xFFF9FAFB) : const Color(0xFF111827);
  Color get appGrey100 =>
      _isLight ? const Color(0xFFF3F4F6) : const Color(0xFF1F2937);
  Color get appGrey200 =>
      _isLight ? const Color(0xFFE5E7EB) : const Color(0xFF374151);
  Color get appGrey300 =>
      _isLight ? const Color(0xFFD1D5DB) : const Color(0xFF4B5563);
  Color get appGrey400 =>
      _isLight ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
  Color get appGrey500 => const Color(0xFF6B7280);
  Color get appGrey600 =>
      _isLight ? const Color(0xFF4B5563) : const Color(0xFF9CA3AF);
  Color get appGrey700 =>
      _isLight ? const Color(0xFF374151) : const Color(0xFFD1D5DB);
  Color get appGrey800 =>
      _isLight ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB);
  Color get appGrey900 =>
      _isLight ? const Color(0xFF111827) : const Color(0xFFF3F4F6);

  // Bottom Navigation Bar Colors (theme-aware)
  Color get appBottomNavSelected =>
      _isLight ? const Color(0xFFE53E3E) : const Color(0xFFE53E3E);
  Color get appBottomNavUnselected =>
      _isLight ? const Color(0xFF718096) : const Color(0xFFA0AEC0);

  // Card Colors (theme-aware)
  Color get appCard => _isLight ? const Color(0xFFF7FAFC) : const Color(0xFF1A1A1A);

  // Shimmer Colors (theme-aware)
  Color get shimmerBaseColor =>
      _isLight ? const Color(0xFFE5E7EB) : const Color(0xFF374151);
  Color get shimmerHighlightColor =>
      _isLight ? const Color(0xFFF3F4F6) : const Color(0xFF4B5563);
  Color get selectedLanguageColor =>
      _isLight ? const Color(0xFF2196F3) : const Color(0xFF2196F3);

  // Divider Colors (theme-aware)
  Color get appDivider => _isLight ? const Color(0xFFE5E7EB) : const Color(0xFF4B5563);
}

//------------------------------------------------------------------------------
// Light Theme Color Constants
//------------------------------------------------------------------------------
const Color appPrimaryLightColor = Color(0xFFE53E3E);
const Color appPrimaryDarkLightColor = Color(0xFFC53030);
const Color appPrimaryLightLightColor = Color(0xFFFC8181);
const Color appBackgroundLightColor = Color(0xFFFFFFFF);
const Color appSurfaceLightColor = Color(0xFFF7FAFC);
const Color appTextPrimaryLightColor = Color(0xFF2D3748);
const Color appTextSecondaryLightColor = Color(0xFF718096);
const Color appTextLightLightColor = Color(0xFFA0AEC0);
const Color appTextWhiteColor = Color(0xFFFFFFFF);
const Color appTextHeaderLightColor = Color(0xFF2D3748);
const Color appTextBodyLightColor = Color(0xFF718096);
const Color appTextCaptionLightColor = Color(0xFFA0AEC0);
const Color appErrorColor = Color(0xFFE53E3E);
const Color appInfoColor = Color(0xFF3182CE);
const Color appErrorLightColor = Color(0xFFFC8181);
const Color appErrorMediumColor = Color(0xFFF56565);
const Color appSelectionPrimaryColor = Color(0xFF2196F3);
const Color appGrey50LightColor = Color(0xFFF9FAFB);
const Color appGrey100LightColor = Color(0xFFF3F4F6);
const Color appGrey200LightColor = Color(0xFFE5E7EB);
const Color appGrey300LightColor = Color(0xFFD1D5DB);
const Color appGrey400LightColor = Color(0xFF9CA3AF);
const Color appGrey500Color = Color(0xFF6B7280);
const Color appGrey600LightColor = Color(0xFF4B5563);
const Color appGrey700LightColor = Color(0xFF374151);
const Color appGrey800LightColor = Color(0xFF1F2937);
const Color appGrey900LightColor = Color(0xFF111827);
const Color appBottomNavSelectedLightColor = Color(0xFFE53E3E);
const Color appBottomNavUnselectedLightColor = Color(0xFF718096);
const Color appCardLightColor = Color(0xFFF7FAFC);
const Color shimmerBaseLightColor = Color(0xFFE5E7EB);
const Color shimmerHighlightLightColor = Color(0xFFF3F4F6);
const Color appDividerLightColor = Color(0xFFE5E7EB);
//------------------------------------------------------------------------------
// Dark Theme Color Constants
//------------------------------------------------------------------------------
const Color appBackgroundDarkColor = Color(0xFF000000);
const Color appSurfaceDarkColor = Color(0xFF1A1A1A);
const Color appTextPrimaryDarkColor = Color(0xFFFFFFFF);
const Color appTextSecondaryDarkColor = Color(0xFFA0AEC0);
const Color appTextLightDarkColor = Color(0xFF718096);
const Color appTextHeaderDarkColor = Color(0xFFFFFFFF);
const Color appTextBodyDarkColor = Color(0xFFA0AEC0);
const Color appTextCaptionDarkColor = Color(0xFF718096);
const Color appGrey50DarkColor = Color(0xFF0A0A0A);
const Color appGrey100DarkColor = Color(0xFF141414);
const Color appGrey200DarkColor = Color(0xFF1F1F1F);
const Color appGrey300DarkColor = Color(0xFF2A2A2A);
const Color appGrey400DarkColor = Color(0xFF3D3D3D);
const Color appGrey600DarkColor = Color(0xFF666666);
const Color appGrey700DarkColor = Color(0xFF808080);
const Color appGrey800DarkColor = Color(0xFF999999);
const Color appGrey900DarkColor = Color(0xFFB3B3B3);
const Color appBottomNavSelectedDarkColor = Color(0xFFE53E3E);
const Color appBottomNavUnselectedDarkColor = Color(0xFFA0AEC0);
const Color appCardDarkColor = Color(0xFF1A1A1A);
const Color shimmerBaseDarkColor = Color(0xFF1F1F1F);
const Color shimmerHighlightDarkColor = Color(0xFF2A2A2A);
const Color appDividerDarkColor = Color(0xFF2A2A2A);
//------------------------------------------------------------------------------
// Category Colors (same for both themes)
//------------------------------------------------------------------------------
const Color appTrendingColor = Color(0xFFE53E3E);
const Color appSportsColor = Color(0xFF38A169);
const Color appPoliticsColor = Color(0xFF3182CE);
const Color appEntertainmentColor = Color(0xFF9F7AEA);
const Color appTechnologyColor = Color(0xFF00B5D8);
const Color appBusinessColor = Color(0xFFD69E2E);
const Color appHealthColor = Color(0xFFFF6B6B);
const Color appLifestyleColor = Color(0xFFED8936);

//------------------------------------------------------------------------------
// Semantic Alert Colors (always on dark/colored backgrounds — not theme-aware)
//------------------------------------------------------------------------------
const Color appAlertSuccessColor = Color(0xFF16A34A);
const Color appAlertErrorColor   = Color(0xFFDC2626);
const Color appAlertWarningColor  = Color(0xFFD97706);
const Color appAlertInfoColor     = Color(0xFF2563EB);
