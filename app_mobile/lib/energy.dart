// Besoin énergétique quotidien estimé à partir des mesures du profil
// (Mifflin-St Jeor × facteur d'activité, ajusté selon l'objectif de poids).
// Mirrors ../../src/lib/energy.ts — garder les deux en phase.

class ActivityLevel {
  final String key;
  final String label;
  final String hint;
  final double factor;
  const ActivityLevel(this.key, this.label, this.hint, this.factor);
}

class WeightAim {
  final String key;
  final String label;
  final String hint;
  final int delta;
  const WeightAim(this.key, this.label, this.hint, this.delta);
}

const List<ActivityLevel> kActivities = [
  ActivityLevel('sedentaire', 'Sédentaire', 'bureau, peu de marche', 1.2),
  ActivityLevel('leger', 'Légère', 'un peu de marche, 1–2 séances/sem.', 1.375),
  ActivityLevel('modere', 'Modérée', '3–5 séances/sem.', 1.55),
  ActivityLevel('actif', 'Soutenue', '6–7 séances/sem.', 1.725),
  ActivityLevel('tres-actif', 'Très intense', 'métier physique ou 2×/jour', 1.9),
];

const List<WeightAim> kAims = [
  WeightAim('perdre-vite', 'Perdre vite', '≈ −0,7 kg/sem.', -500),
  WeightAim('perdre', 'Perdre', '≈ −0,3 kg/sem.', -250),
  WeightAim('maintenir', 'Maintenir', 'stabiliser mon poids', 0),
  WeightAim('prendre', 'Prendre', '≈ +0,3 kg/sem.', 250),
  WeightAim('prendre-vite', 'Prendre vite', '≈ +0,7 kg/sem.', 500),
];

ActivityLevel activityMeta(String? key) =>
    kActivities.firstWhere((a) => a.key == key, orElse: () => kActivities[2]);

WeightAim aimMeta(String? key) => kAims.firstWhere((a) => a.key == key, orElse: () => kAims[2]);

/// Planchers de sécurité : on ne propose jamais moins, même pour perdre vite.
const Map<String, int> _floor = {'f': 1200, 'h': 1500};

class BodyMetrics {
  final String sex; // 'f' | 'h'
  final int birthYear;
  final num heightCm;
  final num weightKg;
  final String activity;
  final String aim;
  const BodyMetrics({
    required this.sex,
    required this.birthYear,
    required this.heightCm,
    required this.weightKg,
    required this.activity,
    required this.aim,
  });

  Map<String, dynamic> toMap() => {
    'sex': sex,
    'birthYear': birthYear,
    'heightCm': heightCm,
    'weightKg': weightKg,
    'activity': activity,
    'aim': aim,
  };
}

class EnergyResult {
  final int bmr;
  final int tdee;
  final int suggested;
  final bool floored;
  const EnergyResult(this.bmr, this.tdee, this.suggested, this.floored);
}

/// Mesures complètes et plausibles ? Un profil incomplet n'affiche pas de
/// proposition plutôt qu'un chiffre faux.
bool metricsComplete({
  String? sex,
  int? birthYear,
  num? heightCm,
  num? weightKg,
  String? activity,
  String? aim,
}) {
  final year = DateTime.now().year;
  return (sex == 'f' || sex == 'h') &&
      birthYear != null &&
      birthYear >= year - 110 &&
      birthYear <= year - 10 &&
      heightCm != null &&
      heightCm >= 100 &&
      heightCm <= 230 &&
      weightKg != null &&
      weightKg >= 25 &&
      weightKg <= 400 &&
      kActivities.any((a) => a.key == activity) &&
      kAims.any((a) => a.key == aim);
}

EnergyResult computeEnergy(BodyMetrics m) {
  final age = DateTime.now().year - m.birthYear;
  final base = 10 * m.weightKg + 6.25 * m.heightCm - 5 * age + (m.sex == 'h' ? 5 : -161);
  final bmr = base.round();
  final tdee = (bmr * activityMeta(m.activity).factor).round();
  final raw = tdee + aimMeta(m.aim).delta;
  final floor = _floor[m.sex] ?? 1200;
  return EnergyResult(bmr, tdee, raw < floor ? floor : (raw / 10).round() * 10, raw < floor);
}
