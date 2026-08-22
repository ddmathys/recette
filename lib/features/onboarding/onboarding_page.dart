import 'package:flutter/material.dart';
import 'package:kameo_engine/kameo_engine.dart';

import '../../core/content_repository.dart';
import '../../core/kameo_scope.dart';
import '../../core/session.dart';
import '../../core/theme/kameo_colors.dart';
import '../../core/widgets/k_button.dart';
import '../../core/widgets/k_choice.dart';
import '../placement/placement_page.dart';
import '../map/map_page.dart';

/// Les trois questions du premier lancement (doc 01 §2).
///
/// Aucun compte n'est demandé ici : l'invitation viendra après le premier
/// tampon, au pic émotionnel.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final ContentRepository _content = ContentRepository();
  int _step = 0;
  List<Country> _destinations = const <Country>[];
  bool _loading = false;

  static const List<({String code, String label, String flag, String note})>
  _languages = <({String code, String label, String flag, String note})>[
    (
      code: 'es',
      label: 'Espagnol',
      flag: '🇪🇸',
      note: '6 villes · 5 niveaux',
    ),
    (
      code: 'en',
      label: 'Anglais',
      flag: '🇬🇧',
      note: '2 destinations au choix',
    ),
  ];

  Future<void> _pickLanguage(String code) async {
    final KameoSession session = KameoScope.of(context);
    session.chooseLanguage(code);
    setState(() => _loading = true);
    final List<Country> list = await _content.countries(code);
    if (!mounted) return;
    setState(() {
      _destinations = list;
      _loading = false;
      _step = 1;
    });
  }

  Future<void> _pickDestination(Country country) async {
    final KameoSession session = KameoScope.of(context);
    final Lexicon lex = await _content.lexicon(country.lang);
    if (!mounted) return;
    session.chooseDestination(country, lex);
    setState(() => _step = 2);
  }

  void _start({required bool withTest}) {
    final KameoSession session = KameoScope.of(context);
    if (withTest) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const PlacementPage()),
      );
    } else {
      session.startFromScratch();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const MapPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            KSpace.lg,
            KSpace.md,
            KSpace.lg,
            KSpace.lg,
          ),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : switch (_step) {
                  0 => _LanguageStep(languages: _languages, onPick: _pickLanguage),
                  1 => _DestinationStep(
                    destinations: _destinations,
                    onPick: _pickDestination,
                    onBack: () => setState(() => _step = 0),
                  ),
                  _ => _StartStep(
                    onStart: _start,
                    onBack: () => setState(() => _step = 1),
                  ),
                },
        ),
      ),
    );
  }
}

class _LanguageStep extends StatelessWidget {
  const _LanguageStep({required this.languages, required this.onPick});

  final List<({String code, String label, String flag, String note})> languages;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: KSpace.md),
        const Center(child: Text('🦎', style: TextStyle(fontSize: 62))),
        const SizedBox(height: KSpace.sm),
        Center(child: Text('Kameo', style: text.displayLarge)),
        const SizedBox(height: KSpace.xs),
        Text(
          'Apprends une langue en traversant le pays qui la parle.',
          textAlign: TextAlign.center,
          style: text.bodyMedium,
        ),
        const Spacer(),
        Text('QUELLE LANGUE VEUX-TU VIVRE ?', style: text.labelSmall),
        const SizedBox(height: KSpace.sm),
        for (final ({String code, String label, String flag, String note}) l
            in languages)
          Padding(
            padding: const EdgeInsets.only(bottom: KSpace.sm),
            child: KChoice(
              emoji: l.flag,
              title: l.label,
              subtitle: l.note,
              onTap: () => onPick(l.code),
            ),
          ),
      ],
    );
  }
}

class _DestinationStep extends StatelessWidget {
  const _DestinationStep({
    required this.destinations,
    required this.onPick,
    required this.onBack,
  });

  final List<Country> destinations;
  final ValueChanged<Country> onPick;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('ÉTAPE 2 SUR 3', style: text.labelSmall),
        const SizedBox(height: KSpace.xs),
        Text('Où veux-tu voyager ?', style: text.headlineMedium),
        const SizedBox(height: KSpace.sm),
        Text(
          'La destination change la carte, les villes — et l\'accent des voix '
          'que tu entendras.',
          style: text.bodyMedium,
        ),
        const SizedBox(height: KSpace.lg),
        for (final Country c in destinations)
          Padding(
            padding: const EdgeInsets.only(bottom: KSpace.sm),
            child: KChoice(
              emoji: c.flag,
              title: c.shortName,
              subtitle:
                  '${c.cities.map((City x) => x.name).take(3).join(' · ')}…',
              trailing: c.accent,
              onTap: () => onPick(c),
            ),
          ),
        const Spacer(),
        KButton.ghost(label: 'Retour', onPressed: onBack),
      ],
    );
  }
}

class _StartStep extends StatelessWidget {
  const _StartStep({required this.onStart, required this.onBack});

  final void Function({required bool withTest}) onStart;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('ÉTAPE 3 SUR 3', style: text.labelSmall),
        const SizedBox(height: KSpace.xs),
        Text('Tu pars d\'où ?', style: text.headlineMedium),
        const SizedBox(height: KSpace.sm),
        Text(
          'Trois secondes ici évitent deux frustrations : faire réviser '
          '« bonjour » à quelqu\'un qui a des bases, ou imposer un test à un '
          'vrai débutant.',
          style: text.bodyMedium,
        ),
        const SizedBox(height: KSpace.lg),
        KChoice(
          emoji: '🌱',
          title: 'Je pars de zéro',
          subtitle: 'On commence à la première ville, tour 1',
          onTap: () => onStart(withTest: false),
        ),
        const SizedBox(height: KSpace.sm),
        KChoice(
          emoji: '🧭',
          title: 'J\'ai quelques bases',
          subtitle: 'Test de placement · 3 min, sautable',
          onTap: () => onStart(withTest: true),
        ),
        const SizedBox(height: KSpace.sm),
        KChoice(
          emoji: '🗣️',
          title: 'Je me débrouille',
          subtitle: 'Test de placement · 3 min, sautable',
          onTap: () => onStart(withTest: true),
        ),
        const Spacer(),
        KButton.ghost(label: 'Retour', onPressed: onBack),
      ],
    );
  }
}
