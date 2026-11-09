import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:market_list/app/app.dart';
import 'package:market_list/core/preferences/theme_preference.dart';

import '../support/fake_shopping_repository.dart';

void main() {
  Future<void> openAppearance(WidgetTester tester) async {
    await tester.pumpWidget(
      MarketListApp(repository: FakeShoppingRepository()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Minhas listas'), findsOneWidget);
    await tester.tap(find.byTooltip('Aparência'));
    await tester.pumpAndSettle();
  }

  testWidgets('F0-05 / F1-04: aplicativo abre listas e permite acessar temas', (
    tester,
  ) async {
    await openAppearance(tester);

    expect(find.text('MarketList'), findsOneWidget);
    expect(find.text('Aparência'), findsOneWidget);
    expect(find.text('Sistema'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('F0-04 / UX-009: alterna AMOLED preto e claro', (tester) async {
    await openAppearance(tester);

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
    await openAppearance(tester);

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

    await openAppearance(tester);
    await tester.tap(find.byType(DropdownButton<ThemePreference>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AMOLED').last);
    await tester.pumpAndSettle();

    expect(find.text('AMOLED'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
