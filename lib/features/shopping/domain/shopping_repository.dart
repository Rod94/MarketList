import 'models/shopping_list.dart';

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
