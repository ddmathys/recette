import 'package:flutter/material.dart';

/// La palette Kameo (spec §1.2). Un seul endroit, jamais de littéral de
/// couleur ailleurs dans le code.
abstract final class KColors {
  static const Color creme = Color(0xFFFDF8EF);
  static const Color encre = Color(0xFF33305E);
  static const Color corail = Color(0xFFFF6B5E);
  static const Color soleil = Color(0xFFFFC63F);
  static const Color raisin = Color(0xFF7C4DFF);
  static const Color lagon = Color(0xFF00C9A7);
  static const Color ciel = Color(0xFF3EA8FF);

  static const Color corailOmbre = Color(0xFFD8493D);
  static const Color encreDouce = Color(0xFF6F6A9B);
  static const Color trait = Color(0xFFE4D9C6);
  static const Color creuse = Color(0xFFF3EADC);
}

/// L'échelle d'espacement. Tout espacement du produit sort d'ici : c'est ce
/// qui évite les « 13 px » qui traînent.
abstract final class KSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 40;
  static const double radius = 18;
  static const double radiusCard = 20;
}
