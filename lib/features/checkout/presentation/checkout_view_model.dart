import 'package:flutter/foundation.dart';

import '../../../core/money/money.dart';
import '../../shopping/domain/models/shopping_list.dart';
import '../../shopping/domain/shopping_calculator.dart';

class CheckoutViewModel extends ChangeNotifier {
  CheckoutViewModel(this.list, this.calculation, {this._persist});

  final ShoppingList list;
  final ShoppingCalculation calculation;
  final Future<void> Function(ShoppingList, ShoppingCalculation, int?)?
  _persist;
  int? _paidCents;
  String? _paidError;
  String? _saveError;
  bool _saving = false;
  bool _disposed = false;

  int? get paidCents => _paidCents;
  String? get paidError => _paidError;
  String? get saveError => _saveError;
  bool get isSaving => _saving;
  bool get hasConfirmation => _persist != null;
  bool get canConfirm =>
      hasConfirmation && !_saving && !_disposed && _paidError == null;
  int? get differenceCents {
    final paid = _paidCents;
    return paid == null ? null : paid - calculation.totalCents;
  }

  void setPaidInput(String input) {
    if (_saving || _disposed) return;
    try {
      _paidCents = parseMoneyCents(input);
      _paidError = null;
    } on FormatException catch (error) {
      _paidCents = null;
      _paidError = error.message;
    }
    notifyListeners();
  }

  Future<bool> confirm() async {
    final persist = _persist;
    if (persist == null || !canConfirm) return false;
    _saving = true;
    _saveError = null;
    notifyListeners();
    try {
      await persist(list, calculation, paidCents);
      return !_disposed;
    } catch (_) {
      _saveError = 'Não foi possível finalizar. O valor digitado foi mantido.';
      return false;
    } finally {
      _saving = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
