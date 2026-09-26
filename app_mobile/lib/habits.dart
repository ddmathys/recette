import 'models.dart';

/// Un repas déjà noté, reproposé "à l'unité" pour le renoter en un tap.
/// Mirrors ../../src/lib/habits.ts.
class Habit {
  final String label;
  final String mealType;
  final String? recipeId;
  final num portionGrams;
  final num kcal;
  final num proteinG;
  final num carbsG;
  final num fatG;
  int times;
  final String lastAt;

  Habit({
    required this.label,
    required this.mealType,
    required this.recipeId,
    required this.portionGrams,
    required this.kcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.times,
    required this.lastAt,
  });

  /// Brouillon de repas pour `count` unités de cet habituel.
  MealLogDraft toDraft(int count, String type, DateTime eatenAt) => MealLogDraft(
    recipeId: recipeId,
    label: label,
    mealType: type,
    eatenAt: eatenAt,
    portionGrams: (portionGrams * count).round(),
    kcal: (kcal * count).round(),
    proteinG: (proteinG * count).round(),
    carbsG: (carbsG * count).round(),
    fatG: (fatG * count).round(),
    count: count == 1 ? null : count,
  );
}

/// Les repas notés le plus souvent (puis le plus récemment) par cet
/// utilisateur, éventuellement filtrés par type. Estimations exclues.
List<Habit> computeHabits(List<MealLog> logs, String ownerId, {String? mealType, int limit = 8}) {
  final byLabel = <String, Habit>{};
  // logs triés du plus récent au plus ancien : la 1re occurrence donne les
  // valeurs les plus récentes.
  for (final l in logs) {
    if (l.ownerId != ownerId || l.source == 'estimate') continue;
    if (mealType != null && l.mealType != mealType) continue;
    final key = l.label.trim().toLowerCase();
    final existing = byLabel[key];
    if (existing != null) {
      existing.times += 1;
      continue;
    }
    final c = (l.count != null && l.count! > 0) ? l.count! : 1;
    byLabel[key] = Habit(
      label: l.label.trim(),
      mealType: l.mealType,
      recipeId: l.recipeId,
      portionGrams: (l.portionGrams / c).round(),
      kcal: (l.kcal / c).round(),
      proteinG: (l.proteinG / c).round(),
      carbsG: (l.carbsG / c).round(),
      fatG: (l.fatG / c).round(),
      times: 1,
      lastAt: l.eatenAt,
    );
  }
  final list = byLabel.values.toList()..sort((a, b) => b.times != a.times ? b.times - a.times : b.lastAt.compareTo(a.lastAt));
  return list.take(limit).toList();
}

class DayTotal {
  num kcal = 0, proteinG = 0, carbsG = 0, fatG = 0, estimated = 0;
}

String dayKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Totaux par jour local (clé YYYY-MM-DD).
Map<String, DayTotal> dailyTotals(List<MealLog> logs) {
  final days = <String, DayTotal>{};
  for (final l in logs) {
    final d = DateTime.tryParse(l.eatenAt)?.toLocal();
    if (d == null) continue;
    final t = days.putIfAbsent(dayKey(d), DayTotal.new);
    t.kcal += l.kcal;
    t.proteinG += l.proteinG;
    t.carbsG += l.carbsG;
    t.fatG += l.fatG;
    if (l.source == 'estimate') t.estimated += l.kcal;
  }
  return days;
}

/// Proposition pour "estimer la journée" : moyenne des 30 derniers jours
/// notés (hors jour visé), sinon l'objectif ; macros selon ta répartition.
({num already, num suggested, bool fromAverage, double protein, double carbs, double fat}) estimateFor(
  List<MealLog> logs,
  DateTime day,
  num goal,
) {
  final totals = dailyTotals(logs);
  final selKey = dayKey(day);
  final sinceKey = dayKey(DateTime.now().subtract(const Duration(days: 30)));
  final others = totals.entries.where((e) => e.key != selKey && e.key.compareTo(sinceKey) >= 0).map((e) => e.value).toList();
  num kcal = 0, p = 0, c = 0, f = 0;
  for (final t in others) {
    kcal += t.kcal;
    p += t.proteinG * 4;
    c += t.carbsG * 4;
    f += t.fatG * 9;
  }
  final macro = p + c + f;
  return (
    already: totals[selKey]?.kcal ?? 0,
    suggested: others.length >= 2 ? kcal / others.length : goal,
    fromAverage: others.length >= 2,
    protein: macro > 0 ? p / macro : 0.25,
    carbs: macro > 0 ? c / macro : 0.45,
    fat: macro > 0 ? f / macro : 0.30,
  );
}
