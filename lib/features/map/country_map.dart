import 'package:flutter/material.dart';
import 'package:kameo_engine/kameo_engine.dart';

import '../../core/theme/kameo_colors.dart';

/// Dessine le pays et l'itinéraire.
///
/// Carte **illustrée**, pas géographique : aucune licence, un rendu chaleureux,
/// et une projection assez fidèle pour que les villes tombent au bon endroit
/// (le test `chaque ville tombe bien à l'intérieur de sa carte` le vérifie).
class CountryMapPainter extends CustomPainter {
  const CountryMapPainter({required this.country, required this.doneCount});

  final Country country;

  /// Nombre d'étapes déjà tamponnées : l'itinéraire parcouru est plein,
  /// le reste est en pointillé.
  final int doneCount;

  Offset _project(MapPoint p, Size size) =>
      Offset(p.x / 100 * size.width, p.y / 100 * size.height);

  @override
  void paint(Canvas canvas, Size size) {
    final Path land = Path();
    for (int i = 0; i < country.outline.length; i++) {
      final Offset o = _project(country.outline[i], size);
      if (i == 0) {
        land.moveTo(o.dx, o.dy);
      } else {
        land.lineTo(o.dx, o.dy);
      }
    }
    land.close();

    canvas.drawPath(
      land,
      Paint()
        ..color = KColors.soleil.withValues(alpha: 0.28)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      land,
      Paint()
        ..color = KColors.traitFort
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );

    final List<Offset> stops = country.cities
        .map((City c) => _project(c.position, size))
        .toList(growable: false);
    for (int i = 0; i < stops.length - 1; i++) {
      _drawLeg(canvas, stops[i], stops[i + 1], travelled: i < doneCount - 1);
    }
  }

  void _drawLeg(
    Canvas canvas,
    Offset from,
    Offset to, {
    required bool travelled,
  }) {
    final Paint paint = Paint()
      ..color = KColors.corail.withValues(alpha: travelled ? 0.9 : 0.55)
      ..strokeWidth = travelled ? 2.6 : 2
      ..strokeCap = StrokeCap.round;
    if (travelled) {
      canvas.drawLine(from, to, paint);
      return;
    }
    // Pointillé : ce qui reste à parcourir.
    const double dash = 7;
    const double gap = 6;
    final double total = (to - from).distance;
    final Offset step = (to - from) / total;
    double travelledLength = 0;
    while (travelledLength < total) {
      final double end = (travelledLength + dash).clamp(0.0, total);
      canvas.drawLine(
        from + step * travelledLength,
        from + step * end,
        paint,
      );
      travelledLength = end + gap;
    }
  }

  @override
  bool shouldRepaint(CountryMapPainter old) =>
      old.country.id != country.id || old.doneCount != doneCount;
}
