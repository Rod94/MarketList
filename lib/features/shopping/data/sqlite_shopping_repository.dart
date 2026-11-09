import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../domain/models/shopping_list.dart';
import '../domain/shopping_repository.dart';

final class SqliteShoppingRepository implements ShoppingRepository {
  SqliteShoppingRepository(this._database, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AppDatabase _database;
  final DateTime Function() _now;

  @override
  String newListId() => const Uuid().v4();

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
