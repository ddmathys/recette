import 'dart:math';

import 'package:flutter/material.dart';
import 'package:kameo_engine/kameo_engine.dart';

import '../../core/kameo_scope.dart';
import '../../core/session.dart';
import '../../core/speech.dart';
import '../../core/theme/kameo_colors.dart';
import '../../core/widgets/k_button.dart';
import 'result_page.dart';

/// Le test de placement, branché sur le moteur.
///
/// L'écran ne sait rien de l'algorithme : il pose la question que le moteur
/// lui donne et lui renvoie la réponse. Toute la logique — escalier, notation
/// par maximum a posteriori, règle d'arrêt — vit dans `PlacementEngine`.
class PlacementPage extends StatefulWidget {
  const PlacementPage({super.key});

  @override
  State<PlacementPage> createState() => _PlacementPageState();
}

class _PlacementPageState extends State<PlacementPage> {
  late final KameoSession _session = KameoScope.of(context);
  late final Lexicon _lexicon = _session.travelLexicon;
  late final PlacementEngine _engine = PlacementEngine(_lexicon);
  final Random _rng = Random();

  PlacementQuestion? _question;
  List<String> _options = const <String>[];
  String? _chosen;
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _nextQuestion());
  }

  @override
  void dispose() {
    Speech.instance.stop();
    super.dispose();
  }

  void _nextQuestion() {
    final PlacementQuestion? q = _engine.next();
    if (q == null) {
      _finish();
      return;
    }
    final List<String> options = _buildOptions(q);
    setState(() {
      _question = q;
      _options = options;
      _chosen = null;
      _revealed = false;
    });
    if (q.format == PlacementFormat.listen) _speak(q);
  }

  List<String> _buildOptions(PlacementQuestion q) {
    final bool wantTerm = q.format == PlacementFormat.produce;
    final List<Lemma> others = _lexicon.distractors(q.lemma, 3, _rng);
    final List<String> options = <String>[
      q.expected,
      for (final Lemma l in others) wantTerm ? l.term : l.fr,
    ];
    // Un piège mérite son leurre : le sens que le francophone attend.
    if (q.isTrap && q.lemma.note != null && options.length > 1) {
      options[1] = _lureFor(q.lemma) ?? options[1];
    }
    final List<String> unique = <String>[];
    for (final String o in options) {
      if (!unique.any((String x) => x.toLowerCase() == o.toLowerCase())) {
        unique.add(o);
      }
    }
    return unique..shuffle(_rng);
  }

  /// Le faux sens qu'un francophone plaquerait spontanément sur le mot.
  String? _lureFor(Lemma lemma) {
    final String t = lemma.term.toLowerCase();
    const Map<String, String> lures = <String, String>{
      'salir': 'salir (rendre sale)',
      'largo': 'large',
      'ropa': 'une corde',
      'quitar': 'quitter',
      'subir': 'subir (endurer)',
      'entender': 'entendre',
      'éxito': 'la sortie',
      'constipado': 'constipé',
      'embarazada': 'embarrassée',
      'discutir': 'discuter calmement',
      'actually': 'actuellement',
      'eventually': 'éventuellement',
      'library': 'une librairie',
      'sensible': 'sensible (émotif)',
      'to attend': 'attendre',
      'to achieve': 'achever',
      'location': 'une location',
      'journey': 'une journée',
      'lecture': 'la lecture',
      'to resume': 'résumer',
      'prune': 'une prune',
      'raisin': 'du raisin frais',
      'coin': 'un coin',
      'chair': 'la chair',
      'car': 'un car',
    };
    return lures[t];
  }

  Future<void> _speak(PlacementQuestion q) => Speech.instance.say(
    q.lemma.term,
    locale: _session.country?.ttsLocale ?? 'es-ES',
  );

  void _answer(String option) {
    if (_revealed) return;
    final PlacementQuestion q = _question!;
    setState(() {
      _chosen = option;
      _revealed = true;
    });
    _engine.submit(correct: option == q.expected);
    Future<void>.delayed(
      Duration(milliseconds: option == q.expected ? 700 : 1600),
      () {
        if (mounted) _nextQuestion();
      },
    );
  }

  void _finish() {
    final PlacementResult result = _engine.result();
    _session.completePlacement(result);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ResultPage(result: result, engine: _engine),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final PlacementQuestion? q = _question;
    final double progress = (_engine.asked / 16).clamp(0.0, 1.0);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(KSpace.lg),
          child: q == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        IconButton(
                          onPressed: _finish,
                          icon: const Icon(Icons.close),
                          color: KColors.encreDouce,
                          tooltip: 'Arrêter le test',
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: progress,
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
                      'QUESTION ${_engine.asked + 1}'
                      '${q.isTrap ? ' · ATTENTION' : ''}',
                      style: text.labelSmall,
                    ),
                    const SizedBox(height: KSpace.sm),
                    Text(q.prompt, style: text.headlineMedium),
                    if (q.format == PlacementFormat.listen) ...<Widget>[
                      const SizedBox(height: KSpace.md),
                      KButton.ghost(
                        label: '🔊  Réécouter',
                        onPressed: () => _speak(q),
                      ),
                    ],
                    const SizedBox(height: KSpace.lg),
                    for (final String option in _options)
                      Padding(
                        padding: const EdgeInsets.only(bottom: KSpace.sm),
                        child: _OptionTile(
                          label: option,
                          state: !_revealed
                              ? _OptionState.idle
                              : option == q.expected
                              ? _OptionState.good
                              : option == _chosen
                              ? _OptionState.bad
                              : _OptionState.idle,
                          onTap: () => _answer(option),
                        ),
                      ),
                    const Spacer(),
                    if (_revealed)
                      _Feedback(
                        correct: _chosen == q.expected,
                        lemma: q.lemma,
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

enum _OptionState { idle, good, bad }

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.state,
    required this.onTap,
  });

  final String label;
  final _OptionState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color border = switch (state) {
      _OptionState.good => KColors.lagon,
      _OptionState.bad => KColors.corail,
      _OptionState.idle => KColors.trait,
    };
    final Color fill = switch (state) {
      _OptionState.good => KColors.lagon.withValues(alpha: 0.12),
      _OptionState.bad => KColors.corail.withValues(alpha: 0.10),
      _OptionState.idle => Colors.white,
    };
    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(KSpace.radius),
      child: InkWell(
        onTap: state == _OptionState.idle ? onTap : null,
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

class _Feedback extends StatelessWidget {
  const _Feedback({required this.correct, required this.lemma});

  final bool correct;
  final Lemma lemma;

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
            lemma.note ?? '« ${lemma.term} » = ${lemma.fr}',
            style: text.bodyMedium?.copyWith(fontSize: 13.5),
          ),
        ],
      ),
    );
  }
}
