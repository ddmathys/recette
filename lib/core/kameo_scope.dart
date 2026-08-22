import 'package:flutter/widgets.dart';

import 'session.dart';

/// Donne accès à la session depuis n'importe quel écran.
class KameoScope extends InheritedNotifier<KameoSession> {
  const KameoScope({
    required KameoSession super.notifier,
    required super.child,
    super.key,
  });

  static KameoSession of(BuildContext context) {
    final KameoScope? scope =
        context.dependOnInheritedWidgetOfExactType<KameoScope>();
    assert(scope != null, 'Aucun KameoScope au-dessus de ce widget');
    return scope!.notifier!;
  }
}
