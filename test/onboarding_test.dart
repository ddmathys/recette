import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kameo/core/content_repository.dart';
import 'package:kameo/core/kameo_scope.dart';
import 'package:kameo/core/session.dart';
import 'package:kameo/core/theme/kameo_theme.dart';
import 'package:kameo/features/onboarding/onboarding_page.dart';
import 'package:kameo_engine/kameo_engine.dart';

Widget wrap(Widget child, KameoSession session) => KameoScope(
      notifier: session,
      child: MaterialApp(theme: KameoTheme.light(), home: child),
    );

/// Préchauffe le cache d'assets.
///
/// `rootBundle` mémorise les futures déjà résolus : après ce passage, les
/// chargements déclenchés par l'app se terminent immédiatement. Sans lui,
/// l'attente se fait dans la zone de faux temps du test et ne se résout
/// jamais — c'est ce qui faisait expirer ces tests.
Future<ContentRepository> preloadContent(WidgetTester tester) async {
  final ContentRepository content = ContentRepository();
  await tester.runAsync(() async {
    for (final String lang in <String>['es', 'en']) {
      await content.countries(lang);
      await content.lexicon(lang);
    }
  });
  return content;
}

/// Pompe jusqu'à ce que [finder] trouve quelque chose, sans jamais attendre
/// la stabilisation complète.
///
/// `pumpAndSettle` ne peut pas servir ici : pendant un chargement, l'écran
/// affiche un indicateur de progression qui tourne sans fin, et « stabilisé »
/// n'arrive donc jamais.
Future<void> pumpUntil(
  WidgetTester tester,
  Finder finder, {
  int maxFrames = 40,
}) async {
  for (int i = 0; i < maxFrames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Rien trouvé pour $finder après $maxFrames images');
}

/// Rend à la taille d'un téléphone plutôt qu'au 800×600 par défaut.
void usePhoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('propose les deux langues au premier lancement', (
    WidgetTester tester,
  ) async {
    usePhoneScreen(tester);
    final ContentRepository content = await preloadContent(tester);
    await tester.pumpWidget(
      wrap(OnboardingPage(content: content), KameoSession()),
    );
    await tester.pump();
    expect(find.text('Kameo'), findsOneWidget);
    expect(find.text('Espagnol'), findsOneWidget);
    expect(find.text('Anglais'), findsOneWidget);
  });

  testWidgets('l anglais propose bien deux destinations', (
    WidgetTester tester,
  ) async {
    usePhoneScreen(tester);
    final ContentRepository content = await preloadContent(tester);
    await tester.pumpWidget(
      wrap(OnboardingPage(content: content), KameoSession()),
    );
    await tester.pump();
    await tester.tap(find.text('Anglais'));
    await pumpUntil(tester, find.text('Où veux-tu voyager ?'));
    expect(find.text('Où veux-tu voyager ?'), findsOneWidget);
    expect(find.text('Royaume-Uni'), findsOneWidget);
    expect(find.text('États-Unis'), findsOneWidget);
    // La destination porte son accent : c'est la promesse du concept.
    expect(find.text('Britannique'), findsOneWidget);
    expect(find.text('Américain'), findsOneWidget);
  });

  testWidgets('l espagnol n a qu une destination au MVP', (
    WidgetTester tester,
  ) async {
    usePhoneScreen(tester);
    final ContentRepository content = await preloadContent(tester);
    await tester.pumpWidget(
      wrap(OnboardingPage(content: content), KameoSession()),
    );
    await tester.pump();
    await tester.tap(find.text('Espagnol'));
    await pumpUntil(tester, find.text('Espagne'));
    expect(find.text('Espagne'), findsOneWidget);
    expect(find.text('Royaume-Uni'), findsNothing);
  });

  testWidgets('choisir une destination mène à la question du niveau', (
    WidgetTester tester,
  ) async {
    usePhoneScreen(tester);
    final ContentRepository content = await preloadContent(tester);
    final KameoSession session = KameoSession();
    await tester.pumpWidget(
      wrap(OnboardingPage(content: content), session),
    );
    await tester.pump();
    await tester.tap(find.text('Espagnol'));
    await pumpUntil(tester, find.text('Espagne'));
    await tester.tap(find.text('Espagne'));
    await pumpUntil(tester, find.text('Tu pars d\'où ?'));
    expect(find.text('Tu pars d\'où ?'), findsOneWidget);
    expect(session.country?.id, 'espana');
    expect(session.lexicon, isNotNull);
  });

  test('le catalogue déclare bien les trois destinations', () async {
    expect(ContentRepository.catalogue['es'], <String>['espana']);
    expect(ContentRepository.catalogue['en'], <String>['uk', 'usa']);
  });

  // `testWidgets` + `runAsync` plutôt qu'un `test` simple : charger un asset
  // demande un vrai tour de boucle d'événements, que la zone de faux temps
  // d'un test ne fournit pas.
  testWidgets('le répertoire de voyage suit la variante de la destination', (
    WidgetTester tester,
  ) async {
    final ContentRepository content = await preloadContent(tester);
    final (List<Country>, Lexicon) loaded = (await tester.runAsync(() async {
      return (await content.countries('en'), await content.lexicon('en'));
    }))!;
    final List<Country> countries = loaded.$1;
    final Lexicon full = loaded.$2;
    final KameoSession session = KameoSession();

    session.chooseDestination(
      countries.firstWhere((Country c) => c.id == 'uk'),
      full,
    );
    final List<String> uk =
        session.travelLexicon.lemmas.map((Lemma l) => l.term).toList();
    session.chooseDestination(
      countries.firstWhere((Country c) => c.id == 'usa'),
      full,
    );
    final List<String> us =
        session.travelLexicon.lemmas.map((Lemma l) => l.term).toList();

    expect(uk, contains('the tube'));
    expect(uk, isNot(contains('subway')));
    expect(us, contains('subway'));
    expect(us, isNot(contains('the tube')));
  });
}
