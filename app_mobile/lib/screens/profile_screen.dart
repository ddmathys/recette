import 'package:flutter/material.dart';

import '../energy.dart';
import '../models.dart';
import '../services/household_service.dart';
import '../theme.dart';

/// « Mon profil » : prénom, mesures du corps → besoin quotidien estimé
/// (energy.dart). La proposition ne devient l'objectif que si l'utilisateur
/// la valide ; il peut aussi taper son propre chiffre, ici ou sur le
/// dashboard, à tout moment. Mirrors ProfileDialog.tsx.
class ProfileScreen extends StatefulWidget {
  final String uid;
  final UserProfile profile;
  const ProfileScreen({super.key, required this.uid, required this.profile});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _households = HouseholdService();
  late final TextEditingController _name = TextEditingController(text: widget.profile.displayName);
  late final TextEditingController _birthYear =
      TextEditingController(text: widget.profile.birthYear?.toString() ?? '');
  late final TextEditingController _height =
      TextEditingController(text: widget.profile.heightCm?.round().toString() ?? '');
  late final TextEditingController _weight =
      TextEditingController(text: widget.profile.weightKg?.toString() ?? '');
  late final TextEditingController _goal =
      TextEditingController(text: (_currentGoal).round().toString());

  late String? _sex = widget.profile.sex;
  late String? _activity = widget.profile.activity;
  late String? _aim = widget.profile.aim;

  String? _busy; // 'metrics' | 'goal' | 'apply'
  String? _error;
  String? _saved;

  num get _currentGoal =>
      (widget.profile.dailyKcalGoal != null && widget.profile.dailyKcalGoal! > 0) ? widget.profile.dailyKcalGoal! : 2000;

  @override
  void dispose() {
    _name.dispose();
    _birthYear.dispose();
    _height.dispose();
    _weight.dispose();
    _goal.dispose();
    super.dispose();
  }

  int? get _year => int.tryParse(_birthYear.text.trim());
  num? get _cm => num.tryParse(_height.text.trim().replaceAll(',', '.'));
  num? get _kg => num.tryParse(_weight.text.trim().replaceAll(',', '.'));

  bool get _complete => metricsComplete(
    sex: _sex,
    birthYear: _year,
    heightCm: _cm,
    weightKg: _kg,
    activity: _activity,
    aim: _aim,
  );

  EnergyResult? get _energy => _complete
      ? computeEnergy(BodyMetrics(
          sex: _sex!,
          birthYear: _year!,
          heightCm: _cm!,
          weightKg: _kg!,
          activity: _activity!,
          aim: _aim!,
        ))
      : null;

  BodyMetrics get _metrics => BodyMetrics(
    sex: _sex!,
    birthYear: _year!,
    heightCm: _cm!,
    weightKg: _kg!,
    activity: _activity!,
    aim: _aim!,
  );

  Future<void> _saveName() async {
    if (_name.text.trim().isNotEmpty && _name.text.trim() != widget.profile.displayName) {
      await _households.setDisplayName(widget.uid, _name.text);
    }
  }

