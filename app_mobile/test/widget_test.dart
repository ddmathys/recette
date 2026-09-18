// Full-app widget tests would need a mocked Firebase (Firebase.initializeApp
// touches platform channels unavailable under flutter_test) — out of scope
// for this pass. This covers the one bit of pure logic worth a regression
// test: the category fallback that keeps an unknown `cat` value (e.g. a
// stale client, or a doc edited outside the app) from crashing the UI —
// mirrors the same guard in ../../src/lib/categories.ts.
import 'package:flutter_test/flutter_test.dart';
import 'package:recettes_du_tiroir/models.dart';

void main() {
  test('categoryFor falls back to a default for an unknown category key', () {
    final known = categoryFor('dessert');
    expect(known.key, 'dessert');

    final unknown = categoryFor('not-a-real-category');
    expect(unknown, kDefaultCategory);
  });
}
