import 'package:flutter/material.dart';

/// Un moment de la journée au dashboard : son libellé, son emoji, sa
/// couleur dans l'anneau et les catégories de recettes à proposer en
/// premier quand on remplit ce créneau. Mirrors MEAL_TYPES in
/// ../../src/lib/mealTypes.ts.
class MealSlot {
  final String key;
  final String label;
  final String short;
  final String emoji;
  final Color color;
  final List<String> cats;
  const MealSlot(this.key, this.label, this.short, this.emoji, this.color, this.cats);
}

const List<MealSlot> kMealSlots = [
  MealSlot('petit-dej', 'Petit-déjeuner', 'Petit-déj', '☕', Color(0xFFF2A600), ['petit-dejeuner']),
  MealSlot('dejeuner', 'Déjeuner', 'Déjeuner', '🍽️', Color(0xFFFF5A36), ['salade', 'sandwich', 'pates-riz', 'soupe']),
  MealSlot('diner', 'Dîner', 'Dîner', '🌙', Color(0xFF17A2B8), ['viande', 'poisson', 'vegetarien', 'pates-riz', 'soupe']),
  MealSlot('collation', 'Collation', 'En-cas', '🍎', Color(0xFF1FA876), ['apero', 'dessert']),
];

MealSlot mealSlot(String key) => kMealSlots.firstWhere((s) => s.key == key, orElse: () => kMealSlots[1]);

/// Mirrors ../../src/lib/mealTypes.ts.
const List<(String, String)> kMealTypes = [
  ('petit-dej', 'Petit-déjeuner'),
  ('dejeuner', 'Déjeuner'),
  ('diner', 'Dîner'),
  ('collation', 'Collation'),
];

String mealTypeLabel(String key) => kMealTypes.firstWhere((m) => m.$1 == key, orElse: () => (key, 'Repas')).$2;

/// Guesses a plausible meal type from the current time, so the form isn't
/// blank by default.
String guessMealType([DateTime? at]) {
  final h = (at ?? DateTime.now()).hour;
  if (h < 10) return 'petit-dej';
  if (h < 15) return 'dejeuner';
  if (h < 21) return 'diner';
  return 'collation';
}

const Map<String, (int, int)> _typicalHour = {
  'petit-dej': (8, 0),
  'dejeuner': (12, 30),
  'collation': (16, 0),
  'diner': (19, 30),
};

bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// Moment à enregistrer pour un repas ajouté sur le jour affiché au
/// dashboard : maintenant si c'est aujourd'hui, sinon ce jour-là à une
/// heure typique du type de repas. Mirrors eatenAtFor() in mealTypes.ts.
DateTime eatenAtFor(DateTime day, String mealType) {
  final now = DateTime.now();
  if (isSameDay(day, now)) return now;
  final (h, m) = _typicalHour[mealType] ?? (12, 0);
  return DateTime(day.year, day.month, day.day, h, m);
}

const _weekdays = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];
const _months = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];

/// "Aujourd'hui", "Hier" ou "jeu. 24 sept."
String dayLabel(DateTime day) {
  final now = DateTime.now();
  if (isSameDay(day, now)) return "Aujourd'hui";
  if (isSameDay(day, now.subtract(const Duration(days: 1)))) return 'Hier';
  return '${_weekdays[day.weekday - 1]} ${day.day} ${_months[day.month - 1]}';
}
