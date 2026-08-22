import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'kameo_colors.dart';

/// Le thème de l'application : Fredoka pour l'affichage, Nunito pour le texte.
abstract final class KameoTheme {
  static ThemeData light() {
    final TextTheme base = ThemeData.light().textTheme;
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: KColors.creme,
      colorScheme: ColorScheme.fromSeed(
        seedColor: KColors.corail,
        primary: KColors.corail,
        secondary: KColors.lagon,
        tertiary: KColors.soleil,
        surface: KColors.creme,
      ),
      textTheme: GoogleFonts.nunitoTextTheme(base).copyWith(
        displayLarge: GoogleFonts.fredoka(
          fontSize: 34,
          fontWeight: FontWeight.w600,
          color: KColors.encre,
        ),
        headlineMedium: GoogleFonts.fredoka(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: KColors.encre,
        ),
        titleMedium: GoogleFonts.fredoka(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: KColors.encre,
        ),
        bodyMedium: GoogleFonts.nunito(
          fontSize: 15,
          height: 1.55,
          color: KColors.encre,
        ),
        labelSmall: GoogleFonts.nunito(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
          color: KColors.encreDouce,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KSpace.radiusCard),
          side: const BorderSide(color: KColors.trait),
        ),
      ),
    );
  }
}
