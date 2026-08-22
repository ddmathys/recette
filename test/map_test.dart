import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kameo/core/content_repository.dart';
import 'package:kameo/core/kameo_scope.dart';
import 'package:kameo/core/session.dart';
import 'package:kameo/core/theme/kameo_theme.dart';
import 'package:kameo/features/map/map_page.dart';
import 'package:kameo_engine/kameo_engine.dart';

Future<KameoSession> sessionFor(String lang, String countryId) async {
  final ContentRepository content = ContentRepository();
  final List<Country> countries = await content.countries(lang);
  final Lexicon lex = await content.lexicon(lang);
  return KameoSession()
    ..chooseLanguage(lang)
    ..chooseDestination(
      countries.firstWhere((Country c) => c.id == countryId),
      lex,
    );
}

Widget wrap(KameoSession session) => KameoScope(
  notifier: session,
  child: MaterialApp(theme: KameoTheme.light(), home: const MapPage()),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('la carte d Espagne affiche ses six villes', (
    WidgetTester tester,
  ) async {
    final KameoSession session = await sessionFor('es', 'espana');
    await tester.pumpWidget(wrap(session));
    await tester.pumpAndSettle();

    for (final String name in <String>[
      'Barcelone',
      'Valence',
      'Grenade',
      'Séville',
      'Madrid',
      'Bilbao',
    ]) {
      expect(find.text(name), findsWidgets, reason: name);
    }
    expect(find.text('Espagne · Tour 1'), findsOneWidget);
    expect(find.text('0/6'), findsOneWidget);
  });

  testWidgets('la carte des États-Unis affiche ses propres villes', (
    WidgetTester tester,
  ) async {
    final KameoSession session = await sessionFor('en', 'usa');
    await tester.pumpWidget(wrap(session));
    await tester.pumpAndSettle();
    expect(find.text('New York'), findsWidgets);
    expect(find.text('Austin'), findsWidgets);
    expect(find.text('Barcelone'), findsNothing);
  });

  testWidgets('toucher une ville ouvre sa fiche et son expression locale', (
    WidgetTester tester,
  ) async {
    final KameoSession session = await sessionFor('en', 'uk');
    await tester.pumpWidget(wrap(session));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Découvrir la ville'));
    await tester.pumpAndSettle();

    expect(find.text('EXPRESSION LOCALE'), findsOneWidget);
    expect(find.text('Mind the gap!'), findsOneWidget);
  });

  testWidgets('les villes suivantes sont verrouillées', (
    WidgetTester tester,
  ) async {
    final KameoSession session = await sessionFor('es', 'espana');
    await tester.pumpWidget(wrap(session));
    await tester.pumpAndSettle();
    // Rien n'est tamponné : la première ville est en cours, les cinq autres
    // sont verrouillées.
    expect(find.byIcon(Icons.lock), findsNWidgets(5));
    expect(find.byIcon(Icons.check), findsNothing);
  });

  testWidgets('un tampon obtenu déverrouille la ville suivante', (
    WidgetTester tester,
  ) async {
    final KameoSession session = await sessionFor('es', 'espana');
    session.stamps.add('barcelona');
    await tester.pumpWidget(wrap(session));
    await tester.pumpAndSettle();
    expect(session.currentCity?.id, 'valencia');
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.byIcon(Icons.lock), findsNWidgets(4));
  });
}
