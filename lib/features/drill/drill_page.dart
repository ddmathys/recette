import 'dart:math';

import 'package:flutter/material.dart';
import 'package:kameo_engine/kameo_engine.dart';

import '../../core/kameo_scope.dart';
import '../../core/session.dart';
import '../../core/speech.dart';
import '../../core/theme/kameo_colors.dart';
import '../../core/widgets/k_button.dart';

/// La session d'apprentissage du vocabulaire d'une ville.
///
/// Les exercices ne viennent d'aucun fichier de contenu : ils sont fabriqués
/// depuis le répertoire par le moteur. C'est ce qui permet de faire tourner
/// l'apprentissage aujourd'hui, avant d'avoir écrit la moindre leçon.
class DrillPage extends StatefulWidget {
  const DrillPage({required this.city, super.key});

  final City city;

  @override
  State<DrillPage> createState() => _DrillPageState();
}

class _DrillPageState extends State<DrillPage> {
  static const int _sessionSize = 6;

  late final KameoSession _session = KameoScope.of(context);
  late final List<Drill> _drills;
  final Random _rng = Random();

  int _index = 0;
  String? _chosen;
  bool _revealed = false;
  int _correct = 0;
  int _wordsBefore = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepare());
  }

  void _prepare() {
    final CityObjective objective = _session.objectiveFor(widget.city.id)!;
    _wordsBefore = objective.acquiredIn(_session.drills);
    setState(() {
      _drills = const DrillBuilder().session(
        lexicon: _session.travelLexicon,
        objective: objective,
        records: _session.drills,
        size: _sessionSize,
        random: _rng,
      );
    });
    _speakIfNeeded();
  }

  @override
  void dispose() {
    Speech.instance.stop();
    super.dispose();
  }

  void _speakIfNeeded() {
    if (_index >= _drills.length) return;
    final Drill d = _drills[_index];
    if (d.spoken != null) {
      Speech.instance.say(
        d.spoken!,
        locale: _session.country?.ttsLocale ?? 'es-ES',
      );
    }
  }

  void _answer(String option) {
    if (_revealed) return;
    final Drill d = _drills[_index];
    final bool ok = option == d.answer;
    setState(() {
      _chosen = option;
      _revealed = true;
      if (ok) _correct++;
    });
    _session.recordDrill(d.lemma.id, d.kind, success: ok);
  }

  void _next() {
    if (_index + 1 >= _drills.length) {
      setState(() => _index = _drills.length);
      return;
    }
    setState(() {
      _index++;
      _chosen = null;
      _revealed = false;
    });
    _speakIfNeeded();
  }

  @override
  Widget build(BuildContext context) {
    final CityObjective? objective = _session.objectiveFor(widget.city.id);
    if (objective == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(KSpace.lg),
          child: _index >= _drills.length
              ? _Summary(
                  city: widget.city,
                  objective: objective,
                  correct: _correct,
                  total: _drills.length,
                  learnedNow:
                      objective.acquiredIn(_session.drills) - _wordsBefore,
                  onStamp: () {
                    _session.awardStamp(widget.city.id);
                    Navigator.of(context).pop();
                  },
                  onClose: () => Navigator.of(context).pop(),
                )
              : _Question(
                  drill: _drills[_index],
                  index: _index,
                  total: _drills.length,
                  chosen: _chosen,
                  revealed: _revealed,
                  onAnswer: _answer,
                  onNext: _next,
                  onReplay: _speakIfNeeded,
                  isLast: _index + 1 >= _drills.length,
                ),
        ),
      ),
    );
  }
}

class _Question extends StatelessWidget {
  const _Question({
    required this.drill,
    required this.index,
    required this.total,
    required this.chosen,
    required this.revealed,
    required this.onAnswer,
    required this.onNext,
    required this.onReplay,
    required this.isLast,
  });

