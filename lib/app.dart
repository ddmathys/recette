import 'package:flutter/material.dart';

import 'core/kameo_scope.dart';
import 'core/session.dart';
import 'core/theme/kameo_theme.dart';
import 'features/onboarding/onboarding_page.dart';

class KameoApp extends StatefulWidget {
  const KameoApp({super.key});

  @override
  State<KameoApp> createState() => _KameoAppState();
}

class _KameoAppState extends State<KameoApp> {
  final KameoSession _session = KameoSession();

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => KameoScope(
        notifier: _session,
        child: MaterialApp(
          title: 'Kameo',
          debugShowCheckedModeBanner: false,
          theme: KameoTheme.light(),
          home: const OnboardingPage(),
        ),
      );
}
