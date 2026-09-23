import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors
  static const Color primaryTeal = Color(0xFF0F766E);      // Deep Teal
  static const Color primaryLight = Color(0xFF14B8A6);     // Bright Aqua Teal
  static const Color accentCyan = Color(0xFF06B6D4);       // Water Cyan
  static const Color surfaceDark = Color(0xFF0F172A);      // Slate 900
  static const Color cardDark = Color(0xFF1E293B);         // Slate 800
  static const Color cardLight = Colors.white;
  static const Color backgroundLight = Color(0xFFF8FAFC);  // Slate 50
  
  // Status & Confidence Colors
  static const Color statusGreen = Color(0xFF10B981);      // > 80% Confidence
  static const Color statusBlue = Color(0xFF3B82F6);       // 60-80% Confidence
  static const Color statusYellow = Color(0xFFF59E0B);     // 40-60% Confidence
  static const Color statusRed = Color(0xFFEF4444);        // < 40% Confidence
  
  static Color getConfidenceColor(double score) {
    if (score >= 80.0) return statusGreen;
    if (score >= 60.0) return statusBlue;
    if (score >= 40.0) return statusYellow;
    return statusRed;
  }

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: backgroundLight,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryTeal,
      primary: primaryTeal,
      secondary: accentCyan,
      background: backgroundLight,
    ),
    textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme),
    appBarTheme: AppBarTheme(
      elevation: 0,
      centerTitle: false,
      backgroundColor: Colors.white,
      foregroundColor: surfaceDark,
      titleTextStyle: GoogleFonts.outfit(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: surfaceDark,
      ),
    ),
    cardTheme: CardTheme(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryTeal,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
  );
}
