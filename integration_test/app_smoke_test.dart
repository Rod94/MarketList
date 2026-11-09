import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:market_list/app/app.dart';
import 'package:market_list/core/preferences/theme_preference.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('F0-06: abre aplicativo e seleciona AMOLED no dispositivo', (
    tester,
  ) async {
    await tester.pumpWidget(const MarketListApp());
    await tester.pumpAndSettle();
    expect(find.text('MarketList'), findsOneWidget);

    await tester.tap(find.byType(DropdownButton<ThemePreference>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AMOLED').last);
    await tester.pumpAndSettle();

    expect(
      Theme.of(tester.element(find.byType(Scaffold))).scaffoldBackgroundColor,
      const Color(0xFF000000),
    );
  });
}
