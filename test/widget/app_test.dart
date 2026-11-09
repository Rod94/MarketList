import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:market_list/app/app.dart';
import 'package:market_list/core/preferences/theme_preference.dart';

void main() {
  testWidgets('F0-05: aplicativo abre com a demonstração de temas', (
    tester,
  ) async {
    await tester.pumpWidget(const MarketListApp());

    expect(find.text('MarketList'), findsOneWidget);
    expect(find.text('Aparência'), findsOneWidget);
    expect(find.text('Sistema'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('F0-04 / UX-009: alterna AMOLED preto e claro', (tester) async {
    await tester.pumpWidget(const MarketListApp());

    await tester.tap(find.byType(DropdownButton<ThemePreference>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AMOLED').last);
    await tester.pumpAndSettle();

    var theme = Theme.of(tester.element(find.byType(Scaffold)));
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, const Color(0xFF000000));
    expect(theme.colorScheme.surface, const Color(0xFF000000));

    await tester.tap(find.byType(DropdownButton<ThemePreference>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Claro').last);
    await tester.pumpAndSettle();

    theme = Theme.of(tester.element(find.byType(Scaffold)));
    expect(theme.brightness, Brightness.light);
    expect(theme.scaffoldBackgroundColor, const Color(0xFFFFFFFF));
    expect(tester.takeException(), isNull);
  });

  testWidgets('F0-04: modo sistema acompanha brilho do dispositivo', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(const MarketListApp());

    expect(
      Theme.of(tester.element(find.byType(Scaffold))).scaffoldBackgroundColor,
      const Color(0xFF000000),
    );

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(Scaffold))).brightness,
      Brightness.light,
    );
  });

  testWidgets('F0-04 / UX-018: tela pequena com fonte ampliada', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(const MarketListApp());
    await tester.tap(find.byType(DropdownButton<ThemePreference>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AMOLED').last);
    await tester.pumpAndSettle();

    expect(find.text('AMOLED'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
