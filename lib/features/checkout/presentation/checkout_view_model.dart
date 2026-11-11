import 'package:flutter/foundation.dart';

import '../../../core/money/money.dart';
import '../../shopping/domain/models/shopping_list.dart';
import '../../shopping/domain/shopping_calculator.dart';

class CheckoutViewModel extends ChangeNotifier {
  CheckoutViewModel(this.list, this.calculation);

  final ShoppingList list;
  final ShoppingCalculation calculation;
  int? _paidCents;
  String? _paidError;

  int? get paidCents => _paidCents;
  String? get paidError => _paidError;
  int? get differenceCents {
    final paid = _paidCents;
    return paid == null ? null : paid - calculation.totalCents;
  }

  void setPaidInput(String input) {
    try {
      _paidCents = parseMoneyCents(input);
      _paidError = null;
    } on FormatException catch (error) {
      _paidCents = null;
      _paidError = error.message;
    }
    notifyListeners();
  }
}
