import 'package:flutter/foundation.dart';

import '../../../core/money/money.dart';
import '../../shopping/domain/models/shopping_snapshot.dart';
import '../../shopping/domain/shopping_repository.dart';

class CheckoutViewModel extends ChangeNotifier {
  CheckoutViewModel(this._review, {required this._persist});

  ShoppingSnapshot _review;
  final Future<void> Function(ShoppingSnapshot, int?) _persist;
  int? _paidCents;
  String? _paidError;
  String? _saveError;
  bool _saving = false;
  bool _disposed = false;
  bool _unavailable = false;

  ShoppingSnapshot get review => _review;
  int? get paidCents => _paidCents;
  String? get paidError => _paidError;
  String? get saveError => _saveError;
  bool get isSaving => _saving;
  bool get canConfirm =>
      !_saving && !_disposed && !_unavailable && _paidError == null;
  int? get differenceCents {
    final paid = _paidCents;
    return paid == null ? null : paid - review.calculation.totalCents;
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
    if (!canConfirm) return false;
    _saving = true;
    _saveError = null;
    notifyListeners();
    try {
      await _persist(review, paidCents);
      return !_disposed;
    } on ShoppingReviewChangedException catch (error) {
      _review = error.current;
      _saveError = 'A compra mudou. Confira os valores atualizados e confirme novamente.';
      return false;
    } on FinalizedShoppingListException {
      _unavailable = true;
      _saveError =
          'Esta compra já foi finalizada e está disponível para consulta.';
      return false;
    } on ShoppingListNotFoundException {
      _unavailable = true;
      _saveError = 'Esta compra não está mais disponível.';
      return false;
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
