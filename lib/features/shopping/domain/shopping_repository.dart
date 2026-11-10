import 'models/shopping_list.dart';
import 'models/shopping_item.dart';

abstract interface class ShoppingRepository {
  /// Gere uma vez por inclusão e reutilize o ID nas tentativas dessa operação.
  String newListId();

  Future<ShoppingList> createList({
    required String id,
    required String name,
    int? budgetCents,
  });

  Future<List<ShoppingList>> listActiveLists();

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
