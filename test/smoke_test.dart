import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kameo/core/theme/kameo_colors.dart';
import 'package:kameo/core/theme/kameo_theme.dart';

void main() {
  test('le thème porte bien la palette Kameo', () {
    final ThemeData t = KameoTheme.light();
    expect(t.colorScheme.primary, KColors.corail);
    expect(t.scaffoldBackgroundColor, KColors.creme);
  });
}
