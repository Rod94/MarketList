import 'package:market_list/features/shopping/domain/models/shopping_list.dart';
import 'package:market_list/features/shopping/domain/models/shopping_item.dart';
import 'package:market_list/features/shopping/domain/shopping_repository.dart';

class FakeShoppingRepository implements ShoppingRepository {
  FakeShoppingRepository({
    Iterable<ShoppingList> lists = const [],
    Iterable<ShoppingItem> items = const [],
  }) : lists = List.of(lists),
       items = List.of(items);

  final List<ShoppingList> lists;
  final List<ShoppingItem> items;
  final List<String> itemCreationIds = [];
  int itemIdCalls = 0;
  int itemCreateCalls = 0;
  int itemUpdateCalls = 0;
  int itemRemoveCalls = 0;
  Future<List<ShoppingItem>> Function(String)? itemsLoadHandler;
  Future<ShoppingItem> Function(
    String,
    String,
    String,
    int?,
    ShoppingItemOrigin,
  )?
  itemCreateHandler;
  Future<ShoppingItem> Function(String, String, String, int?)?
  itemUpdateHandler;
  Future<bool> Function(String, String)? itemRemoveHandler;
  final List<String> creationIds = [];
  int loadCalls = 0;
  int createCalls = 0;
  int removeCalls = 0;
  int idCalls = 0;
  Future<List<ShoppingList>> Function()? loadHandler;
  Future<ShoppingList> Function(String id, String name, int? budget)?
  createHandler;
  Future<bool> Function(String id)? removeHandler;

  @override
  String newListId() => 'fake-${++idCalls}';

  @override
  String newItemId() => 'fake-item-${++itemIdCalls}';

  @override
  Future<ShoppingItem> createItem({
    required String id,
    required String shoppingListId,
    required String name,
    required ShoppingItemOrigin origin,
    int? plannedQuantity,
  }) async {
    itemCreateCalls++;
    itemCreationIds.add(id);
    if (itemCreateHandler != null) {
      return itemCreateHandler!(
        id,
        shoppingListId,
        name,
        plannedQuantity,
        origin,
      );
    }
    final item = ShoppingItem(
      id: id,
      shoppingListId: shoppingListId,
      name: name,
      plannedQuantity: plannedQuantity,
      origin: origin,
      sortOrder: items.where((i) => i.shoppingListId == shoppingListId).length,
    );
    items.add(item);
    return item;
  }

  @override
  Future<List<ShoppingItem>> listItems(String shoppingListId) async =>
      itemsLoadHandler != null
      ? await itemsLoadHandler!(shoppingListId)
      : items.where((item) => item.shoppingListId == shoppingListId).toList();

  @override
  Future<ShoppingItem> updateItem({
    required String id,
    required String shoppingListId,
    required String name,
    required int? plannedQuantity,
  }) async {
    itemUpdateCalls++;
    if (itemUpdateHandler != null) {
      return itemUpdateHandler!(id, shoppingListId, name, plannedQuantity);
    }
    final index = items.indexWhere(
      (i) => i.id == id && i.shoppingListId == shoppingListId,
    );
    final original = items[index];
    return items[index] = ShoppingItem(
      id: id,
      shoppingListId: shoppingListId,
      name: name,
      plannedQuantity: plannedQuantity,
      origin: original.origin,
      sortOrder: original.sortOrder,
      removedAt: original.removedAt,
    );
  }

  @override
  Future<bool> removeItem({
    required String id,
    required String shoppingListId,
  }) async {
    itemRemoveCalls++;
    if (itemRemoveHandler != null) {
      return itemRemoveHandler!(id, shoppingListId);
    }
    final index = items.indexWhere(
      (i) => i.id == id && i.shoppingListId == shoppingListId,
    );
    if (index < 0 || items[index].removedAt != null) return false;
    final original = items[index];
    items[index] = ShoppingItem(
      id: id,
      shoppingListId: shoppingListId,
      name: original.name,
      plannedQuantity: original.plannedQuantity,
      origin: original.origin,
      sortOrder: original.sortOrder,
      removedAt: DateTime.utc(2026, 11, 10),
    );
    return true;
  }

  @override
  Future<List<ShoppingList>> listActiveLists() async {
    loadCalls++;
    if (loadHandler != null) return loadHandler!();
    return List.of(
      lists.where((list) => list.status == ShoppingListStatus.active),
    );
  }

  @override
  Future<ShoppingList> createList({
    required String id,
    required String name,
    int? budgetCents,
  }) async {
    createCalls++;
    creationIds.add(id);
    if (createHandler != null) return createHandler!(id, name, budgetCents);
    final list = ShoppingList(
      id: id,
      name: name,
      createdAt: DateTime.utc(2026, 11, 9, 12),
      budgetCents: budgetCents,
    );
    lists.add(list);
    return list;
  }

  @override
  Future<bool> removeActiveList(String id) async {
    removeCalls++;
    if (removeHandler != null) return removeHandler!(id);
    final matching = lists.where((list) => list.id == id);
    if (matching.isEmpty) return false;
    if (matching.single.status == ShoppingListStatus.finalized) {
      throw FinalizedShoppingListException(id);
    }
    lists.removeWhere((list) => list.id == id);
    return true;
  }
}