  Future<void> _saveMetrics() async {
    if (!_complete) {
      setState(() => _error = "Complète le sexe, l'année de naissance, la taille, le poids, l'activité et l'objectif.");
      return;
    }
    setState(() {
      _error = null;
      _busy = 'metrics';
    });
    try {
      await _saveName();
      await _households.saveBodyMetrics(widget.uid, _metrics.toMap());
      if (mounted) setState(() => _saved = 'Mesures enregistrées.');
    } catch (_) {
      if (mounted) setState(() => _error = "L'enregistrement a échoué, réessaie.");
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  /// « OK, je réplique » : la proposition devient l'objectif du dashboard.
  Future<void> _applySuggestion() async {
    final e = _energy;
    if (e == null) return;
    setState(() {
      _error = null;
      _busy = 'apply';
    });
    try {
      await _saveName();
      await _households.saveBodyMetrics(widget.uid, _metrics.toMap());
      await _households.setDailyKcalGoal(widget.uid, e.suggested, source: 'computed');
      if (mounted) {
        _goal.text = e.suggested.toString();
        setState(() => _saved = 'Objectif réglé sur ${e.suggested} kcal/jour.');
      }
    } catch (_) {
      if (mounted) setState(() => _error = "L'enregistrement a échoué, réessaie.");
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _saveGoal() async {
    final v = num.tryParse(_goal.text.trim());
    if (v == null || v < 800 || v > 6000) {
      setState(() => _error = 'Indique un objectif entre 800 et 6000 kcal.');
      return;
    }
    setState(() {
      _error = null;
      _busy = 'goal';
    });
    try {
      await _households.setDailyKcalGoal(widget.uid, v.round());
      if (mounted) setState(() => _saved = 'Objectif fixé à la main : ${v.round()} kcal/jour.');
    } catch (_) {
      if (mounted) setState(() => _error = "L'enregistrement a échoué, réessaie.");
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = _energy;
    final goalDiffers = e != null && (e.suggested - _currentGoal).abs() >= 25;

    return Scaffold(
      appBar: AppBar(title: const Text('Mon profil')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [
            if (_error != null) _Banner(text: _error!, color: AppColors.accent),
            if (_error == null && _saved != null) _Banner(text: '✓ ${_saved!}', color: AppColors.herb),

            // Objectif en cours — c'est lui que le dashboard utilise.
            _Card(
              title: 'MON OBJECTIF DU JOUR',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      SizedBox(
                        width: 120,
                        child: TextField(
                          controller: _goal,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 20, fontWeight: FontWeight.w800),
                          decoration: const InputDecoration(labelText: 'kcal / jour', isDense: true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _busy != null ? null : _saveGoal,
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.ink, foregroundColor: AppColors.bg),
                        child: Text(_busy == 'goal' ? '…' : 'Enregistrer'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.profile.goalSource == 'computed'
                        ? 'Calculé depuis tes mesures — tu peux le remplacer par ton propre chiffre quand tu veux.'
                        : 'Fixé à la main. Remplis tes mesures ci-dessous pour obtenir une proposition.',
                    style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
                  ),
                ],
              ),
            ),

            // Mesures
            _Card(
              title: 'MES MESURES',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    "Servent uniquement à estimer ton besoin quotidien. Rien n'est partagé avec les autres membres du foyer.",
                    style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Prénom', isDense: true),
                  ),
                  const SizedBox(height: 16),
                  const Text('Sexe', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      for (final opt in const [('f', 'Femme'), ('h', 'Homme')])
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: opt.$1 == 'f' ? 8 : 0),
                            child: OutlinedButton(
                              onPressed: () => setState(() => _sex = opt.$1),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: _sex == opt.$1 ? AppColors.accent : AppColors.surface2,
                                foregroundColor: _sex == opt.$1 ? Colors.white : AppColors.inkSoft,
                                side: BorderSide(color: _sex == opt.$1 ? AppColors.accent : AppColors.line, width: 2),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text(opt.$2, style: const TextStyle(fontWeight: FontWeight.w800)),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "La formule de calcul n'a que ces deux variantes.",
                    style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _birthYear,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(labelText: 'Naissance', isDense: true, hintText: '1990'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _height,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(labelText: 'Taille cm', isDense: true, hintText: '178'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _weight,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(labelText: 'Poids kg', isDense: true, hintText: '75'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Activité physique', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                  const SizedBox(height: 6),
                  for (final a in kActivities)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() => _activity = a.key),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: _activity == a.key ? AppColors.accent.withValues(alpha: 0.08) : AppColors.surface2,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _activity == a.key ? AppColors.accent : AppColors.line, width: 2),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(a.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(a.hint, style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  const Text('Mon objectif de poids', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final a in kAims)
                        ChoiceChip(
                          label: Text(a.label),
                          selected: _aim == a.key,
                          selectedColor: AppColors.accent,
                          labelStyle: TextStyle(
                            color: _aim == a.key ? Colors.white : AppColors.ink,
                            fontWeight: FontWeight.w700,
                          ),
                          onSelected: (_) => setState(() => _aim = a.key),
                        ),
                    ],
                  ),
                  if (_aim != null) ...[
                    const SizedBox(height: 4),
                    Text(aimMeta(_aim).hint, style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft)),
                  ],
                ],
              ),
            ),

            // Résultat
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFFDF8), Color(0xFFFDF4E4)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'TON BESOIN ESTIMÉ',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.inkSoft),
                  ),
                  const SizedBox(height: 8),
                  if (e == null)
                    const Text(
                      "Complète tes mesures ci-dessus et le calcul s'affiche ici.",
                      style: TextStyle(fontSize: 13.5, color: AppColors.inkSoft),
                    )
                  else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${e.suggested}',
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 34, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(width: 6),
                        const Text('kcal / jour', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.inkSoft)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Métabolisme de base ${e.bmr} × activité ${activityMeta(_activity).label.toLowerCase()} = ${e.tdee} kcal dépensées, '
                      '${aimMeta(_aim).delta == 0 ? "sans ajustement" : "ajusté de ${aimMeta(_aim).delta > 0 ? "+" : ""}${aimMeta(_aim).delta} kcal pour ton objectif"}.',
                      style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
                    ),
                    if (e.floored) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Relevé au plancher de sécurité (${_sex == 'f' ? 1200 : 1500} kcal). Pour descendre plus bas, parles-en à un professionnel.',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.gold),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _busy != null ? null : _applySuggestion,
                        child: Text(
                          _busy == 'apply'
                              ? 'Enregistrement…'
                              : (goalDiffers ? 'OK, utiliser ${e.suggested} kcal' : "✓ C'est déjà mon objectif"),
                          style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: _busy != null ? null : _saveMetrics,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.ink,
                          side: const BorderSide(color: AppColors.line, width: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                          _busy == 'metrics' ? 'Enregistrement…' : "Garder mes mesures sans changer l'objectif",
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Estimation indicative, sans valeur médicale. Tu gardes la main : l'objectif reste modifiable ici ou en tapant sur le chiffre du dashboard.",
                      style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  const _Card({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final String text;
  final Color color;
  const _Banner({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    );
  }
}
