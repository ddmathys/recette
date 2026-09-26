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
