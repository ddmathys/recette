import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kameo/core/content_repository.dart';
import 'package:kameo/core/kameo_scope.dart';
import 'package:kameo/core/session.dart';
import 'package:kameo/core/theme/kameo_theme.dart';
import 'package:kameo/features/map/map_page.dart';
import 'package:kameo_engine/kameo_engine.dart';

/// Charge le contenu depuis les assets.
///
/// `runAsync` est indispensable : hors de lui, l'attente d'un canal de
/// plateforme se fait dans la zone de faux temps du test et ne se résout
/// jamais. C'est ce qui faisait expirer ces tests au bout de dix minutes.
Future<KameoSession> sessionFor(
  WidgetTester tester,
  String lang,
  String countryId,
) async {
  final ContentRepository content = ContentRepository();
  final (List<Country>, Lexicon) loaded = (await tester.runAsync(() async {
    return (await content.countries(lang), await content.lexicon(lang));
  }))!;
  return KameoSession()
    ..chooseLanguage(lang)
    ..chooseDestination(
      loaded.$1.firstWhere((Country c) => c.id == countryId),
      loaded.$2,
    );
}

Widget wrap(KameoSession session) => KameoScope(
      notifier: session,
      child: MaterialApp(theme: KameoTheme.light(), home: const MapPage()),
    );

/// Rend à la taille d'un téléphone plutôt qu'au 800×600 par défaut.
///
/// La cible du produit est un écran de téléphone : tester à une autre taille
/// laisse passer des boutons hors de portée du pouce — ou hors de l'écran.
void usePhoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532); // iPhone 13, en pixels
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('la carte d Espagne affiche ses six villes', (
    WidgetTester tester,
  ) async {
    usePhoneScreen(tester);
    final KameoSession session = await sessionFor(tester, 'es', 'espana');
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
    usePhoneScreen(tester);
    final KameoSession session = await sessionFor(tester, 'en', 'usa');
    await tester.pumpWidget(wrap(session));
    await tester.pumpAndSettle();
    expect(find.text('New York'), findsWidgets);
    expect(find.text('Austin'), findsWidgets);
    expect(find.text('Barcelone'), findsNothing);
  });

  testWidgets('toucher une ville ouvre sa fiche et son expression locale', (
    WidgetTester tester,
  ) async {
    usePhoneScreen(tester);
    final KameoSession session = await sessionFor(tester, 'en', 'uk');
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
    usePhoneScreen(tester);
    final KameoSession session = await sessionFor(tester, 'es', 'espana');
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
    usePhoneScreen(tester);
    final KameoSession session = await sessionFor(tester, 'es', 'espana');
    session.stamps.add('barcelona');
    await tester.pumpWidget(wrap(session));
    await tester.pumpAndSettle();
    expect(session.currentCity?.id, 'valencia');
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.byIcon(Icons.lock), findsNWidgets(4));
  });
}
