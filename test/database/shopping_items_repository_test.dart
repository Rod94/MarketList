import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:market_list/core/database/app_database.dart';
import 'package:market_list/features/shopping/data/sqlite_shopping_repository.dart';
import 'package:market_list/features/shopping/domain/models/shopping_item.dart';
import 'package:market_list/features/shopping/domain/shopping_repository.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late AppDatabase appDatabase;
  late Database db;
  late SqliteShoppingRepository repository;
  final now = DateTime.utc(2026, 11, 10, 12);

  Future<ShoppingItem> create({
    String id = 'item-001',
    String listId = 'list-001',
    String name = 'Carne',
    int? quantity,
    ShoppingItemOrigin origin = ShoppingItemOrigin.planned,
  }) => repository.createItem(
    id: id,
    shoppingListId: listId,
    name: name,
    plannedQuantity: quantity,
    origin: origin,
  );

  Future<ShoppingItem> update({
    String id = 'item-001',
    String listId = 'list-001',
    String name = 'Carne',
    int? quantity,
  }) => repository.updateItem(
    id: id,
    shoppingListId: listId,
    name: name,
    plannedQuantity: quantity,
  );

  Future<bool> remove({String id = 'item-001', String listId = 'list-001'}) =>
      repository.removeItem(id: id, shoppingListId: listId);

  Future<int> finalize() => db.update(
    'shopping_lists',
    {
      'status': 'finalized',
      'finalized_at_utc': '2026-11-10T14:00:00.000000Z',
      'finalized_registered_total_cents': 0,
    },
    where: 'id = ?',
    whereArgs: ['list-001'],
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'market_list_items_test_',
    );
    appDatabase = AppDatabase(
      factory: databaseFactoryFfi,
      path: p.join(directory.path, 'items.db'),
    );
    db = await appDatabase.open();
    repository = SqliteShoppingRepository(appDatabase, now: () => now);
    await repository.createList(id: 'list-001', name: 'Compra');
    await repository.createList(id: 'list-002', name: 'Outra compra');
  });

  tearDown(() async {
    if (db.isOpen) await db.close();
    final root = await Directory.systemTemp.resolveSymbolicLinks();
    final target = await directory.resolveSymbolicLinks();
    if (!p.isWithin(root, target) ||
        !p.basename(target).startsWith('market_list_items_test_')) {
      throw StateError('Recusando limpeza fora da pasta de teste.');
    }
    await directory.delete(recursive: true);
  });

  test(
    'CT-004: cria com nome livre e quantidade ausente, após persistir',
    () async {
      const name = "  Carne d'água'); DROP TABLE shopping_items; --  ";
      final item = await create(name: name);
      expect(item.name, name.trim());
      expect(item.plannedQuantity, isNull);
      expect(item.sortOrder, 0);
      expect(item.origin, ShoppingItemOrigin.planned);
      expect(item.removedAt, isNull);
      final row = (await db.query('shopping_items')).single;
      expect(row['name'], item.name);
      expect(row['planned_quantity'], isNull);
      expect(row['shopping_list_id'], 'list-001');
    },
  );

  test('F2-04: edição no meio e reabertura preservam ordem original', () async {
    await create(id: 'first', name: 'Zebra');
    await create(id: 'middle', name: 'Leite');
    await create(id: 'last', name: 'Arroz');
    await update(id: 'middle', name: 'Abacate', quantity: 5);
    await db.close();
    db = await appDatabase.open();
    final loaded = await repository.listItems('list-001');
    expect(loaded.map((i) => i.id), ['first', 'middle', 'last']);
    expect(loaded.map((i) => i.sortOrder), [0, 1, 2]);
    expect((await create(id: 'next')).sortOrder, 3);
  });

  test('IDs novos são UUID v4 independentes dos IDs de lista', () {
    final id = repository.newItemId();
    expect(
      id,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    expect(repository.newItemId(), isNot(id));
  });

  test(
    'CT-004: repetir mesmo ID/dados retorna o mesmo registro sem duplicar',
    () async {
      await create(name: '  Sabonete  ', quantity: 5);
      final retry = await create(name: 'Sabonete', quantity: 5);
      expect(retry.sortOrder, 0);
      expect((await db.query('shopping_items')).length, 1);
    },
  );

  test('CT-004: inclusões simultâneas de mesmo ID não duplicam', () async {
    final results = await Future.wait([create(), create()]);
    expect(results.map((item) => item.id).toSet(), {'item-001'});
    expect((await db.query('shopping_items')).length, 1);
  });

  test('IDs iguais com payload diferente não substituem dados', () async {
    await create(quantity: 5);
    for (final operation in [
      () => create(name: 'Outro'),
      () => create(quantity: 1),
      () => create(quantity: 5, origin: ShoppingItemOrigin.atStore),
      () => create(listId: 'list-002', quantity: 5),
    ]) {
      await expectLater(
        operation(),
        throwsA(isA<ShoppingItemCreationConflict>()),
      );
    }
    expect((await db.query('shopping_items')).single['planned_quantity'], 5);
  });

  test('nomes iguais com IDs distintos continuam permitidos', () async {
    await create();
    await create(id: 'item-002');
    expect((await repository.listItems('list-001')).length, 2);
  });

  test('CT-006/021: editar substitui nome/quantidade e preserva identidade/posição/origem', () async {
    final original = await create(
      quantity: 5,
      origin: ShoppingItemOrigin.atStore,
    );
    final edited = await update(name: '  Carne bovina  ', quantity: 1);
    expect(edited.name, 'Carne bovina');
    expect(edited.plannedQuantity, 1);
    expect(edited.id, original.id);
    expect(edited.shoppingListId, original.shoppingListId);
    expect(edited.origin, original.origin);
    expect(edited.sortOrder, original.sortOrder);
    expect((await db.query('shopping_items')).length, 1);
  });

  test(
    'CT-006: null → 1 → 5 → null persiste sem quantidade implícita',
    () async {
      await create();
      for (final quantity in <int?>[1, 5, null]) {
        await update(quantity: quantity);
        final loaded = (await repository.listItems('list-001')).single;
        expect(loaded.plannedQuantity, quantity);
        expect(
          (await db.query('shopping_items')).single['planned_quantity'],
          quantity,
        );
      }
    },
  );

  test(
    'entradas inválidas não alteram item existente nem criam outro',
    () async {
      await create(quantity: 5);
      for (final operation in [
        () => create(id: ' ', name: 'Novo'),
        () => create(id: 'new', name: ' '),
        () => create(id: 'new', quantity: 0),
        () => update(quantity: -1),
        () => update(name: '\t\n'),
      ]) {
        await expectLater(operation(), throwsArgumentError);
      }
      expect((await db.query('shopping_items')).single['planned_quantity'], 5);
    },
  );

  test('CT-005: remover só marca UTC e preserva os demais dados', () async {
    await create(quantity: 5);
    final before = (await db.query('shopping_items')).single;
    expect(await remove(), isTrue);
    final row = (await db.query('shopping_items')).single;
    expect(row, {...before, 'removed_at_utc': '2026-11-10T12:00:00.000000Z'});
    final loaded = (await repository.listItems('list-001')).single;
    expect(loaded.removedAt, now);
    expect(await remove(), isFalse);
  });

  test(
    'remover duas vezes em paralelo confirma somente uma operação',
    () async {
      await create();
      final results = await Future.wait([remove(), remove()]);
      expect(results.where((result) => result).length, 1);
    },
  );

  test('item removido não é editado ou ressuscitado por retry', () async {
    await create();
    await remove();
    final before = await db.query('shopping_items');
    await expectLater(update(), throwsA(isA<RemovedShoppingItemException>()));
    await expectLater(create(), throwsA(isA<RemovedShoppingItemException>()));
    expect(await db.query('shopping_items'), before);
  });

  test('ausência de item: editar falha; remover retorna false', () async {
    await expectLater(update(), throwsA(isA<ShoppingItemNotFoundException>()));
    expect(await remove(), isFalse);
  });

  test(
    'vínculo não pode ser movido ou usado para alterar outra lista',
    () async {
      await create();
      await expectLater(
        update(listId: 'list-002'),
        throwsA(isA<ShoppingItemNotFoundException>()),
      );
      expect(await remove(listId: 'list-002'), isFalse);
      expect((await repository.listItems('list-001')).single.removedAt, isNull);
      expect(await repository.listItems('list-002'), isEmpty);
    },
  );

  test(
    'lista ausente é erro explícito para leitura e escritas de itens',
    () async {
      for (final operation in <Future<Object?> Function()>[
        () => create(listId: 'missing'),
        () => update(listId: 'missing'),
        () => remove(listId: 'missing'),
        () => repository.listItems('missing'),
      ]) {
        await expectLater(
          operation(),
          throwsA(isA<ShoppingListNotFoundException>()),
        );
      }
      expect(await db.query('shopping_items'), isEmpty);
    },
  );

  test(
    'CT-046: todas as escritas recusam finalizada, incluindo retry e ausente',
    () async {
      await create();
      await finalize();
      final before = await db.query('shopping_items');
      for (final operation in <Future<Object?> Function()>[
        () => create(),
        () => create(id: 'new'),
        () => update(),
        () => remove(),
        () => remove(id: 'missing'),
      ]) {
        await expectLater(
          operation(),
          throwsA(isA<FinalizedShoppingListException>()),
        );
      }
      expect(await db.query('shopping_items'), before);
      expect((await repository.listItems('list-001')).length, 1);
    },
  );

  test(
    'CT-003/006: fechar/reabrir recupera itens das listas separadamente',
    () async {
      await create(quantity: 5);
      await create(
        id: 'other',
        listId: 'list-002',
        origin: ShoppingItemOrigin.atStore,
      );
      await update(quantity: null);
      await db.close();
      db = await appDatabase.open();
      repository = SqliteShoppingRepository(appDatabase);
      expect(
        (await repository.listItems('list-001')).single.plannedQuantity,
        isNull,
      );
      expect((await repository.listItems('list-002')).single.id, 'other');
      final items = await repository.listItems('list-001');
      expect(() => items.clear(), throwsUnsupportedError);
    },
  );

  test(
    'CT-002: excluir lista ativa apaga seus itens sem afetar outra lista',
    () async {
      await create();
      await create(id: 'other', listId: 'list-002');
      await remove();
      expect(await repository.removeActiveList('list-001'), isTrue);
      expect((await db.query('shopping_items')).single['id'], 'other');
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    },
  );

  test(
    'falha de exclusão da lista reverte também o cascade dos itens',
    () async {
      await create();
      await db.execute(
        'CREATE TABLE test_dependency (list_id TEXT REFERENCES shopping_lists(id))',
      );
      await db.insert('test_dependency', {'list_id': 'list-001'});
      await expectLater(
        repository.removeActiveList('list-001'),
        throwsA(isA<DatabaseException>()),
      );
      expect((await repository.listItems('list-001')).single.id, 'item-001');
    },
  );

  test(
    'falhas SQL em criar/editar/remover não retornam sucesso e permitem retry',
    () async {
      for (final operation in ['INSERT', 'UPDATE']) {
        await db.execute(
          '''CREATE TRIGGER fail_item BEFORE $operation ON shopping_items
        BEGIN SELECT RAISE(ABORT, 'simulated storage failure'); END''',
        );
        if (operation == 'INSERT') {
          await expectLater(create(), throwsA(isA<DatabaseException>()));
          expect(await db.query('shopping_items'), isEmpty);
          await db.execute('DROP TRIGGER fail_item');
          await create(quantity: 5);
        } else {
          final before = await db.query('shopping_items');
          await expectLater(
            update(quantity: 1),
            throwsA(isA<DatabaseException>()),
          );
          await expectLater(remove(), throwsA(isA<DatabaseException>()));
          expect(await db.query('shopping_items'), before);
          await db.execute('DROP TRIGGER fail_item');
          expect((await update(quantity: 1)).plannedQuantity, 1);
          expect(await remove(), isTrue);
        }
      }
    },
  );

  test('concorrência: criações distintas recebem posições distintas', () async {
    final items = await Future.wait([
      for (var i = 0; i < 6; i++) create(id: 'item-$i'),
    ]);
    expect(items.map((item) => item.sortOrder).toSet(), {0, 1, 2, 3, 4, 5});
  });

  test('remoção não reutiliza posição de um registro preservado', () async {
    await create();
    await remove();
    expect((await create(id: 'next')).sortOrder, 1);
  });

  test('limite técnico da posição falha sem overflow ou gravação', () async {
    await create();
    await db.update('shopping_items', {'sort_order': 9223372036854775807});
    await expectLater(create(id: 'new'), throwsStateError);
    expect((await db.query('shopping_items')).length, 1);
  });

  test('edição que espera finalização em transação é recusada', () async {
    await create();
    final started = Completer<void>();
    final release = Completer<void>();
    final pendingFinalization = db.transaction((txn) async {
      await txn.update(
        'shopping_lists',
        {
          'status': 'finalized',
          'finalized_at_utc': '2026-11-10T14:00:00.000Z',
          'finalized_registered_total_cents': 0,
        },
        where: 'id = ?',
        whereArgs: ['list-001'],
      );
      started.complete();
      await release.future;
    });
    await started.future;
    final pendingUpdate = expectLater(
      update(quantity: 1),
      throwsA(isA<FinalizedShoppingListException>()),
    );
    release.complete();
    await pendingFinalization;
    await pendingUpdate;
    expect(
      (await db.query('shopping_items')).single['planned_quantity'],
      isNull,
    );
  });

  test(
    'leitura recusa data corrompida sem descartar nem reescrever registro',
    () async {
      await create();
      await db.update('shopping_items', {
        'removed_at_utc': '2026-02-30T12:00:00Z',
      });
      final before = await db.query('shopping_items');
      await expectLater(
        repository.listItems('list-001'),
        throwsFormatException,
      );
      expect(await db.query('shopping_items'), before);
    },
  );
}
