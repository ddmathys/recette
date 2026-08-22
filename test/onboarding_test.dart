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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('propose les deux langues au premier lancement', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(wrap(const OnboardingPage(), KameoSession()));
    await tester.pumpAndSettle();
    expect(find.text('Kameo'), findsOneWidget);
    expect(find.text('Espagnol'), findsOneWidget);
    expect(find.text('Anglais'), findsOneWidget);
  });

  testWidgets('l anglais propose bien deux destinations', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(wrap(const OnboardingPage(), KameoSession()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anglais'));
    await tester.pumpAndSettle();
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
    await tester.pumpWidget(wrap(const OnboardingPage(), KameoSession()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Espagnol'));
    await tester.pumpAndSettle();
    expect(find.text('Espagne'), findsOneWidget);
    expect(find.text('Royaume-Uni'), findsNothing);
  });

  testWidgets('choisir une destination mène à la question du niveau', (
    WidgetTester tester,
  ) async {
    final KameoSession session = KameoSession();
    await tester.pumpWidget(wrap(const OnboardingPage(), session));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Espagnol'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Espagne'));
    await tester.pumpAndSettle();
    expect(find.text('Tu pars d\'où ?'), findsOneWidget);
    expect(session.country?.id, 'espana');
    expect(session.lexicon, isNotNull);
  });

  test('le catalogue déclare bien les trois destinations', () async {
    expect(ContentRepository.catalogue['es'], <String>['espana']);
    expect(ContentRepository.catalogue['en'], <String>['uk', 'usa']);
  });

  test('le répertoire de voyage suit la variante de la destination', () async {
    final ContentRepository content = ContentRepository();
    final List<Country> countries = await content.countries('en');
    final Lexicon full = await content.lexicon('en');
    final KameoSession session = KameoSession();

    session.chooseDestination(
      countries.firstWhere((Country c) => c.id == 'uk'),
      full,
    );
    final List<String> uk = session.travelLexicon.lemmas
        .map((Lemma l) => l.term)
        .toList();
    session.chooseDestination(
      countries.firstWhere((Country c) => c.id == 'usa'),
      full,
    );
    final List<String> us = session.travelLexicon.lemmas
        .map((Lemma l) => l.term)
        .toList();

    expect(uk, contains('the tube'));
    expect(uk, isNot(contains('subway')));
    expect(us, contains('subway'));
    expect(us, isNot(contains('the tube')));
  });
}