  final Drill drill;
  final int index;
  final int total;
  final String? chosen;
  final bool revealed;
  final ValueChanged<String> onAnswer;
  final VoidCallback onNext;
  final VoidCallback onReplay;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final bool correct = chosen == drill.answer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
              color: KColors.encreDouce,
              tooltip: 'Quitter',
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: (index + 1) / total,
                  minHeight: 10,
                  backgroundColor: KColors.creuse,
                  color: KColors.lagon,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: KSpace.lg),
        Text(
          switch (drill.kind) {
            DrillKind.recognize => 'RECONNAÎTRE',
            DrillKind.recall => 'RETROUVER',
            DrillKind.listen => 'ÉCOUTER',
          },
          style: text.labelSmall,
        ),
        const SizedBox(height: KSpace.sm),
        Text(drill.prompt, style: text.headlineMedium),
        if (drill.spoken != null) ...<Widget>[
          const SizedBox(height: KSpace.md),
          KButton.ghost(label: '🔊  Réécouter', onPressed: onReplay),
        ],
        const SizedBox(height: KSpace.lg),
        for (final String option in drill.options)
          Padding(
            padding: const EdgeInsets.only(bottom: KSpace.sm),
            child: _Option(
              label: option,
              good: revealed && option == drill.answer,
              bad: revealed && option == chosen && option != drill.answer,
              onTap: () => onAnswer(option),
            ),
          ),
        const Spacer(),
        if (revealed) ...<Widget>[
          _Explanation(drill: drill, correct: correct),
          const SizedBox(height: KSpace.sm),
          KButton(label: isLast ? 'Terminer' : 'Continuer', onPressed: onNext),
        ],
      ],
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.label,
    required this.good,
    required this.bad,
    required this.onTap,
  });

  final String label;
  final bool good;
  final bool bad;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color border = good
        ? KColors.lagon
        : bad
            ? KColors.corail
            : KColors.trait;
    return Material(
      color: good
          ? KColors.lagon.withValues(alpha: 0.12)
          : bad
              ? KColors.corail.withValues(alpha: 0.10)
              : Colors.white,
      borderRadius: BorderRadius.circular(KSpace.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KSpace.radius),
        child: Ink(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(KSpace.radius),
            border: Border.all(color: border, width: 1.5),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: KSpace.md,
            vertical: 14,
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 15.5,
                ),
          ),
        ),
      ),
    );
  }
}

class _Explanation extends StatelessWidget {
  const _Explanation({required this.drill, required this.correct});

  final Drill drill;
  final bool correct;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(KSpace.md),
      decoration: BoxDecoration(
        color: (correct ? KColors.lagon : KColors.corail).withValues(
          alpha: 0.12,
        ),
        borderRadius: BorderRadius.circular(KSpace.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            correct ? 'Bien vu.' : 'Presque.',
            style: text.titleMedium?.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 2),
          Text(
            drill.lemma.note ?? '« ${drill.lemma.term} » = ${drill.lemma.fr}',
            style: text.bodyMedium?.copyWith(fontSize: 13.5),
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.city,
    required this.objective,
    required this.correct,
    required this.total,
    required this.learnedNow,
    required this.onStamp,
    required this.onClose,
  });

  final City city;
  final CityObjective objective;
  final int correct;
  final int total;
  final int learnedNow;
  final VoidCallback onStamp;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final KameoSession session = KameoScope.of(context);
    final int acquired = objective.acquiredIn(session.drills);
    final bool ready = objective.canStamp(session.drills);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: KSpace.lg),
        Text(city.emoji,
            style: const TextStyle(fontSize: 54), textAlign: TextAlign.center),
        const SizedBox(height: KSpace.sm),
        Text(
          ready ? 'Ville terminée !' : 'Session terminée',
          style: text.displayLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: KSpace.md),
        Container(
          padding: const EdgeInsets.all(KSpace.md),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(KSpace.radiusCard),
            border: Border.all(color: KColors.trait),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('$correct bonnes réponses sur $total',
                  style: text.titleMedium),
              const SizedBox(height: KSpace.xs),
              Text(
                learnedNow > 0
                    ? '$learnedNow mot${learnedNow > 1 ? 's' : ''} assimilé'
                        '${learnedNow > 1 ? 's' : ''} — réussi'
                        '${learnedNow > 1 ? 's' : ''} sur deux types '
                        'd\'exercice différents.'
                    : 'Aucun mot assimilé cette fois : un mot compte quand tu '
                        'le réussis à la fois en reconnaissance et en '
                        'restitution.',
                style: text.bodyMedium?.copyWith(fontSize: 13),
              ),
              const SizedBox(height: KSpace.md),
              Row(
                children: <Widget>[
                  Text('Vocabulaire de ${city.name}', style: text.labelSmall),
                  const Spacer(),
                  Text(
                    '$acquired/${objective.total}',
                    style: text.labelSmall,
                  ),
                ],
              ),
              const SizedBox(height: KSpace.xs),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: acquired / objective.total,
                  minHeight: 11,
                  backgroundColor: KColors.creuse,
                  color: ready ? KColors.soleil : KColors.lagon,
                ),
              ),
              const SizedBox(height: KSpace.sm),
              Text(
                ready
                    ? 'Objectif atteint : ${objective.required} mots suffisaient.'
                    : 'Encore ${objective.required - acquired} mot'
                        '${objective.required - acquired > 1 ? 's' : ''} pour '
                        'décrocher le tampon.',
                style: text.bodyMedium?.copyWith(fontSize: 12.5),
              ),
            ],
          ),
        ),
        const Spacer(),
        if (ready)
          KButton.go(label: '🛂  Obtenir le tampon', onPressed: onStamp)
        else
          KButton(label: 'Continuer à apprendre', onPressed: onClose),
        const SizedBox(height: KSpace.sm),
        KButton.ghost(label: 'Retour à la carte', onPressed: onClose),
      ],
    );
  }
}
