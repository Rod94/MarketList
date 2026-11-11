import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:market_list/core/database/app_database.dart';
import 'package:market_list/core/money/money.dart';
import 'package:market_list/features/shopping/data/sqlite_shopping_repository.dart';
import 'package:market_list/features/shopping/domain/models/purchase_entry.dart';
import 'package:market_list/features/shopping/domain/models/shopping_item.dart';
import 'package:market_list/features/shopping/domain/shopping_repository.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late AppDatabase database;
  late Database db;
  late SqliteShoppingRepository repository;
  PurchaseEntry entry({
    String id = 'e',
    String item = 'soap',
    int? quantity = 3,
    int? price = 350,
    int? direct,
  }) => PurchaseEntry(
    id: id,
    shoppingItemId: item,
    quantity: direct == null ? quantity : null,
    unitPriceCents: direct == null ? price : null,
    directAmountCents: direct,
  );
  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'market_list_purchase_test_',
    );
    database = AppDatabase(
      factory: databaseFactoryFfi,
      path: p.join(directory.path, 'purchase.db'),
    );
    db = await database.open();
    repository = SqliteShoppingRepository(database);
    await repository.createList(id: 'list', name: 'Compra');
    await repository.createList(id: 'other-list', name: 'Outra');
    for (final id in ['soap', 'milk', 'meat']) {
      await repository.createItem(
        id: id,
        shoppingListId: 'list',
        name: id,
        origin: ShoppingItemOrigin.planned,
        plannedQuantity: id == 'soap' ? 5 : null,
      );
    }
    await repository.createItem(
      id: 'foreign',
      shoppingListId: 'other-list',
      name: 'Outra',
      origin: ShoppingItemOrigin.planned,
    );
  });
  tearDown(() async {
    if (db.isOpen) await db.close();
    final root = await Directory.systemTemp.resolveSymbolicLinks();
    final target = await directory.resolveSymbolicLinks();
    if (!p.isWithin(root, target) ||
        !p.basename(target).startsWith('market_list_purchase_test_')) {
      throw StateError('Recusando limpeza fora da pasta de teste.');
    }
    await directory.delete(recursive: true);
  });
  test(
    'FIN-006/022/023 finaliza com pendências e preserva caixa e entradas',
    () async {
      await repository.createPurchaseEntry(
        shoppingListId: 'list',
        entry: entry(),
      );
      final review = await repository.loadShoppingSnapshot('list');
      final finalized = await repository.finalizeShoppingList(
        review,
        checkoutPaidCents: 1150,
      );
      expect(finalized.list.status.name, 'finalized');
      expect(finalized.list.finalizedAt, isNotNull);
      expect(finalized.list.finalizedRegisteredTotalCents, 1050);
      expect(finalized.list.checkoutPaidCents, 1150);
      expect(
        finalized.calculation.itemsNeedingAttention.map(
          (item) => item.missingQuantity,
        ),
        [2, null, null],
      );
      expect((await repository.listActiveLists()).map((list) => list.id), [
        'other-list',
      ]);
      await db.close();
      db = await database.open();
      final reopened = await repository.loadShoppingSnapshot('list');
      expect(reopened.list.checkoutPaidCents, 1150);
      expect(reopened.list.finalizedRegisteredTotalCents, 1050);
      expect(
        reopened.calculation.items.first.entries.single.unitPriceCents,
        350,
      );
    },
  );

  test('FIN-021/024 distingue caixa ausente, zero e valor negativo', () async {
    final review = await repository.loadShoppingSnapshot('list');
    await expectLater(
      repository.finalizeShoppingList(review, checkoutPaidCents: -1),
      throwsRangeError,
    );
    final blank = await repository.finalizeShoppingList(review);
    final other = await repository.loadShoppingSnapshot('other-list');
    final zero = await repository.finalizeShoppingList(
      other,
      checkoutPaidCents: 0,
    );
    expect(blank.list.checkoutPaidCents, isNull);
    expect(zero.list.checkoutPaidCents, 0);
  });

  test(
    'CT-047 duas chamadas concorrentes confirmam uma só finalização',
    () async {
      final review = await repository.loadShoppingSnapshot('list');
      Future<int?> attempt(int paid) async {
        try {
          return (await repository.finalizeShoppingList(
            review,
            checkoutPaidCents: paid,
          )).list.checkoutPaidCents;
        } on FinalizedShoppingListException {
          return null;
        }
      }

      final results = await Future.wait([attempt(0), attempt(500)]);
      final successful = results.nonNulls.single;
      expect(
        (await repository.loadShoppingSnapshot('list')).list.checkoutPaidCents,
        successful,
      );
    },
  );

  test(
    'CT-048/FIN-017 erro SQL reverte status, data e ambos os totais',
    () async {
      final review = await repository.loadShoppingSnapshot('list');
      await db.execute('''
      CREATE TRIGGER fail_finalize AFTER UPDATE OF status ON shopping_lists
      WHEN NEW.status = 'finalized'
      BEGIN SELECT RAISE(ABORT, 'falha simulada'); END
    ''');
      await expectLater(
        repository.finalizeShoppingList(review, checkoutPaidCents: 100),
        throwsA(isA<DatabaseException>()),
      );
      final unchanged = (await repository.loadShoppingSnapshot('list')).list;
      expect(unchanged.status.name, 'active');
      expect(unchanged.finalizedAt, isNull);
      expect(unchanged.finalizedRegisteredTotalCents, isNull);
      expect(unchanged.checkoutPaidCents, isNull);
      await db.execute('DROP TRIGGER fail_finalize');
      expect(
        (await repository.finalizeShoppingList(
          review,
          checkoutPaidCents: 100,
        )).list.checkoutPaidCents,
        100,
      );
    },
  );

  test('conferência desatualizada exige nova confirmação com total ou avisos alterados', () async {
    final first = await repository.loadShoppingSnapshot('list');
    await repository.updateItem(
      id: 'soap',
      shoppingListId: 'list',
      name: 'Sabonete',
      plannedQuantity: 5,
    );
    await expectLater(
      repository.finalizeShoppingList(first),
      throwsA(isA<ShoppingReviewChangedException>()),
    );
    final second = await repository.loadShoppingSnapshot('list');
    await repository.createPurchaseEntry(
      shoppingListId: 'list',
      entry: entry(),
    );
    await expectLater(
      repository.finalizeShoppingList(second),
      throwsA(isA<ShoppingReviewChangedException>()),
    );
    final third = await repository.loadShoppingSnapshot('list');
    await repository.updateListBudget('list', 1000);
    await expectLater(
      repository.finalizeShoppingList(third),
      throwsA(isA<ShoppingReviewChangedException>()),
    );
    expect(
      (await repository.loadShoppingSnapshot('list')).list.status.name,
      'active',
    );
  });

  test(
    'CT-046/FIN-016 todas as gravações recusam a compra finalizada',
    () async {
      await repository.createPurchaseEntry(
        shoppingListId: 'list',
        entry: entry(),
      );
      final removedAt = (await repository.removeItemForUndo(
        id: 'milk',
        shoppingListId: 'list',
      ))!;
      final review = await repository.loadShoppingSnapshot('list');
      await repository.finalizeShoppingList(review, checkoutPaidCents: 1111);
      final before = [
        await db.query('shopping_lists'),
        await db.query('shopping_items'),
        await db.query('purchase_entries'),
      ];
      final mutations = <Future<Object?> Function()>[
        () => repository.createList(id: 'list', name: 'Compra'),
        () => repository.removeActiveList('list'),
        () => repository.updateListBudget('list', 0),
        () => repository.createItem(
          id: 'new',
          shoppingListId: 'list',
          name: 'Novo',
          origin: ShoppingItemOrigin.planned,
        ),
        () => repository.createItemWithPurchase(
          id: 'new',
          shoppingListId: 'list',
          name: 'Novo',
          entry: entry(id: 'new-entry', item: 'new'),
        ),
        () => repository.updateItem(
          id: 'soap',
          shoppingListId: 'list',
          name: 'Outro',
          plannedQuantity: null,
        ),
        () => repository.removeItem(id: 'soap', shoppingListId: 'list'),
        () => repository.restoreRemovedItem(
          id: 'milk',
          shoppingListId: 'list',
          removedAt: removedAt,
        ),
        () => repository.createPurchaseEntry(
          shoppingListId: 'list',
          entry: entry(id: 'another'),
        ),
        () => repository.updatePurchaseEntry(
          shoppingListId: 'list',
          entry: entry(price: 420),
        ),
        () => repository.removePurchaseEntry(
          shoppingListId: 'list',
          shoppingItemId: 'soap',
          entryId: 'e',
        ),
        () => repository.finalizeShoppingList(review, checkoutPaidCents: 0),
      ];
      for (final mutate in mutations) {
        await expectLater(
          mutate(),
          throwsA(isA<FinalizedShoppingListException>()),
        );
      }
      expect([
        await db.query('shopping_lists'),
        await db.query('shopping_items'),
        await db.query('purchase_entries'),
      ], before);
    },
  );

  test(
    'CT-009/010: vários preços retornam fotografia confirmada com total exato',
    () async {
      await repository.createPurchaseEntry(
        shoppingListId: 'list',
        entry: entry(),
      );
      await repository.createPurchaseEntry(
        shoppingListId: 'list',
        entry: entry(id: 'second', quantity: 2, price: 420),
      );
      await repository.createPurchaseEntry(
        shoppingListId: 'list',
        entry: entry(id: 'milk', item: 'milk', price: 422),
      );
      final result = await repository.createPurchaseEntry(
        shoppingListId: 'list',
        entry: entry(id: 'meat', item: 'meat', direct: 4782),
      );
      expect(result.totalCents, 7938);
      expect((await db.query('purchase_entries')).length, 4);
    },
  );
  test(
    'CT-035: mesmo ID/dados, inclusive concorrentes, não duplicam compra',
    () async {
      final results = await Future.wait([
        repository.createPurchaseEntry(shoppingListId: 'list', entry: entry()),
        repository.createPurchaseEntry(shoppingListId: 'list', entry: entry()),
      ]);
      expect(results.map((r) => r.totalCents), [1050, 1050]);
      expect((await db.query('purchase_entries')).length, 1);
    },
  );
  test(
    'concorrência com valores altos confirma só a operação que cabe no total',
    () async {
      Future<bool> attempt(String id) async {
        try {
          await repository.createPurchaseEntry(
            shoppingListId: 'list',
            entry: entry(id: id, direct: maxMoneyCents),
          );
          return true;
        } on RangeError {
          return false;
        }
      }

      final results = await Future.wait([attempt('a'), attempt('b')]);
      expect(results.where((success) => success).length, 1);
      expect((await db.query('purchase_entries')).length, 1);
      expect(
        (await repository.loadShoppingList('list')).totalCents,
        maxMoneyCents,
      );
    },
  );
  test(
    'falha em cascade da lista preserva lista, item e entrada atomicamente',
    () async {
      await repository.createPurchaseEntry(
        shoppingListId: 'list',
        entry: entry(),
      );
      await db.execute(
        '''CREATE TRIGGER fail_cascade BEFORE DELETE ON purchase_entries
      BEGIN SELECT RAISE(ABORT, 'simulated storage failure'); END''',
      );
      await expectLater(
        repository.removeActiveList('list'),
        throwsA(isA<DatabaseException>()),
      );
      expect((await repository.loadShoppingList('list')).totalCents, 1050);
      expect(
        (await db.query(
          'shopping_items',
          where: 'id = ?',
          whereArgs: ['soap'],
        )).length,
        1,
      );
    },
  );

  test(
    'F3-07: item espontâneo e primeira entrada são confirmados juntos',
    () async {
      final result = await repository.createItemWithPurchase(
        id: 'new',
        shoppingListId: 'list',
        name: 'Leite',
        entry: entry(id: 'quick', item: 'new', quantity: 3, price: 422),
      );
      expect(result.totalCents, 1266);
      final added = result.items.firstWhere((s) => s.item.id == 'new');
      expect(added.item.origin, ShoppingItemOrigin.atStore);
      expect(added.item.plannedQuantity, isNull);
      expect(added.entries.single.quantity, 3);
    },
  );
  test(
    'F3-07: retry concorrente com mesmos IDs não duplica produto nem compra',
    () async {
      Future<Object> add() => repository.createItemWithPurchase(
        id: 'new',
        shoppingListId: 'list',
        name: 'Leite',
        entry: entry(id: 'quick', item: 'new', quantity: 3, price: 422),
      );
      await Future.wait([add(), add()]);
      expect(
        (await db.query(
          'shopping_items',
          where: 'id = ?',
          whereArgs: ['new'],
        )).length,
        1,
      );
      expect((await db.query('purchase_entries')).length, 1);
    },
  );
  test(
    'F3-07: erro na entrada reverte também o produto e permite retry',
    () async {
      await db.execute(
        '''CREATE TRIGGER fail_quick BEFORE INSERT ON purchase_entries
      BEGIN SELECT RAISE(ABORT, 'simulated storage failure'); END''',
      );
      Future<Object> add() => repository.createItemWithPurchase(
        id: 'new',
        shoppingListId: 'list',
        name: 'Leite',
        entry: entry(id: 'quick', item: 'new', direct: 4782),
      );
      await expectLater(add(), throwsA(isA<DatabaseException>()));
      expect(
        await db.query('shopping_items', where: 'id = ?', whereArgs: ['new']),
        isEmpty,
      );
      expect(await db.query('purchase_entries'), isEmpty);
      await db.execute('DROP TRIGGER fail_quick');
      await add();
      expect((await repository.loadShoppingList('list')).totalCents, 4782);
    },
  );
  test('F3-07: overflow do total reverte ambas as inclusões', () async {
    await repository.createPurchaseEntry(
      shoppingListId: 'list',
      entry: entry(direct: maxMoneyCents),
    );
    await expectLater(
      repository.createItemWithPurchase(
        id: 'new',
        shoppingListId: 'list',
        name: 'Outro',
        entry: entry(id: 'quick', item: 'new', direct: 1),
      ),
      throwsRangeError,
    );
    expect(
      await db.query('shopping_items', where: 'id = ?', whereArgs: ['new']),
      isEmpty,
    );
    expect((await db.query('purchase_entries')).length, 1);
  });
  test('F3-07: entrada de outro ID não pode criar produto parcial', () async {
    await expectLater(
      repository.createItemWithPurchase(
        id: 'new',
        shoppingListId: 'list',
        name: 'Outro',
        entry: entry(),
      ),
      throwsArgumentError,
    );
    expect(
      await db.query('shopping_items', where: 'id = ?', whereArgs: ['new']),
      isEmpty,
    );
  });
  test(
    'D-031: nomes iguais com IDs distintos continuam inclusões legítimas',
    () async {
      for (final id in ['new-a', 'new-b']) {
        await repository.createItemWithPurchase(
          id: id,
          shoppingListId: 'list',
          name: 'Leite',
          entry: entry(id: 'e-$id', item: id, direct: 100),
        );
      }
      expect(
        (await db.query(
          'shopping_items',
          where: 'name = ?',
          whereArgs: ['Leite'],
        )).length,
        2,
      );
      expect((await repository.loadShoppingList('list')).totalCents, 200);
    },
  );

  test('ID de entrada é UUID v4 e não depende do relógio', () {
    final first = repository.newEntryId();
    final second = repository.newEntryId();
    expect(
      first,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    expect(first, isNot(second));
  });
  test('criação repetida com dados/vínculo diferentes gera conflito, sem substituir', () async {
    await repository.createPurchaseEntry(
      shoppingListId: 'list',
      entry: entry(),
    );
    for (final changed in [
      entry(price: 420),
      entry(item: 'milk'),
      entry(direct: 100),
    ]) {
      await expectLater(
        repository.createPurchaseEntry(shoppingListId: 'list', entry: changed),
        throwsA(isA<PurchaseEntryCreationConflict>()),
      );
    }
    expect((await repository.loadShoppingList('list')).totalCents, 1050);
  });
  test(
    'CT-022/027: correção substitui preço na mesma linha e retorna novo total',
    () async {
      await repository.createPurchaseEntry(
        shoppingListId: 'list',
        entry: entry(quantity: 1, price: 2590),
      );
      final result = await repository.updatePurchaseEntry(
        shoppingListId: 'list',
        entry: entry(quantity: 1, price: 2390),
      );
      expect(result.totalCents, 2390);
      expect((await db.query('purchase_entries')).length, 1);
    },
  );
  test(
    'CT-025: troca entre modo unitário e direto limpa campos incompatíveis',
    () async {
      await repository.createPurchaseEntry(
        shoppingListId: 'list',
        entry: entry(),
      );
      var result = await repository.updatePurchaseEntry(
        shoppingListId: 'list',
        entry: entry(direct: 4782),
      );
      expect(result.totalCents, 4782);
      var row = (await db.query('purchase_entries')).single;
      expect(row['quantity'], isNull);
      expect(row['unit_price_cents'], isNull);
      result = await repository.updatePurchaseEntry(
        shoppingListId: 'list',
        entry: entry(quantity: 2, price: 100),
      );
      row = (await db.query('purchase_entries')).single;
      expect(row['direct_amount_cents'], isNull);
      expect(result.totalCents, 200);
    },
  );
  test('CT-023: remover só uma entrada desconta apenas seu subtotal', () async {
    await repository.createPurchaseEntry(
      shoppingListId: 'list',
      entry: entry(),
    );
    await repository.createPurchaseEntry(
      shoppingListId: 'list',
      entry: entry(id: 'second', quantity: 2, price: 420),
    );
    final result = await repository.removePurchaseEntry(
      shoppingListId: 'list',
      shoppingItemId: 'soap',
      entryId: 'second',
    );
    expect(result.totalCents, 1050);
    expect((await db.query('purchase_entries')).single['id'], 'e');
    await expectLater(
      repository.removePurchaseEntry(
        shoppingListId: 'list',
        shoppingItemId: 'soap',
        entryId: 'second',
      ),
      throwsA(isA<PurchaseEntryNotFoundException>()),
    );
  });
  test('D-032 restaura a mesma linha e os preços uma vez', () async {
    await repository.createPurchaseEntry(
      shoppingListId: 'list',
      entry: entry(),
    );
    final removedAt = (await repository.removeItemForUndo(
      id: 'soap',
      shoppingListId: 'list',
    ))!;
    expect((await repository.loadShoppingList('list')).totalCents, 0);
    expect(
      await repository.restoreRemovedItem(
        id: 'soap',
        shoppingListId: 'list',
        removedAt: removedAt.subtract(const Duration(microseconds: 1)),
      ),
      isNull,
    );
    final restored = await repository.restoreRemovedItem(
      id: 'soap',
      shoppingListId: 'list',
      removedAt: removedAt,
    );
    expect(restored!.items.map((summary) => summary.item.id), [
      'soap',
      'milk',
      'meat',
    ]);
    expect(restored.totalCents, 1050);
    expect(
      await repository.restoreRemovedItem(
        id: 'soap',
        shoppingListId: 'list',
        removedAt: removedAt,
      ),
      isNull,
    );
    expect((await db.query('purchase_entries')).single['id'], 'e');
  });

  test('D-032 reverte o desfazer se o total ultrapassar o limite', () async {
    await repository.createPurchaseEntry(
      shoppingListId: 'list',
      entry: entry(direct: maxMoneyCents),
    );
    final removedAt = (await repository.removeItemForUndo(
      id: 'soap',
      shoppingListId: 'list',
    ))!;
    await repository.createPurchaseEntry(
      shoppingListId: 'list',
      entry: entry(id: 'milk', item: 'milk', direct: 1),
    );
    await expectLater(
      repository.restoreRemovedItem(
        id: 'soap',
        shoppingListId: 'list',
        removedAt: removedAt,
      ),
      throwsRangeError,
    );
    final result = await repository.loadShoppingList('list');
    expect(result.totalCents, 1);
    expect(result.items.first.item.removedAt, removedAt);
    expect((await db.query('purchase_entries')).length, 2);
  });

  test('D-032 repositório recusa restaurar após a lista finalizar', () async {
    final removedAt = (await repository.removeItemForUndo(
      id: 'soap',
      shoppingListId: 'list',
    ))!;
    await db.update(
      'shopping_lists',
      {
        'status': 'finalized',
        'finalized_at_utc': DateTime.now()
            .toUtc()
            .add(const Duration(minutes: 1))
            .toIso8601String(),
        'finalized_registered_total_cents': 0,
      },
      where: 'id = ?',
      whereArgs: ['list'],
    );
    await expectLater(
      repository.restoreRemovedItem(
        id: 'soap',
        shoppingListId: 'list',
        removedAt: removedAt,
      ),
      throwsA(isA<FinalizedShoppingListException>()),
    );
    expect((await repository.listItems('list')).first.removedAt, removedAt);
  });

  test(
    'CT-024/050: remover item comprado retira subtotal sem apagar entradas',
    () async {
      await repository.createPurchaseEntry(
        shoppingListId: 'list',
        entry: entry(),
      );
      await repository.removeItem(id: 'soap', shoppingListId: 'list');
      expect((await repository.loadShoppingList('list')).totalCents, 0);
      expect((await db.query('purchase_entries')).single['id'], 'e');
      await expectLater(
        repository.createPurchaseEntry(
          shoppingListId: 'list',
          entry: entry(id: 'new'),
        ),
        throwsA(isA<RemovedShoppingItemException>()),
      );
      await expectLater(
        repository.updatePurchaseEntry(
          shoppingListId: 'list',
          entry: entry(price: 100),
        ),
        throwsA(isA<RemovedShoppingItemException>()),
      );
      await expectLater(
        repository.removePurchaseEntry(
          shoppingListId: 'list',
          shoppingItemId: 'soap',
          entryId: 'e',
        ),
        throwsA(isA<RemovedShoppingItemException>()),
      );
    },
  );
  test('CT-021: renomear mantém entradas vinculadas e subtotal', () async {
    await repository.createPurchaseEntry(
      shoppingListId: 'list',
      entry: entry(),
    );
    await repository.updateItem(
      id: 'soap',
      shoppingListId: 'list',
      name: 'Sabonete',
      plannedQuantity: null,
    );
    final snapshot = await repository.loadShoppingList('list');
    expect(snapshot.totalCents, 1050);
    expect(
      snapshot.items.firstWhere((s) => s.item.id == 'soap').entries.single.id,
      'e',
    );
  });
  test('D-028: gratuito persiste sem virar ausência', () async {
    final result = await repository.createPurchaseEntry(
      shoppingListId: 'list',
      entry: entry(price: 0),
    );
    expect(result.totalCents, 0);
    expect(
      result.items.firstWhere((s) => s.item.id == 'soap').entries.length,
      1,
    );
    expect((await db.query('purchase_entries')).single['unit_price_cents'], 0);
  });
  test('vínculos estrangeiros, órfãos e entrada ausente não podem ser gravados/movidos', () async {
    await expectLater(
      repository.createPurchaseEntry(
        shoppingListId: 'list',
        entry: entry(item: 'foreign'),
      ),
      throwsA(isA<ShoppingItemNotFoundException>()),
    );
    await expectLater(
      repository.createPurchaseEntry(
        shoppingListId: 'list',
        entry: entry(item: 'missing'),
      ),
      throwsA(isA<ShoppingItemNotFoundException>()),
    );
    await expectLater(
      repository.updatePurchaseEntry(shoppingListId: 'list', entry: entry()),
      throwsA(isA<PurchaseEntryNotFoundException>()),
    );
    await repository.createPurchaseEntry(
      shoppingListId: 'list',
      entry: entry(),
    );
    await expectLater(
      repository.updatePurchaseEntry(
        shoppingListId: 'list',
        entry: entry(item: 'milk'),
      ),
      throwsA(isA<PurchaseEntryNotFoundException>()),
    );
    expect((await repository.loadShoppingList('list')).totalCents, 1050);
  });
  test(
    'CT-046: finalizada recusa criar/retry/editar/remover sem depender de UI',
    () async {
      await repository.createPurchaseEntry(
        shoppingListId: 'list',
        entry: entry(),
      );
      await db.update(
        'shopping_lists',
        {
          'status': 'finalized',
          'finalized_at_utc': '2026-11-10T18:00:00Z',
          'finalized_registered_total_cents': 1050,
        },
        where: 'id = ?',
        whereArgs: ['list'],
      );
      final before = await db.query('purchase_entries');
      for (final operation in <Future<Object?> Function()>[
        () => repository.createPurchaseEntry(
          shoppingListId: 'list',
          entry: entry(),
        ),
        () => repository.updatePurchaseEntry(
          shoppingListId: 'list',
          entry: entry(),
        ),
        () => repository.removePurchaseEntry(
          shoppingListId: 'list',
          shoppingItemId: 'soap',
          entryId: 'e',
        ),
      ]) {
        await expectLater(
          operation(),
          throwsA(isA<FinalizedShoppingListException>()),
        );
      }
      expect(await db.query('purchase_entries'), before);
      expect((await repository.loadShoppingList('list')).totalCents, 1050);
    },
  );
  test(
    'D-029: soma da lista não pode estourar; criação falha e reverte linha',
    () async {
      await repository.createPurchaseEntry(
        shoppingListId: 'list',
        entry: entry(direct: maxMoneyCents),
      );
      await expectLater(
        repository.createPurchaseEntry(
          shoppingListId: 'list',
          entry: entry(id: 'extra', item: 'milk', direct: 1),
        ),
        throwsRangeError,
      );
      expect((await db.query('purchase_entries')).length, 1);
      expect(
        (await repository.loadShoppingList('list')).totalCents,
        maxMoneyCents,
      );
    },
  );
  test(
    'D-029: edição que estoura soma reverte e mantém total anterior',
    () async {
      await repository.createPurchaseEntry(
        shoppingListId: 'list',
        entry: entry(direct: maxMoneyCents - 1),
      );
      await repository.createPurchaseEntry(
        shoppingListId: 'list',
        entry: entry(id: 'extra', item: 'milk', direct: 1),
      );
      await expectLater(
        repository.updatePurchaseEntry(
          shoppingListId: 'list',
          entry: entry(id: 'extra', item: 'milk', direct: 2),
        ),
        throwsRangeError,
      );
      expect(
        (await repository.loadShoppingList('list')).totalCents,
        maxMoneyCents,
      );
      expect(
        (await db.query(
          'purchase_entries',
          where: 'id = ?',
          whereArgs: ['extra'],
        )).single['direct_amount_cents'],
        1,
      );
    },
  );
  test('reabertura recupera fotografia e cascade de lista elimina só seus dependentes', () async {
    await repository.createPurchaseEntry(
      shoppingListId: 'list',
      entry: entry(),
    );
    await repository.createPurchaseEntry(
      shoppingListId: 'other-list',
      entry: entry(id: 'foreign-entry', item: 'foreign', direct: 10),
    );
    await db.close();
    db = await database.open();
    repository = SqliteShoppingRepository(database);
    expect((await repository.loadShoppingList('list')).totalCents, 1050);
    await repository.removeActiveList('list');
    expect((await db.query('purchase_entries')).single['id'], 'foreign-entry');
    expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
  });
  test('falhas SQL de inserir/editar/excluir não retornam sucesso e permitem retry', () async {
    for (final op in ['INSERT', 'UPDATE', 'DELETE']) {
      await db.execute(
        '''CREATE TRIGGER fail_entry BEFORE $op ON purchase_entries
        BEGIN SELECT RAISE(ABORT, 'simulated storage failure'); END''',
      );
      final before = await db.query('purchase_entries');
      final action = op == 'INSERT'
          ? repository.createPurchaseEntry(
              shoppingListId: 'list',
              entry: entry(),
            )
          : op == 'UPDATE'
          ? repository.updatePurchaseEntry(
              shoppingListId: 'list',
              entry: entry(price: 100),
            )
          : repository.removePurchaseEntry(
              shoppingListId: 'list',
              shoppingItemId: 'soap',
              entryId: 'e',
            );
      await expectLater(action, throwsA(isA<DatabaseException>()));
      expect(await db.query('purchase_entries'), before);
      await db.execute('DROP TRIGGER fail_entry');
      if (op == 'INSERT') {
        await repository.createPurchaseEntry(
          shoppingListId: 'list',
          entry: entry(),
        );
      }
    }
    expect(
      (await repository.removePurchaseEntry(
        shoppingListId: 'list',
        shoppingItemId: 'soap',
        entryId: 'e',
      )).totalCents,
      0,
    );
  });
}
