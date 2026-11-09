import 'package:flutter/foundation.dart';

import '../../core/preferences/theme_preference.dart';

class ThemeViewModel extends ChangeNotifier {
  ThemePreference _preference = ThemePreference.system;

  ThemePreference get preference => _preference;

  void selectTheme(ThemePreference preference) {
    if (_preference == preference) return;
    _preference = preference;
    notifyListeners();
  }
}
