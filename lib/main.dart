import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/preferences/theme_preference.dart';
import 'core/preferences/theme_preference_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = ThemePreferenceStore();
  var theme = ThemePreference.system;
  try {
    theme = await preferences.read();
  } catch (_) {
    debugPrint('MarketList: não foi possível ler a preferência de aparência.');
  }
  runApp(MarketListApp(initialTheme: theme, persistTheme: preferences.save));
}
