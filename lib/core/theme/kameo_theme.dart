import 'package:flutter/material.dart';

import 'kameo_colors.dart';

/// Le thème de l'application : Fredoka pour l'affichage, Nunito pour le texte.
///
/// Les deux polices sont **embarquées dans l'app**, pas téléchargées au
/// premier lancement. Une app qui parle de voyage n'a aucune raison d'avoir
/// besoin du réseau pour afficher son propre texte — et ça supprime au passage
/// un mode de panne en test comme en avion.
///
/// Ce sont des polices variables : l'axe `wght` donne toutes les graisses avec
/// un seul fichier, au lieu d'en embarquer quatre.
abstract final class KameoTheme {
  static const String display = 'Fredoka';
  static const String body = 'Nunito';

  static TextStyle _fredoka({
    required double size,
    double weight = 600,
    Color color = KColors.encre,
    double? height,
  }) =>
      TextStyle(
        fontFamily: display,
        fontSize: size,
        height: height,
        color: color,
        fontVariations: <FontVariation>[FontVariation('wght', weight)],
      );

  static TextStyle _nunito({
    required double size,
    double weight = 400,
    Color color = KColors.encre,
    double? height,
    double? letterSpacing,
  }) =>
      TextStyle(
        fontFamily: body,
        fontSize: size,
        height: height,
        color: color,
        letterSpacing: letterSpacing,
        fontVariations: <FontVariation>[FontVariation('wght', weight)],
      );

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      fontFamily: body,
      scaffoldBackgroundColor: KColors.creme,
      colorScheme: ColorScheme.fromSeed(
        seedColor: KColors.corail,
        primary: KColors.corail,
        secondary: KColors.lagon,
        tertiary: KColors.soleil,
        surface: KColors.creme,
      ),
      textTheme: TextTheme(
        displayLarge: _fredoka(size: 30, height: 1.15),
        headlineMedium: _fredoka(size: 23, height: 1.2),
        titleMedium: _fredoka(size: 17),
        bodyLarge: _nunito(size: 16, height: 1.5),
        bodyMedium: _nunito(size: 15, height: 1.55),
        labelSmall: _nunito(
          size: 11,
          weight: 800,
          color: KColors.encreDouce,
          letterSpacing: 1.4,
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
