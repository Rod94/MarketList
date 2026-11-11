import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:market_list/app/theme/app_theme.dart';

void main() {
  double contrast(Color foreground, Color background) {
    final first = foreground.computeLuminance();
    final second = background.computeLuminance();
    return (math.max(first, second) + .05) / (math.min(first, second) + .05);
  }

  for (final (name, theme) in [
    ('Claro', AppTheme.light),
    ('AMOLED', AppTheme.amoled),
  ]) {
    test('F7-04 contraste de texto e ação em $name', () {
      final colors = theme.colorScheme;
      for (final (label, foreground, background) in [
        ('texto principal', colors.onSurface, theme.scaffoldBackgroundColor),
        (
          'texto secundário',
          colors.onSurfaceVariant,
          theme.scaffoldBackgroundColor,
        ),
        (
          'texto secundário em painel',
          colors.onSurfaceVariant,
          colors.surfaceContainer,
        ),
        ('texto do botão preenchido', colors.onPrimary, colors.primary),
      ]) {
        expect(
          contrast(foreground, background),
          greaterThanOrEqualTo(4.5),
          reason: label,
        );
      }
    });
  }
}
