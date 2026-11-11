import 'models/shopping_list.dart';
import 'models/shopping_item.dart';
import 'models/purchase_entry.dart';
import 'models/shopping_snapshot.dart';
import 'shopping_calculator.dart';

abstract interface class ShoppingRepository {
  /// Gere uma vez por inclusão e reutilize o ID nas tentativas dessa operação.
  String newListId();

  Future<ShoppingList> createList({
    required String id,
    required String name,
    int? budgetCents,
  });

  Future<List<ShoppingList>> listActiveLists();

  Future<List<ShoppingList>> listFinalizedLists();

  Future<ShoppingSnapshot> loadShoppingSnapshot(String id);

  Future<ShoppingSnapshot> finalizeShoppingList(
    ShoppingSnapshot reviewed, {
    int? checkoutPaidCents,
  });

  Future<ShoppingList> updateListBudget(String id, int? budgetCents);

  /// Retorna false se ausente; listas finalizadas são recusadas.
  Future<bool> removeActiveList(String id);

  /// Gere uma vez por inclusão e mantenha o ID nas tentativas dessa operação.
  String newItemId();

  Future<ShoppingItem> createItem({
    required String id,
    required String shoppingListId,
    required String name,
    required ShoppingItemOrigin origin,
    int? plannedQuantity,
  });

  /// Mantém os dois IDs durante tentativas da mesma inclusão.
  Future<ShoppingCalculation> createItemWithPurchase({
    required String id,
    required String shoppingListId,
    required String name,
    required PurchaseEntry entry,
  });

  /// Inclui registros removidos; não representa o filtro visual da compra.
  Future<List<ShoppingItem>> listItems(String shoppingListId);

  /// Quantidade é explícita: null retira o planejamento, sem preservar o anterior.
  Future<ShoppingItem> updateItem({
    required String id,
    required String shoppingListId,
    required String name,
    required int? plannedQuantity,
  });

  /// Marca remoção lógica; false se item ausente/removido. Recusa finalizada.
  Future<bool> removeItem({required String id, required String shoppingListId});

  /// Retorna o instante persistido da remoção para identificar o desfazer.
  Future<DateTime?> removeItemForUndo({
    required String id,
    required String shoppingListId,
  });

  /// Restaura apenas a remoção identificada; null se ela já não corresponde.
  Future<ShoppingCalculation?> restoreRemovedItem({
    required String id,
    required String shoppingListId,
    required DateTime removedAt,
  });

  String newEntryId();
  Future<ShoppingCalculation> loadShoppingList(String shoppingListId);
  Future<ShoppingCalculation> createPurchaseEntry({
    required String shoppingListId,
    required PurchaseEntry entry,
  });
  Future<ShoppingCalculation> updatePurchaseEntry({
    required String shoppingListId,
    required PurchaseEntry entry,
  });
  Future<ShoppingCalculation> removePurchaseEntry({
    required String shoppingListId,
    required String shoppingItemId,
    required String entryId,
  });
}

final class ShoppingReviewChangedException implements Exception {
  const ShoppingReviewChangedException(this.current);

  final ShoppingSnapshot current;
}

final class PurchaseEntryCreationConflict implements Exception {
  const PurchaseEntryCreationConflict(this.id);
  final String id;
  @override
  String toString() =>
      'O identificador já pertence a uma entrada com outros dados.';
}

final class PurchaseEntryNotFoundException implements Exception {
  const PurchaseEntryNotFoundException(this.id);
  final String id;
  @override
  String toString() => 'A entrada não foi encontrada neste produto.';
}

final class ShoppingListNotFoundException implements Exception {
  const ShoppingListNotFoundException(this.id);
  final String id;
  @override
  String toString() => 'A lista não foi encontrada.';
}

final class ShoppingItemNotFoundException implements Exception {
  const ShoppingItemNotFoundException(this.id);
  final String id;
  @override
  String toString() => 'O item não foi encontrado nesta lista.';
}

final class ShoppingItemCreationConflict implements Exception {
  const ShoppingItemCreationConflict(this.id);
  final String id;
  @override
  String toString() =>
      'O identificador já pertence a um item com outros dados.';
}

final class RemovedShoppingItemException implements Exception {
  const RemovedShoppingItemException(this.id);
  final String id;
  @override
  String toString() => 'O item já foi removido desta compra.';
}

final class FinalizedShoppingListException implements Exception {
  const FinalizedShoppingListException(this.id);

  final String id;

  @override
  String toString() =>
      'A lista finalizada está disponível somente para consulta.';
}

final class ShoppingListCreationConflict implements Exception {
  const ShoppingListCreationConflict(this.id);

  final String id;

  @override
  String toString() =>
      'O identificador já pertence a uma criação com outros dados.';
}
