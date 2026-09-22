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
