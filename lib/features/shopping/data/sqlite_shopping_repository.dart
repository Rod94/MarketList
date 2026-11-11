import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/money/money.dart';
import '../domain/models/shopping_item.dart';
import '../domain/models/shopping_list.dart';
import '../domain/models/purchase_entry.dart';
import '../domain/models/shopping_snapshot.dart';
import '../domain/shopping_calculator.dart';
import '../domain/shopping_repository.dart';

final class SqliteShoppingRepository implements ShoppingRepository {
  SqliteShoppingRepository(this._database, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AppDatabase _database;
  final DateTime Function() _now;

  @override
  String newListId() => const Uuid().v4();

  @override
  String newItemId() => const Uuid().v4();

  @override
  String newEntryId() => const Uuid().v4();

  @override
  Future<ShoppingCalculation> loadShoppingList(String shoppingListId) async {
    final db = await _database.open();
    return db.transaction((txn) async {
      await _requireList(txn, shoppingListId);
      return _calculateTransaction(txn, shoppingListId);
    });
  }

  @override
  Future<ShoppingSnapshot> loadShoppingSnapshot(String id) async {
    final db = await _database.open();
    return db.transaction((txn) => _readSnapshot(txn, id));
  }

  @override
  Future<ShoppingSnapshot> finalizeShoppingList(
    ShoppingSnapshot reviewed, {
    int? checkoutPaidCents,
  }) async {
    if (checkoutPaidCents != null) validateMoneyCents(checkoutPaidCents);
    final id = reviewed.list.id;
    final db = await _database.open();
    return db.transaction((txn) async {
      final current = await _readSnapshot(txn, id, writable: true);
      if (!current.matchesReview(reviewed)) {
        throw ShoppingReviewChangedException(current);
      }
      final now = _now().toUtc();
      final created = current.list.createdAt;
      final finalized = ShoppingList(
        id: id,
        name: current.list.name,
        createdAt: created,
        status: ShoppingListStatus.finalized,
        // O relógio do aparelho pode ter sido ajustado desde a criação.
        finalizedAt: now.isBefore(created) ? created : now,
        budgetCents: current.list.budgetCents,
        finalizedRegisteredTotalCents: current.calculation.totalCents,
        checkoutPaidCents: checkoutPaidCents,
      );
      final changed = await txn.update(
        'shopping_lists',
        {
          'status': finalized.status.name,
          'finalized_at_utc': _formatUtc(finalized.finalizedAt!),
          'finalized_registered_total_cents':
              finalized.finalizedRegisteredTotalCents,
          'checkout_paid_cents': finalized.checkoutPaidCents,
        },
        where: 'id = ? AND status = ?',
        whereArgs: [id, ShoppingListStatus.active.name],
      );
      if (changed != 1) throw FinalizedShoppingListException(id);
      return ShoppingSnapshot(finalized, current.calculation);
    });
  }

  static Future<ShoppingSnapshot> _readSnapshot(
    DatabaseExecutor txn,
    String id, {
    bool writable = false,
  }) async {
    _validateId(id, 'id');
    final rows = await txn.query(
      'shopping_lists',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw ShoppingListNotFoundException(id);
    final list = _fromRow(rows.single);
    if (writable && list.status == ShoppingListStatus.finalized) {
      throw FinalizedShoppingListException(id);
    }
    return ShoppingSnapshot(list, await _calculateTransaction(txn, id));
  }

  @override
  Future<ShoppingCalculation> createPurchaseEntry({
    required String shoppingListId,
    required PurchaseEntry entry,
  }) async {
    final db = await _database.open();
    return db.transaction((txn) async {
      await _requireWritableItem(txn, shoppingListId, entry.shoppingItemId);
      await _insertOrReuseEntry(txn, entry);
      return _calculateTransaction(txn, shoppingListId);
    });
  }

  static Future<void> _insertOrReuseEntry(
    DatabaseExecutor txn,
    PurchaseEntry entry, {
    bool requireExisting = false,
  }) async {
    final rows = await txn.query(
      'purchase_entries',
      where: 'id = ?',
      whereArgs: [entry.id],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      final existing = _entryFromRow(rows.single);
      if (existing.shoppingItemId != entry.shoppingItemId ||
          existing.quantity != entry.quantity ||
          existing.unitPriceCents != entry.unitPriceCents ||
          existing.directAmountCents != entry.directAmountCents) {
        throw PurchaseEntryCreationConflict(entry.id);
      }
    } else {
      if (requireExisting) throw PurchaseEntryCreationConflict(entry.id);
      await txn.insert('purchase_entries', _entryToRow(entry));
    }
  }

  @override
  Future<ShoppingCalculation> updatePurchaseEntry({
    required String shoppingListId,
    required PurchaseEntry entry,
  }) async {
    final db = await _database.open();
    return db.transaction((txn) async {
      await _requireWritableItem(txn, shoppingListId, entry.shoppingItemId);
      final changed = await txn.update(
        'purchase_entries',
        {
          'quantity': entry.quantity,
          'unit_price_cents': entry.unitPriceCents,
          'direct_amount_cents': entry.directAmountCents,
        },
        where: 'id = ? AND shopping_item_id = ?',
        whereArgs: [entry.id, entry.shoppingItemId],
      );
      if (changed != 1) throw PurchaseEntryNotFoundException(entry.id);
      return _calculateTransaction(txn, shoppingListId);
    });
  }

  @override
  Future<ShoppingCalculation> removePurchaseEntry({
    required String shoppingListId,
    required String shoppingItemId,
    required String entryId,
  }) async {
    _validateId(entryId, 'entryId');
    final db = await _database.open();
    return db.transaction((txn) async {
      await _requireWritableItem(txn, shoppingListId, shoppingItemId);
      final removed = await txn.delete(
        'purchase_entries',
        where: 'id = ? AND shopping_item_id = ?',
        whereArgs: [entryId, shoppingItemId],
      );
      if (removed != 1) throw PurchaseEntryNotFoundException(entryId);
      return _calculateTransaction(txn, shoppingListId);
    });
  }

  static Future<void> _requireWritableItem(
    DatabaseExecutor txn,
    String listId,
    String itemId,
  ) async {
    await _requireList(txn, listId, writable: true);
    _validateId(itemId, 'shoppingItemId');
    final rows = await txn.query(
      'shopping_items',
      where: 'id = ? AND shopping_list_id = ?',
      whereArgs: [itemId, listId],
      limit: 1,
    );
    if (rows.isEmpty) throw ShoppingItemNotFoundException(itemId);
    final item = _itemFromRow(rows.single);
    if (item.removedAt != null) throw RemovedShoppingItemException(itemId);
  }

  static Future<ShoppingCalculation> _calculateTransaction(
    DatabaseExecutor txn,
    String listId,
  ) async {
    final items = await txn.query(
      'shopping_items',
      where: 'shopping_list_id = ?',
      whereArgs: [listId],
    );
    final entries = await txn.rawQuery(
      '''
      SELECT e.* FROM purchase_entries e
      JOIN shopping_items i ON i.id = e.shopping_item_id
      WHERE i.shopping_list_id = ? ORDER BY e.id
    ''',
      [listId],
    );
    return calculateShoppingList(
      shoppingListId: listId,
      items: items.map(_itemFromRow),
      entries: entries.map(_entryFromRow),
    );
  }

  static Map<String, Object?> _entryToRow(PurchaseEntry entry) => {
    'id': entry.id,
    'shopping_item_id': entry.shoppingItemId,
    'quantity': entry.quantity,
    'unit_price_cents': entry.unitPriceCents,
    'direct_amount_cents': entry.directAmountCents,
  };

  static PurchaseEntry _entryFromRow(Map<String, Object?> row) => PurchaseEntry(
    id: row['id'] as String,
    shoppingItemId: row['shopping_item_id'] as String,
    quantity: row['quantity'] as int?,
    unitPriceCents: row['unit_price_cents'] as int?,
    directAmountCents: row['direct_amount_cents'] as int?,
  );

  @override
  Future<ShoppingItem> createItem({
    required String id,
    required String shoppingListId,
    required String name,
    required ShoppingItemOrigin origin,
    int? plannedQuantity,
  }) async {
    final candidate = ShoppingItem(
      id: id,
      shoppingListId: shoppingListId,
      name: name,
      origin: origin,
      plannedQuantity: plannedQuantity,
      sortOrder: 0,
    );
    final db = await _database.open();
    return db.transaction(
      (txn) async => (await _insertOrReuseItem(txn, candidate)).item,
    );
  }

  @override
  Future<ShoppingCalculation> createItemWithPurchase({
    required String id,
    required String shoppingListId,
    required String name,
    required PurchaseEntry entry,
  }) async {
    if (entry.shoppingItemId != id) {
      throw ArgumentError.value(
        entry.shoppingItemId,
        'entry',
        'Vínculo com outro produto.',
      );
    }
    final candidate = ShoppingItem(
      id: id,
      shoppingListId: shoppingListId,
      name: name,
      origin: ShoppingItemOrigin.atStore,
      sortOrder: 0,
    );
    final db = await _database.open();
    return db.transaction((txn) async {
      final result = await _insertOrReuseItem(txn, candidate);
      await _insertOrReuseEntry(txn, entry, requireExisting: !result.created);
      return _calculateTransaction(txn, shoppingListId);
    });
  }

  static Future<({ShoppingItem item, bool created})> _insertOrReuseItem(
    DatabaseExecutor txn,
    ShoppingItem candidate,
  ) async {
    final id = candidate.id;
    final shoppingListId = candidate.shoppingListId;
    final plannedQuantity = candidate.plannedQuantity;
    final origin = candidate.origin;
    await _requireList(txn, shoppingListId, writable: true);
    final rows = await txn.query(
      'shopping_items',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      final existing = _itemFromRow(rows.single);
      if (existing.shoppingListId != shoppingListId ||
          existing.name != candidate.name ||
          existing.plannedQuantity != plannedQuantity ||
          existing.origin != origin) {
        throw ShoppingItemCreationConflict(id);
      }
      if (existing.removedAt != null) throw RemovedShoppingItemException(id);
      return (item: existing, created: false);
    }
    final result = await txn.rawQuery(
      'SELECT MAX(sort_order) AS last_position FROM shopping_items WHERE shopping_list_id = ?',
      [shoppingListId],
    );
    final last = result.single['last_position'] as int?;
    if (last == 9223372036854775807) {
      throw StateError('Não há posição representável para outro item.');
    }
    final item = ShoppingItem(
      id: id,
      shoppingListId: shoppingListId,
      name: candidate.name,
      origin: origin,
      plannedQuantity: plannedQuantity,
      sortOrder: last == null ? 0 : last + 1,
    );
    await txn.insert('shopping_items', {
      'id': item.id,
      'shopping_list_id': item.shoppingListId,
      'name': item.name,
      'planned_quantity': item.plannedQuantity,
      'origin': origin == ShoppingItemOrigin.planned ? 'planned' : 'at_store',
      'sort_order': item.sortOrder,
      'removed_at_utc': null,
    });
    return (item: item, created: true);
  }

  @override
  Future<List<ShoppingItem>> listItems(String shoppingListId) async {
    final db = await _database.open();
    return db.transaction((txn) async {
      await _requireList(txn, shoppingListId);
      final rows = await txn.query(
        'shopping_items',
        where: 'shopping_list_id = ?',
        whereArgs: [shoppingListId],
        orderBy: 'sort_order, id',
      );
      return List<ShoppingItem>.unmodifiable(rows.map(_itemFromRow));
    });
  }

  @override
  Future<ShoppingItem> updateItem({
    required String id,
    required String shoppingListId,
    required String name,
    required int? plannedQuantity,
  }) async {
    _validateId(id, 'id');
    final db = await _database.open();
    return db.transaction((txn) async {
      await _requireList(txn, shoppingListId, writable: true);
      final rows = await txn.query(
        'shopping_items',
        where: 'id = ? AND shopping_list_id = ?',
        whereArgs: [id, shoppingListId],
        limit: 1,
      );
      if (rows.isEmpty) throw ShoppingItemNotFoundException(id);
      final existing = _itemFromRow(rows.single);
      if (existing.removedAt != null) throw RemovedShoppingItemException(id);
      final updated = ShoppingItem(
        id: id,
        shoppingListId: shoppingListId,
        name: name,
        plannedQuantity: plannedQuantity,
        origin: existing.origin,
        sortOrder: existing.sortOrder,
      );
      final changed = await txn.update(
        'shopping_items',
        {'name': updated.name, 'planned_quantity': updated.plannedQuantity},
        where: 'id = ? AND shopping_list_id = ? AND removed_at_utc IS NULL',
        whereArgs: [id, shoppingListId],
      );
      if (changed != 1) {
        throw StateError('Não foi possível confirmar a edição.');
      }
      return updated;
    });
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
    _validateId(id, 'id');
    final db = await _database.open();
    return db.transaction((txn) async {
      await _requireList(txn, shoppingListId, writable: true);
      final removedAt = _now().toUtc();
      final changed = await txn.update(
        'shopping_items',
        {'removed_at_utc': _formatUtc(removedAt)},
        where: 'id = ? AND shopping_list_id = ? AND removed_at_utc IS NULL',
        whereArgs: [id, shoppingListId],
      );
      if (changed > 1) {
        throw StateError('Mais de um item afetado pela remoção.');
      }
      return changed == 1 ? removedAt : null;
    });
  }

  @override
  Future<ShoppingCalculation?> restoreRemovedItem({
    required String id,
    required String shoppingListId,
    required DateTime removedAt,
  }) async {
    _validateId(id, 'id');
    final db = await _database.open();
    return db.transaction((txn) async {
      await _requireList(txn, shoppingListId, writable: true);
      final changed = await txn.update(
        'shopping_items',
        {'removed_at_utc': null},
        where: 'id = ? AND shopping_list_id = ? AND removed_at_utc = ?',
        whereArgs: [id, shoppingListId, _formatUtc(removedAt)],
      );
      if (changed == 0) return null;
      // Valide o total antes do commit caso outras compras tenham sido salvas.
      return _calculateTransaction(txn, shoppingListId);
    });
  }

  static Future<void> _requireList(
    DatabaseExecutor txn,
    String id, {
    bool writable = false,
  }) async {
    _validateId(id, 'shoppingListId');
    final rows = await txn.query(
      'shopping_lists',
      columns: ['status'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw ShoppingListNotFoundException(id);
    switch (rows.single['status']) {
      case 'active':
        return;
      case 'finalized':
        if (writable) throw FinalizedShoppingListException(id);
        return;
      default:
        throw const FormatException('Estado de lista inválido no banco.');
    }
  }

  static void _validateId(String id, String field) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(
        id,
        field,
        'O identificador não pode ser vazio.',
      );
    }
  }

  static ShoppingItem _itemFromRow(Map<String, Object?> row) => ShoppingItem(
    id: row['id'] as String,
    shoppingListId: row['shopping_list_id'] as String,
    name: row['name'] as String,
    plannedQuantity: row['planned_quantity'] as int?,
    origin: switch (row['origin']) {
      'planned' => ShoppingItemOrigin.planned,
      'at_store' => ShoppingItemOrigin.atStore,
      _ => throw const FormatException('Origem de item inválida no banco.'),
    },
    sortOrder: row['sort_order'] as int,
    removedAt: row['removed_at_utc'] == null
        ? null
        : _parseUtc(row['removed_at_utc'], 'removed_at_utc'),
  );

  @override
  Future<ShoppingList> createList({
    required String id,
    required String name,
    int? budgetCents,
  }) async {
    final candidate = ShoppingList(
      id: id,
      name: name,
      createdAt: _now(),
      budgetCents: budgetCents,
    );
    final db = await _database.open();
    return db.transaction((txn) async {
      final rows = await txn.query(
        'shopping_lists',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        if (rows.single['status'] == 'finalized') {
          throw FinalizedShoppingListException(id);
        }
        final existing = _fromRow(rows.single);
        if (existing.name != candidate.name ||
            existing.budgetCents != candidate.budgetCents) {
          throw ShoppingListCreationConflict(id);
        }
        return existing;
      }

      await txn.insert('shopping_lists', _toRow(candidate));
      return candidate;
    });
  }

  @override
  Future<List<ShoppingList>> listActiveLists() async {
    final db = await _database.open();
    final rows = await db.query(
      'shopping_lists',
      where: 'status = ?',
      whereArgs: ['active'],
    );
    final lists = rows.map(_fromRow).toList();
    // A v1 também aceita frações com larguras diferentes; ordenar o texto
    // inverteria instantes como .000Z e .000001Z.
    lists.sort(ShoppingList.compareByNewestCreation);
    return List<ShoppingList>.unmodifiable(lists);
  }

  @override
  Future<ShoppingList> updateListBudget(String id, int? budgetCents) async {
    if (budgetCents != null) validateMoneyCents(budgetCents);
    final db = await _database.open();
    return db.transaction((txn) async {
      await _requireList(txn, id, writable: true);
      final updated = await txn.update(
        'shopping_lists',
        {'budget_cents': budgetCents},
        where: 'id = ?',
        whereArgs: [id],
      );
      if (updated != 1) throw StateError('O orçamento não foi atualizado.');
      final rows = await txn.query(
        'shopping_lists',
        where: 'id = ?',
        whereArgs: [id],
      );
      return _fromRow(rows.single);
    });
  }

  @override
  Future<List<ShoppingList>> listFinalizedLists() async {
    final db = await _database.open();
    final rows = await db.query(
      'shopping_lists',
      where: 'status = ?',
      whereArgs: [ShoppingListStatus.finalized.name],
    );
    final lists = rows.map(_fromRow).toList()
      ..sort(ShoppingList.compareByNewestFinalization);
    return List.unmodifiable(lists);
  }

  @override
  Future<bool> removeActiveList(String id) async {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(
        id,
        'id',
        'O identificador não pode ser vazio.',
      );
    }
    final db = await _database.open();
    return db.transaction((txn) async {
      final rows = await txn.query(
        'shopping_lists',
        columns: ['status'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return false;
      if (rows.single['status'] == 'finalized') {
        throw FinalizedShoppingListException(id);
      }
      final removed = await txn.delete(
        'shopping_lists',
        where: 'id = ? AND status = ?',
        whereArgs: [id, 'active'],
      );
      if (removed != 1) {
        throw StateError(
          'Não foi possível confirmar a remoção da lista ativa.',
        );
      }
      return true;
    });
  }

  static Map<String, Object?> _toRow(ShoppingList list) => {
    'id': list.id,
    'name': list.name,
    'status': list.status.name,
    'created_at_utc': _formatUtc(list.createdAt),
    'finalized_at_utc': list.finalizedAt == null
        ? null
        : _formatUtc(list.finalizedAt!),
    'budget_cents': list.budgetCents,
    'finalized_registered_total_cents': list.finalizedRegisteredTotalCents,
    'checkout_paid_cents': list.checkoutPaidCents,
  };

  static ShoppingList _fromRow(Map<String, Object?> row) {
    final finalizedAt = row['finalized_at_utc'];
    return ShoppingList(
      id: row['id'] as String,
      name: row['name'] as String,
      createdAt: _parseUtc(row['created_at_utc'], 'created_at_utc'),
      status: switch (row['status']) {
        'active' => ShoppingListStatus.active,
        'finalized' => ShoppingListStatus.finalized,
        _ => throw const FormatException('Estado de lista inválido no banco.'),
      },
      finalizedAt: finalizedAt == null
          ? null
          : _parseUtc(finalizedAt, 'finalized_at_utc'),
      budgetCents: row['budget_cents'] as int?,
      finalizedRegisteredTotalCents:
          row['finalized_registered_total_cents'] as int?,
      checkoutPaidCents: row['checkout_paid_cents'] as int?,
    );
  }

  static String _formatUtc(DateTime date) {
    final utc = date.toUtc();
    final iso = utc.toIso8601String();
    return utc.microsecond == 0
        ? '${iso.substring(0, iso.length - 1)}000Z'
        : iso;
  }

  static final _utcPattern = RegExp(
    r'^((?:-?\d{4}|[+-]\d{6})-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})(?:\.(\d{1,6}))?Z$',
  );

  static DateTime _parseUtc(Object? value, String column) {
    final match = value is String ? _utcPattern.firstMatch(value) : null;
    final date = value is String ? DateTime.tryParse(value) : null;
    if (match == null || date == null) {
      throw FormatException('Data UTC inválida em $column.');
    }
    final canonical = '${match[1]}.${(match[2] ?? '').padRight(6, '0')}Z';
    // DateTime.parse aceita overflow (ex.: 30/02); a comparação o detecta.
    if (_formatUtc(date) != canonical) {
      throw FormatException('Data UTC inválida em $column.');
    }
    return date;
  }
}
