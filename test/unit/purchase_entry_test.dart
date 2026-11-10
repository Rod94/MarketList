import 'package:flutter_test/flutter_test.dart';
import 'package:market_list/core/money/money.dart';
import 'package:market_list/features/shopping/domain/models/purchase_entry.dart';

void main() {
  test(
    'F3-02 / CT-008: quantidade × preço conserva dados e subtotal exato',
    () {
      final entry = PurchaseEntry(
        id: 'entry',
        shoppingItemId: 'item',
        quantity: 3,
        unitPriceCents: 422,
      );
      expect(entry.id, 'entry');
      expect(entry.shoppingItemId, 'item');
      expect(entry.quantity, 3);
      expect(entry.unitPriceCents, 422);
      expect(entry.directAmountCents, isNull);
      expect(entry.subtotalCents, 1266);
      expect(entry.isDirect, isFalse);
    },
  );
  test(
    'F3-02 / CT-020: valor direto não inventa quantidade ou preço unitário',
    () {
      final entry = PurchaseEntry(
        id: 'entry',
        shoppingItemId: 'item',
        directAmountCents: 4782,
      );
      expect(entry.quantity, isNull);
      expect(entry.unitPriceCents, isNull);
      expect(entry.subtotalCents, 4782);
      expect(entry.isDirect, isTrue);
    },
  );
  test('D-028: zero explícito é entrada válida nos dois modos', () {
    expect(
      PurchaseEntry(
        id: 'a',
        shoppingItemId: 'item',
        quantity: 2,
        unitPriceCents: 0,
      ).subtotalCents,
      0,
    );
    final direct = PurchaseEntry(
      id: 'b',
      shoppingItemId: 'item',
      directAmountCents: 0,
    );
    expect(direct.isDirect, isTrue);
    expect(direct.directAmountCents, 0);
  });
  for (final invalid in [
    <String, int?>{},
    {'quantity': 1},
    {'unit': 100},
    {'quantity': 1, 'direct': 100},
    {'unit': 100, 'direct': 100},
    {'quantity': 1, 'unit': 100, 'direct': 100},
    {'quantity': 0, 'unit': 100},
    {'quantity': -1, 'unit': 100},
    {'quantity': 1, 'unit': -1},
    {'direct': -1},
  ]) {
    test('F3-02: recusa modo incompleto/misto ou valor inválido $invalid', () {
      expect(
        () => PurchaseEntry(
          id: 'entry',
          shoppingItemId: 'item',
          quantity: invalid['quantity'],
          unitPriceCents: invalid['unit'],
          directAmountCents: invalid['direct'],
        ),
        throwsArgumentError,
      );
    });
  }
  for (final invalid in ['', ' ', '\t\n']) {
    test('ID e vínculo não podem ser vazios ${invalid.codeUnits}', () {
      expect(
        () => PurchaseEntry(
          id: invalid,
          shoppingItemId: 'item',
          directAmountCents: 1,
        ),
        throwsArgumentError,
      );
      expect(
        () => PurchaseEntry(
          id: 'entry',
          shoppingItemId: invalid,
          directAmountCents: 1,
        ),
        throwsArgumentError,
      );
    });
  }
  test('IDs opacos são preservados sem normalização', () {
    final entry = PurchaseEntry(
      id: 'opaque id',
      shoppingItemId: 'item id',
      directAmountCents: 1,
    );
    expect(entry.id, 'opaque id');
    expect(entry.shoppingItemId, 'item id');
  });
  test('D-029: subtotal fora de int64 falha ao construir', () {
    expect(
      () => PurchaseEntry(
        id: 'entry',
        shoppingItemId: 'item',
        quantity: 2,
        unitPriceCents: maxMoneyCents,
      ),
      throwsRangeError,
    );
    expect(
      PurchaseEntry(
        id: 'entry',
        shoppingItemId: 'item',
        quantity: 1,
        unitPriceCents: maxMoneyCents,
      ).subtotalCents,
      maxMoneyCents,
    );
  });
}
