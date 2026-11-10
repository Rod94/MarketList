import 'package:market_list/features/shopping/domain/models/shopping_list.dart';
import 'package:market_list/features/shopping/domain/models/shopping_item.dart';
import 'package:market_list/features/shopping/domain/shopping_repository.dart';

class FakeShoppingRepository implements ShoppingRepository {
  FakeShoppingRepository({Iterable<ShoppingList> lists = const []})
    : lists = List.of(lists);

  final List<ShoppingList> lists;
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
  String newItemId() => throw UnimplementedError('Fake exclusivo de listas.');

  @override
  Future<ShoppingItem> createItem({
    required String id,
    required String shoppingListId,
    required String name,
    required ShoppingItemOrigin origin,
    int? plannedQuantity,
  }) => throw UnimplementedError('Fake exclusivo de listas.');

  @override
  Future<List<ShoppingItem>> listItems(String shoppingListId) =>
      throw UnimplementedError('Fake exclusivo de listas.');

  @override
  Future<ShoppingItem> updateItem({
    required String id,
    required String shoppingListId,
    required String name,
    required int? plannedQuantity,
  }) => throw UnimplementedError('Fake exclusivo de listas.');

  @override
  Future<bool> removeItem({
    required String id,
    required String shoppingListId,
  }) => throw UnimplementedError('Fake exclusivo de listas.');

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
