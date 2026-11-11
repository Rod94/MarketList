import 'package:market_list/features/shopping/domain/models/shopping_list.dart';
import 'package:market_list/features/shopping/domain/models/shopping_item.dart';
import 'package:market_list/features/shopping/domain/models/purchase_entry.dart';
import 'package:market_list/features/shopping/domain/shopping_calculator.dart';
import 'package:market_list/features/shopping/domain/shopping_repository.dart';

class FakeShoppingRepository implements ShoppingRepository {
  FakeShoppingRepository({
    Iterable<ShoppingList> lists = const [],
    Iterable<ShoppingItem> items = const [],
  }) : lists = List.of(lists),
       items = List.of(items);

  final List<ShoppingList> lists;
  final List<ShoppingItem> items;
  final List<PurchaseEntry> entries = [];
  Future<ShoppingCalculation> Function(String, String, String, PurchaseEntry)?
  quickPurchaseHandler;

  @override
  Future<ShoppingCalculation> createItemWithPurchase({
    required String id,
    required String shoppingListId,
    required String name,
    required PurchaseEntry entry,
  }) async {
    final handler = quickPurchaseHandler;
    if (handler != null) return handler(id, shoppingListId, name, entry);
    await createItem(
      id: id,
      shoppingListId: shoppingListId,
      name: name,
      origin: ShoppingItemOrigin.atStore,
    );
    entries.add(entry);
    return loadShoppingList(shoppingListId);
  }

  final List<String> entryCreationIds = [];
  int entryIdCalls = 0;
  int purchaseCreateCalls = 0;
  Future<ShoppingCalculation> Function(String, PurchaseEntry)?
  purchaseCreateHandler;
  Future<ShoppingCalculation> Function(String, PurchaseEntry)?
  purchaseUpdateHandler;
  Future<ShoppingCalculation> Function(String, String, String)?
  purchaseRemoveHandler;
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
  Future<ShoppingList> Function(String id, int? budget)? budgetHandler;

  @override
  Future<ShoppingList> updateListBudget(String id, int? budgetCents) async {
    final handler = budgetHandler;
    if (handler != null) return handler(id, budgetCents);
    final index = lists.indexWhere((list) => list.id == id);
    if (index == -1) throw ShoppingListNotFoundException(id);
    final previous = lists[index];
    if (previous.status == ShoppingListStatus.finalized) {
      throw FinalizedShoppingListException(id);
    }
    final updated = ShoppingList(
      id: previous.id,
      name: previous.name,
      createdAt: previous.createdAt,
      budgetCents: budgetCents,
    );
    lists[index] = updated;
    return updated;
  }

  @override
  String newListId() => 'fake-${++idCalls}';

  @override
  String newItemId() => 'fake-item-${++itemIdCalls}';

  @override
  String newEntryId() => 'fake-entry-${++entryIdCalls}';
  @override
  Future<ShoppingCalculation> loadShoppingList(String shoppingListId) async {
    final loaded = await listItems(shoppingListId);
    final ids = loaded.map((item) => item.id).toSet();
    return calculateShoppingList(
      shoppingListId: shoppingListId,
      items: loaded,
      entries: entries.where((entry) => ids.contains(entry.shoppingItemId)),
    );
  }

  @override
  Future<ShoppingCalculation> createPurchaseEntry({
    required String shoppingListId,
    required PurchaseEntry entry,
  }) async {
    purchaseCreateCalls++;
    entryCreationIds.add(entry.id);
    if (purchaseCreateHandler != null) {
      return purchaseCreateHandler!(shoppingListId, entry);
    }
    entries.add(entry);
    return loadShoppingList(shoppingListId);
  }

  @override
  Future<ShoppingCalculation> updatePurchaseEntry({
    required String shoppingListId,
    required PurchaseEntry entry,
  }) async {
    if (purchaseUpdateHandler != null) {
      return purchaseUpdateHandler!(shoppingListId, entry);
    }
    final index = entries.indexWhere((e) => e.id == entry.id);
    entries[index] = entry;
    return loadShoppingList(shoppingListId);
  }

  @override
  Future<ShoppingCalculation> removePurchaseEntry({
    required String shoppingListId,
    required String shoppingItemId,
    required String entryId,
  }) async {
    if (purchaseRemoveHandler != null) {
      return purchaseRemoveHandler!(shoppingListId, shoppingItemId, entryId);
    }
    entries.removeWhere(
      (entry) => entry.id == entryId && entry.shoppingItemId == shoppingItemId,
    );
    return loadShoppingList(shoppingListId);
  }

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
  }) async =>
      await removeItemForUndo(id: id, shoppingListId: shoppingListId) != null;

  @override
  Future<DateTime?> removeItemForUndo({
    required String id,
    required String shoppingListId,
  }) async {
    itemRemoveCalls++;
    final handler = itemRemoveHandler;
    if (handler != null && !await handler(id, shoppingListId)) return null;
    final index = items.indexWhere(
      (i) => i.id == id && i.shoppingListId == shoppingListId,
    );
    if (index < 0 || items[index].removedAt != null) return null;
    final original = items[index];
    final removedAt = DateTime.utc(
      2026,
      11,
      10,
    ).add(Duration(microseconds: itemRemoveCalls));
    items[index] = ShoppingItem(
      id: id,
      shoppingListId: shoppingListId,
      name: original.name,
      plannedQuantity: original.plannedQuantity,
      origin: original.origin,
      sortOrder: original.sortOrder,
      removedAt: removedAt,
    );
    return removedAt;
  }

  @override
  Future<ShoppingCalculation?> restoreRemovedItem({
    required String id,
    required String shoppingListId,
    required DateTime removedAt,
  }) async {
    final index = items.indexWhere(
      (item) =>
          item.id == id &&
          item.shoppingListId == shoppingListId &&
          item.removedAt == removedAt,
    );
    if (index < 0) return null;
    final original = items[index];
    items[index] = ShoppingItem(
      id: original.id,
      shoppingListId: original.shoppingListId,
      name: original.name,
      plannedQuantity: original.plannedQuantity,
      origin: original.origin,
      sortOrder: original.sortOrder,
    );
    try {
      return await loadShoppingList(shoppingListId);
    } catch (_) {
      items[index] = original;
      rethrow;
    }
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
