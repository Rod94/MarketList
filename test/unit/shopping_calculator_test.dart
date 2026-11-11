import 'package:flutter_test/flutter_test.dart';
import 'package:market_list/core/money/money.dart';
import 'package:market_list/features/shopping/domain/models/purchase_entry.dart';
import 'package:market_list/features/shopping/domain/models/shopping_item.dart';
import 'package:market_list/features/shopping/domain/shopping_calculator.dart';

void main() {
  ShoppingItem item({
    String id = 'item',
    int? planned = 5,
    int order = 0,
    bool removed = false,
  }) => ShoppingItem(
    id: id,
    shoppingListId: 'list',
    name: id,
    plannedQuantity: planned,
    origin: ShoppingItemOrigin.planned,
    sortOrder: order,
    removedAt: removed ? DateTime.utc(2026) : null,
  );
  PurchaseEntry units({
    String id = 'entry',
    String itemId = 'item',
    int quantity = 3,
    int price = 350,
  }) => PurchaseEntry(
    id: id,
    shoppingItemId: itemId,
    quantity: quantity,
    unitPriceCents: price,
  );
  PurchaseEntry direct({
    String id = 'direct',
    String itemId = 'item',
    int amount = 4782,
  }) =>
      PurchaseEntry(id: id, shoppingItemId: itemId, directAmountCents: amount);
  ShoppingCalculation calc(
    List<ShoppingItem> items,
    List<PurchaseEntry> entries,
  ) => calculateShoppingList(
    shoppingListId: 'list',
    items: items,
    entries: entries,
  );

  test(
    'CT-009/010: exemplos sabonete + leite + carne totalizam 7938 centavos',
    () {
      final result = calc(
        [
          item(id: 'soap'),
          item(id: 'milk', planned: null),
          item(id: 'meat', planned: null),
        ],
        [
          units(id: 's1', itemId: 'soap'),
          units(id: 's2', itemId: 'soap', quantity: 2, price: 420),
          units(id: 'm', itemId: 'milk', quantity: 3, price: 422),
          direct(itemId: 'meat'),
        ],
      );
      expect(result.totalCents, 7938);
      expect(
        result.items.firstWhere((s) => s.item.id == 'soap').subtotalCents,
        1890,
      );
    },
  );
  test('vazio é zero e não exige orçamento', () {
    expect(calc([], []).totalCents, 0);
  });

  test('FIN-002/003/013 reúne avisos na ordem de cadastro', () {
    final result = calc(
      [
        item(id: 'sabao', order: 4),
        item(id: 'cafe', order: 2),
        item(id: 'arroz', order: 3, removed: true),
        item(id: 'azeite', order: 1, planned: null),
        item(id: 'brinde', order: 5, planned: null),
      ],
      [
        units(itemId: 'sabao'),
        units(id: 'cafe-unidades', itemId: 'cafe', quantity: 5),
        direct(id: 'cafe-direto', itemId: 'cafe', amount: 500),
        units(id: 'arroz-unidades', itemId: 'arroz'),
        direct(id: 'gratuito', itemId: 'brinde', amount: 0),
      ],
    );
    final attention = result.itemsNeedingAttention.toList();
    expect(attention.map((summary) => summary.item.id), [
      'azeite',
      'cafe',
      'sabao',
    ]);
    expect(attention.map((summary) => summary.status), [
      ItemPurchaseStatus.pending,
      ItemPurchaseStatus.quantityUnconfirmed,
      ItemPurchaseStatus.partial,
    ]);
    expect(attention.map((summary) => summary.missingQuantity), [
      null,
      null,
      2,
    ]);
    expect(attention[1].knownPurchasedQuantity, 5);
    expect(result.totalCents, 3300);
  });

  test('conferência pode ter a lista de avisos vazia', () {
    expect(calc([], []).itemsNeedingAttention, isEmpty);
    expect(calc([item()], [units(quantity: 5)]).itemsNeedingAttention, isEmpty);
  });
  test('pendente planejado preserva faltantes sem preço fictício', () {
    final summary = calc([item()], []).items.single;
    expect(summary.status, ItemPurchaseStatus.pending);
    expect(summary.missingQuantity, 5);
    expect(summary.subtotalCents, 0);
    expect(summary.purchasedQuantity, 0);
  });
  test('pendente sem planejamento não assume uma unidade', () {
    final summary = calc([item(planned: null)], []).items.single;
    expect(summary.status, ItemPurchaseStatus.pending);
    expect(summary.missingQuantity, isNull);
  });
  for (final quantity in [3, 5, 6]) {
    test('CT-013/014/015: planejado 5, comprado $quantity', () {
      final summary = calc([item()], [units(quantity: quantity)]).items.single;
      expect(summary.purchasedQuantity, quantity);
      expect(
        summary.status,
        quantity < 5
            ? ItemPurchaseStatus.partial
            : ItemPurchaseStatus.purchased,
      );
      expect(summary.missingQuantity, quantity < 5 ? 5 - quantity : 0);
      expect(summary.subtotalCents, quantity * 350);
    });
  }
  test(
    'D-030: valor direto planejado conta subtotal mas não confirma quantidade',
    () {
      final summary = calc([item()], [direct()]).items.single;
      expect(summary.status, ItemPurchaseStatus.quantityUnconfirmed);
      expect(summary.purchasedQuantity, isNull);
      expect(summary.missingQuantity, isNull);
      expect(summary.knownPurchasedQuantity, 0);
      expect(summary.subtotalCents, 4782);
    },
  );
  test(
    'D-030: misto permanece não confirmado mesmo com unidades suficientes',
    () {
      final summary = calc(
        [item()],
        [units(quantity: 5), direct()],
      ).items.single;
      expect(summary.status, ItemPurchaseStatus.quantityUnconfirmed);
      expect(summary.purchasedQuantity, isNull);
      expect(summary.knownPurchasedQuantity, 5);
      expect(summary.subtotalCents, 6532);
    },
  );
  test('zero direto explícito é registro e mantém desconhecida a quantidade planejada', () {
    final summary = calc([item()], [direct(amount: 0)]).items.single;
    expect(summary.entries.length, 1);
    expect(summary.status, ItemPurchaseStatus.quantityUnconfirmed);
  });
  test('D-028: unidades gratuitas podem completar planejamento', () {
    final summary = calc([item()], [units(quantity: 5, price: 0)]).items.single;
    expect(summary.status, ItemPurchaseStatus.purchased);
    expect(summary.subtotalCents, 0);
  });
  test('D-028: gratuito sem planejamento está comprado, não pendente', () {
    expect(
      calc([item(planned: null)], [direct(amount: 0)]).items.single.status,
      ItemPurchaseStatus.purchased,
    );
  });
  test('CT-024/050: removido conserva subtotal e não participa do total', () {
    final result = calc(
      [item(removed: true), item(id: 'kept')],
      [units(), direct(itemId: 'kept', amount: 10)],
    );
    expect(result.totalCents, 10);
    expect(result.items.first.status, ItemPurchaseStatus.removed);
    expect(result.items.first.subtotalCents, 1050);
  });
  test('CT-022/027: substituir entrada corrige sem duplicar valor antigo', () {
    final before = calc([item()], [units(quantity: 1, price: 2590)]);
    final after = calc([item()], [units(quantity: 1, price: 2390)]);
    expect(before.totalCents - after.totalCents, 200);
    expect(after.totalCents, 2390);
  });
  test(
    'CT-023: remover só segunda entrada desconta somente seus 840 centavos',
    () {
      final first = units();
      final second = units(id: 'second', quantity: 2, price: 420);
      expect(calc([item()], [first, second]).totalCents, 1890);
      expect(calc([item()], [first]).totalCents, 1050);
    },
  );
  test(
    'ordem é sortOrder; inputs e saídas não são mutáveis por efeito colateral',
    () {
      final items = [item(id: 'last', order: 2), item()];
      final entries = [units()];
      final result = calc(items, entries);
      expect(result.items.map((s) => s.item.id), ['item', 'last']);
      expect(items.first.id, 'last');
      items.clear();
      entries.clear();
      expect(result.items.length, 2);
      expect(result.items.first.entries.length, 1);
      expect(() => result.items.clear(), throwsUnsupportedError);
      expect(() => result.items.first.entries.clear(), throwsUnsupportedError);
    },
  );
  test('IDs de item duplicados não podem duplicar subtotal', () {
    expect(() => calc([item(), item()], [units()]), throwsArgumentError);
  });
  test('IDs de entrada duplicados não podem duplicar subtotal', () {
    expect(() => calc([item()], [units(), units()]), throwsArgumentError);
  });
  test('entrada órfã não pode entrar na conta', () {
    expect(() => calc([], [units()]), throwsArgumentError);
  });
  test('item de outra lista é recusado, não misturado silenciosamente', () {
    final foreign = ShoppingItem(
      id: 'item',
      shoppingListId: 'other',
      name: 'Outro',
      origin: ShoppingItemOrigin.planned,
      sortOrder: 0,
    );
    expect(() => calc([foreign], [units()]), throwsArgumentError);
  });
  test('D-029: soma de itens ou entradas não pode ultrapassar int64', () {
    expect(
      () => calc(
        [item(), item(id: 'other')],
        [
          direct(amount: maxMoneyCents),
          direct(id: 'd2', itemId: 'other', amount: 1),
        ],
      ),
      throwsRangeError,
    );
    expect(
      () => calc(
        [item()],
        [direct(amount: maxMoneyCents), direct(id: 'd2', amount: 1)],
      ),
      throwsRangeError,
    );
    expect(
      calc([item()], [direct(amount: maxMoneyCents)]).totalCents,
      maxMoneyCents,
    );
  });
  test('quantidade acumulada também não pode dar wrap, mesmo em produtos gratuitos', () {
    expect(
      () => calc(
        [item()],
        [
          units(quantity: maxMoneyCents, price: 0),
          units(id: 'extra', quantity: 1, price: 0),
        ],
      ),
      throwsRangeError,
    );
  });
}
