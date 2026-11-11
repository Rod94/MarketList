import 'package:flutter/foundation.dart';

import '../../core/preferences/theme_preference.dart';

class ThemeViewModel extends ChangeNotifier {
  ThemeViewModel({
    ThemePreference initialPreference = ThemePreference.system,
    this._persist,
  }) : _preference = initialPreference;

  ThemePreference _preference;
  final Future<void> Function(ThemePreference)? _persist;
  bool _saving = false;
  bool _disposed = false;
  String? _error;

  ThemePreference get preference => _preference;
  bool get isSaving => _saving;
  String? get error => _error;

  Future<void> selectTheme(ThemePreference preference) async {
    if (_preference == preference || _saving || _disposed) return;
    final persist = _persist;
    _error = null;
    if (persist != null) {
      _saving = true;
      notifyListeners();
      try {
        await persist(preference);
      } catch (_) {
        _error = 'Não foi possível salvar o tema. Tente novamente.';
      } finally {
        _saving = false;
      }
    }
    if (_disposed) return;
    if (_error == null) _preference = preference;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
