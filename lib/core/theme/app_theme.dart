import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class AppTheme {
  static ThemeData lightTheme([double fontScale = 1.0]) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: appPrimaryLightColor,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: appBackgroundLightColor,
      fontFamily: GoogleFonts.roboto().fontFamily,
      appBarTheme: AppBarTheme(
        backgroundColor: appBackgroundLightColor,
        foregroundColor: appTextPrimaryLightColor,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.roboto(
          fontSize: 20 * fontScale,
          fontWeight: FontWeight.w600,
          color: appTextPrimaryLightColor,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: appPrimaryLightColor,
          foregroundColor: appTextWhiteColor,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.roboto(
            fontSize: 16 * fontScale,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      textTheme: GoogleFonts.robotoTextTheme().copyWith(
        headlineLarge: GoogleFonts.roboto(fontSize: 24 * fontScale, fontWeight: FontWeight.bold, color: appTextPrimaryLightColor),
        headlineMedium: GoogleFonts.roboto(fontSize: 20 * fontScale, fontWeight: FontWeight.w600, color: appTextPrimaryLightColor),
        headlineSmall: GoogleFonts.roboto(fontSize: 18 * fontScale, fontWeight: FontWeight.w500, color: appTextPrimaryLightColor),
        bodyLarge: GoogleFonts.roboto(fontSize: 16 * fontScale, fontWeight: FontWeight.normal, color: appTextPrimaryLightColor),
        bodyMedium: GoogleFonts.roboto(fontSize: 14 * fontScale, fontWeight: FontWeight.normal, color: appTextSecondaryLightColor),
        bodySmall: GoogleFonts.roboto(fontSize: 12 * fontScale, fontWeight: FontWeight.normal, color: appTextLightLightColor),
      ),
      cardTheme: CardThemeData(
        color: appSurfaceLightColor,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: appBackgroundLightColor,
        selectedItemColor: appPrimaryLightColor,
        unselectedItemColor: appTextLightLightColor,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: GoogleFonts.roboto(fontSize: 12 * fontScale),
        unselectedLabelStyle: GoogleFonts.roboto(fontSize: 12 * fontScale),
      ),
      inputDecorationTheme: InputDecorationTheme(
        fillColor: appSurfaceLightColor,
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: appPrimaryLightColor,
            width: 2,
          ),
        ),
        hintStyle: TextStyle(
          color: appTextLightLightColor,
        ),
        labelStyle: TextStyle(
          color: appTextSecondaryLightColor,
        ),
      ),
    );
  }

  static ThemeData darkTheme([double fontScale = 1.0]) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: appPrimaryLightColor,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: appBackgroundDarkColor,
      fontFamily: GoogleFonts.roboto().fontFamily,
      appBarTheme: AppBarTheme(
        backgroundColor: appBackgroundDarkColor,
        foregroundColor: appTextWhiteColor,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.roboto(
          fontSize: 20 * fontScale,
          fontWeight: FontWeight.w600,
          color: appTextWhiteColor,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: appPrimaryLightColor,
          foregroundColor: appTextWhiteColor,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.roboto(
            fontSize: 16 * fontScale,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      textTheme: GoogleFonts.robotoTextTheme(ThemeData.dark().textTheme).copyWith(
        headlineLarge: GoogleFonts.roboto(
          fontSize: 24 * fontScale,
          fontWeight: FontWeight.bold,
          color: appTextWhiteColor,
        ),
        headlineMedium: GoogleFonts.roboto(
          fontSize: 20 * fontScale,
          fontWeight: FontWeight.w600,
          color: appTextWhiteColor,
        ),
        headlineSmall: GoogleFonts.roboto(
          fontSize: 18 * fontScale,
          fontWeight: FontWeight.w500,
          color: appTextWhiteColor,
        ),
        bodyLarge: GoogleFonts.roboto(
          fontSize: 16 * fontScale,
          fontWeight: FontWeight.normal,
          color: appTextWhiteColor,
        ),
        bodyMedium: GoogleFonts.roboto(
          fontSize: 14 * fontScale,
          fontWeight: FontWeight.normal,
          color: appTextLightDarkColor,
        ),
        bodySmall: GoogleFonts.roboto(
          fontSize: 12 * fontScale,
          fontWeight: FontWeight.normal,
          color: appTextLightDarkColor,
        ),
      ),
      cardTheme: CardThemeData(
        color: appSurfaceDarkColor,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: appBackgroundDarkColor,
        selectedItemColor: appPrimaryLightColor,
        unselectedItemColor: appTextLightDarkColor,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: GoogleFonts.roboto(fontSize: 12 * fontScale),
        unselectedLabelStyle: GoogleFonts.roboto(fontSize: 12 * fontScale),
      ),
      inputDecorationTheme: InputDecorationTheme(
        fillColor: appSurfaceDarkColor,
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: Colors.white70,
            width: 2,
          ),
        ),
        hintStyle: TextStyle(
          color: appTextLightDarkColor,
        ),
        labelStyle: TextStyle(
          color: appTextSecondaryDarkColor,
        ),
      ),
    );
  }
}
