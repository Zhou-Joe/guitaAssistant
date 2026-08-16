import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color primary = Color(0xFF1E1B4B);       // Indigo 950 - headers, accents
  static const Color secondary = Color(0xFF4338CA);     // Indigo 700 - secondary elements
  static const Color cta = Color(0xFF22C55E);           // Green 500 - play/success
  static const Color error = Color(0xFFEF4444);         // Red 500 - stop/error
  static const Color warning = Color(0xFFF59E0B);       // Amber 500 - close/warning
  static const Color background = Color(0xFF0F0F23);    // Dark navy background
  static const Color surface = Color(0xFF1A1A2E);       // Cards, panels
  static const Color surfaceElevated = Color(0xFF252542); // Modals, dialogs
  static const Color textPrimary = Color(0xFFF8FAFC);   // Main text (Slate 50)
  static const Color textSecondary = Color(0xFF94A3B8); // Muted text (Slate 400)
  static const Color textMuted = Color(0xFF64748B);     // Labels (Slate 500)

  // Vibrant accent colors for feature cards
  static const Color accentTuner = Color(0xFF22C55E);     // Green - success/in-tune
  static const Color accentMetronome = Color(0xFF4338CA);  // Indigo - rhythm/music
  static const Color accentFavorites = Color(0xFFF59E0B);  // Amber - favorites/star
  static const Color accentRecording = Color(0xFFEF4444);  // Red - recording indicator
  static const Color accentAnalysis = Color(0xFF8B5CF6);  // Purple - analytics
  static const Color accentSettings = Color(0xFF64748B);  // Slate - neutral

  // Aliases for backwards compatibility
  static const Color success = cta;
  static const Color card = surface;
  static const Color text = textPrimary;
  static const Color textLight = textSecondary;
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        error: AppColors.error,
        surface: AppColors.surface,
      ),
      scaffoldBackgroundColor: AppColors.background,
      textTheme: GoogleFonts.poppinsTextTheme().apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.cta,
          foregroundColor: AppColors.textPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surfaceElevated,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      iconTheme: IconThemeData(
        color: AppColors.textPrimary,
      ),
    );
  }
}