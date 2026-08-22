import 'package:flutter/material.dart';

import 'core/theme/kameo_theme.dart';
import 'features/home/home_page.dart';

class KameoApp extends StatelessWidget {
  const KameoApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Kameo',
    debugShowCheckedModeBanner: false,
    theme: KameoTheme.light(),
    home: const HomePage(),
  );
}
