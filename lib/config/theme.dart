import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color primary = Color(0xFFFF6B6B);
  static const Color secondary = Color(0xFF4ECDC4);
  static const Color success = Color(0xFF95E1D3);
  static const Color warning = Color(0xFFFFE66D);
  static const Color error = Color(0xFFFF8585);
  static const Color background = Color(0xFFF7FFF7);
  static const Color card = Color(0xFFFFFFFF);
  static const Color text = Color(0xFF2D3436);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
      textTheme: GoogleFonts.nunitoTextTheme(),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ),
    );
  }
}
