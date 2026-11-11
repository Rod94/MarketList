import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:market_list/features/checkout/presentation/checkout_view_model.dart';
import 'package:market_list/features/shopping/domain/models/shopping_list.dart';
import 'package:market_list/features/shopping/domain/models/shopping_snapshot.dart';
import 'package:market_list/features/shopping/domain/shopping_calculator.dart';

void main() {
  final list = ShoppingList(
    id: 'list',
    name: 'Mercado',
    createdAt: DateTime.utc(2026),
  );
  final calculation = calculateShoppingList(
    shoppingListId: list.id,
    items: [],
    entries: [],
  );

  test(
    'FIN-008 espera a gravação e aceita somente uma confirmação simultânea',
    () async {
      final result = Completer<void>();
      final values = <int?>[];
      final model = CheckoutViewModel(
        ShoppingSnapshot(list, calculation),
        persist: (_, paid) {
          values.add(paid);
          return result.future;
        },
      );
      addTearDown(model.dispose);
      final confirming = model.confirm();
      expect(model.isSaving, isTrue);
      expect(await model.confirm(), isFalse);
      expect(values, [null]);
      result.complete();
      expect(await confirming, isTrue);
      expect(model.isSaving, isFalse);
    },
  );

  test(
    'FIN-017/024 recusa formato inválido e permite tentar novamente',
    () async {
      final values = <int?>[];
      final model = CheckoutViewModel(
        ShoppingSnapshot(list, calculation),
        persist: (_, paid) async {
          values.add(paid);
          if (values.length == 1) throw StateError('Falha de gravação');
        },
      );
      addTearDown(model.dispose);
      model.setPaidInput('1,234');
      expect(await model.confirm(), isFalse);
      expect(values, isEmpty);
      model.setPaidInput('2,40');
      expect(await model.confirm(), isFalse);
      expect(model.saveError, isNotNull);
      expect(model.paidCents, 240);
      expect(await model.confirm(), isTrue);
      expect(values, [240, 240]);
    },
  );
}
