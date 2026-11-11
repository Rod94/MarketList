import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:market_list/core/database/app_database.dart';
import 'package:market_list/features/shopping/data/sqlite_shopping_repository.dart';
import 'package:market_list/features/shopping/domain/models/shopping_list.dart';
import 'package:market_list/features/shopping/domain/shopping_repository.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory directory;
  late AppDatabase appDatabase;
  late Database db;
  late SqliteShoppingRepository repository;
  late DateTime now;

  Future<ShoppingList> create({
    String id = 'list-001',
    String name = 'Compra da semana',
    int? budgetCents,
  }) => repository.createList(id: id, name: name, budgetCents: budgetCents);

  Future<void> seed({
    required String id,
    String createdAt = '2026-11-09T12:00:00.000Z',
    bool finalized = false,
  }) async {
    await db.insert('shopping_lists', {
      'id': id,
      'name': 'Lista $id',
      'status': finalized ? 'finalized' : 'active',
      'created_at_utc': createdAt,
      'finalized_at_utc': finalized ? '2026-11-09T14:00:00.000Z' : null,
      'budget_cents': null,
      'finalized_registered_total_cents': finalized ? 52780 : null,
      'checkout_paid_cents': finalized ? 53020 : null,
    });
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('market_list_repo_test_');
    appDatabase = AppDatabase(
      factory: databaseFactoryFfi,
      path: p.join(directory.path, 'repository.db'),
    );
    db = await appDatabase.open();
    now = DateTime.utc(2026, 11, 9, 12);
    repository = SqliteShoppingRepository(appDatabase, now: () => now);
  });

  tearDown(() async {
    if (db.isOpen) await db.close();
    final root = await Directory.systemTemp.resolveSymbolicLinks();
    final target = await directory.resolveSymbolicLinks();
    if (!p.isWithin(root, target) ||
        !p.basename(target).startsWith('market_list_repo_test_')) {
      throw StateError('Recusando limpeza fora da pasta de teste.');
    }
    await directory.delete(recursive: true);
  });

  test('F1-03: disponibiliza novos IDs UUID v4 sem depender do nome/relógio', () {
    final first = repository.newListId();
    final second = repository.newListId();
    final pattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );
    expect(first, matches(pattern));
    expect(second, matches(pattern));
    expect(first, isNot(second));
  });

  test('F6-01 histórico usa conclusão, desempata por ID e preserva frações antigas', () async {
    await seed(id: 'ativa');
    for (final (id, finalizedAt) in [
      ('b', '2026-11-09T14:00:00.000Z'),
      ('c', '2026-11-09T14:00:00.000001Z'),
      ('a', '2026-11-09T14:00:00Z'),
    ]) {
      await seed(id: id, finalized: true);
      await db.update(
        'shopping_lists',
        {'finalized_at_utc': finalizedAt},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    final before = await db.query('shopping_lists');
    final history = await repository.listFinalizedLists();
    expect(history.map((list) => list.id), ['c', 'a', 'b']);
    expect(
      history.map((list) => list.finalizedRegisteredTotalCents),
      everyElement(52780),
    );
    expect(() => history.clear(), throwsUnsupportedError);
    await db.close();
    db = await appDatabase.open();
    expect((await repository.listFinalizedLists()).map((list) => list.id), [
      'c',
      'a',
      'b',
    ]);
    expect(await db.query('shopping_lists'), before);
  });

  test('F6-01 lista vazia e somente ativas produzem histórico vazio', () async {
    expect(await repository.listFinalizedLists(), isEmpty);
    await seed(id: 'ativa');
    expect(await repository.listFinalizedLists(), isEmpty);
  });

  test(
    'CT-001 repositório: cria ativa, valida nome e confirma linha persistida',
    () async {
      final result = await create(name: '  Compra da semana  ');
      expect(result.id, 'list-001');
      expect(result.name, 'Compra da semana');
      expect(result.status, ShoppingListStatus.active);
      expect(result.createdAt, now);
      expect(result.createdAt.isUtc, isTrue);
      expect(result.budgetCents, isNull);
      final row = (await db.query('shopping_lists')).single;
      expect(row['name'], result.name);
      expect(row['created_at_utc'], '2026-11-09T12:00:00.000000Z');
      expect(row['finalized_at_utc'], isNull);
      expect(row['finalized_registered_total_cents'], isNull);
      expect(row['checkout_paid_cents'], isNull);
    },
  );

  test('F1-03: orçamento zero permanece distinto de ausente', () async {
    await create(id: 'absent');
    await create(id: 'zero', budgetCents: 0);
    final lists = await repository.listActiveLists();
    expect(
      lists.singleWhere((list) => list.id == 'absent').budgetCents,
      isNull,
    );
    expect(lists.singleWhere((list) => list.id == 'zero').budgetCents, 0);
  });

  test('F1-03: valida entradas antes de persistir', () async {
    await expectLater(create(id: '  '), throwsArgumentError);
    await expectLater(create(name: '\t\n'), throwsArgumentError);
    await expectLater(create(budgetCents: -1), throwsArgumentError);
    await expectLater(repository.removeActiveList('  '), throwsArgumentError);
    expect(await db.query('shopping_lists'), isEmpty);
  });

  test('CT-031 orçamento ativo pode mudar, ser zero ou ser retirado', () async {
    final list = await create(budgetCents: 80000);
    for (final value in [90000, 0, null]) {
      final updated = await repository.updateListBudget(list.id, value);
      expect(updated.budgetCents, value);
      expect(updated.name, list.name);
      expect(updated.createdAt, list.createdAt);
      expect((await repository.listActiveLists()).single.budgetCents, value);
    }
  });

  test(
    'CT-031 orçamento rejeita lista finalizada, ausente e valor negativo',
    () async {
      await seed(id: 'history', finalized: true);
      final active = await create(budgetCents: 80000);
      await expectLater(
        repository.updateListBudget(active.id, -1),
        throwsRangeError,
      );
      await expectLater(
        repository.updateListBudget('history', 0),
        throwsA(isA<FinalizedShoppingListException>()),
      );
      await expectLater(
        repository.updateListBudget('missing', 0),
        throwsA(isA<ShoppingListNotFoundException>()),
      );
      expect((await repository.listActiveLists()).single.budgetCents, 80000);
      expect(
        (await db.query(
          'shopping_lists',
          where: 'id = ?',
          whereArgs: ['history'],
        )).single['budget_cents'],
        isNull,
      );
    },
  );

  test('F1-03: nomes iguais com IDs diferentes continuam permitidos', () async {
    await create(id: 'one');
    await create(id: 'two');
    expect((await repository.listActiveLists()).length, 2);
  });

  test(
    'CT-003 parcial: reabrir arquivo recupera identidade, data e orçamento',
    () async {
      now = DateTime(2026, 11, 9, 9, 30, 0, 123, 456);
      final saved = await create(budgetCents: 12345);
      await db.close();
      db = await appDatabase.open();
      final reopened = SqliteShoppingRepository(appDatabase);
      final restored = (await reopened.listActiveLists()).single;
      expect(restored.id, saved.id);
      expect(restored.name, saved.name);
      expect(restored.createdAt, saved.createdAt);
      expect(restored.createdAt.isUtc, isTrue);
      expect(restored.budgetCents, 12345);
    },
  );

  test('F1-03: ordena por instante real e desempata por ID, com formatos v1 mistos', () async {
    await seed(id: 'b');
    await seed(id: 'a');
    await seed(id: 'micro', createdAt: '2026-11-09T12:00:00.000001Z');
    await seed(id: 'milli', createdAt: '2026-11-09T12:00:00.001Z');
    expect((await repository.listActiveLists()).map((list) => list.id), [
      'milli',
      'micro',
      'a',
      'b',
    ]);
  });

  test('F1-03: lista apenas ativas sem alterar histórico', () async {
    await create();
    await seed(id: 'history', finalized: true);
    final before = await db.query(
      'shopping_lists',
      where: 'id = ?',
      whereArgs: ['history'],
    );
    expect((await repository.listActiveLists()).single.id, 'list-001');
    expect(
      await db.query('shopping_lists', where: 'id = ?', whereArgs: ['history']),
      before,
    );
  });

  test('F1-03: coleção retornada é somente leitura', () async {
    final saved = await create();
    final lists = await repository.listActiveLists();
    expect(() => lists.add(saved), throwsUnsupportedError);
  });

  test(
    'F1-03: aspas em ID/nome são dados, sem remover outras listas',
    () async {
      const id = "id' OR 1=1 --";
      const name = "Compra d'água'); DROP TABLE shopping_lists; --";
      await create(id: 'preserved');
      await create(id: id, name: name);
      expect(
        (await repository.listActiveLists())
            .singleWhere((list) => list.id == id)
            .name,
        name,
      );
      expect(await repository.removeActiveList(id), isTrue);
      expect((await repository.listActiveLists()).single.id, 'preserved');
    },
  );

  test(
    'F1-03: repetir criação com mesmo ID devolve original sem duplicar',
    () async {
      final first = await create(name: '  Compra da semana  ');
      now = now.add(const Duration(hours: 1));
      final repeated = await create();
      expect(repeated.createdAt, first.createdAt);
      expect(repeated.id, first.id);
      expect((await db.query('shopping_lists')).length, 1);
    },
  );

  test(
    'F1-03: mesmo ID com nome diferente é conflito sem sobrescrever',
    () async {
      await create();
      await expectLater(
        create(name: 'Outro nome'),
        throwsA(isA<ShoppingListCreationConflict>()),
      );
      expect(
        (await repository.listActiveLists()).single.name,
        'Compra da semana',
      );
    },
  );

  test(
    'F1-03: mesmo ID com orçamento diferente é conflito sem sobrescrever',
    () async {
      await create();
      await expectLater(
        create(budgetCents: 0),
        throwsA(isA<ShoppingListCreationConflict>()),
      );
      expect((await repository.listActiveLists()).single.budgetCents, isNull);
    },
  );

  test(
    'CT-046 parcial: criar com ID finalizado não reabre nem altera histórico',
    () async {
      await seed(id: 'history', finalized: true);
      final before = await db.query('shopping_lists');
      await expectLater(
        create(id: 'history'),
        throwsA(isA<FinalizedShoppingListException>()),
      );
      expect(await db.query('shopping_lists'), before);
    },
  );

  test(
    'F1-03: criações simultâneas de mesmo ID persistem uma única linha',
    () async {
      final another = SqliteShoppingRepository(appDatabase);
      final results = await Future.wait([
        create(),
        another.createList(id: 'list-001', name: 'Compra da semana'),
        create(),
      ]);
      expect(results.map((list) => list.id).toSet(), {'list-001'});
      expect(results.map((list) => list.createdAt).toSet().length, 1);
      expect((await db.query('shopping_lists')).length, 1);
    },
  );

  test('F1-03: concorrência com ID igual e dados diferentes não perde a primeira gravação', () async {
    final outcomes = await Future.wait([
      create(name: 'Primeira')
          .then<Object>((value) => value, onError: (Object error) => error),
      create(name: 'Segunda')
          .then<Object>((value) => value, onError: (Object error) => error),
    ]);
    expect(outcomes.whereType<ShoppingList>().length, 1);
    expect(outcomes.whereType<ShoppingListCreationConflict>().length, 1);
    final saved = outcomes.whereType<ShoppingList>().single;
    expect((await repository.listActiveLists()).single.name, saved.name);
  });

  test('CT-002 repositório: remove somente a lista ativa indicada', () async {
    await create(id: 'removed');
    await create(id: 'preserved');
    await seed(id: 'history', finalized: true);
    expect(await repository.removeActiveList('removed'), isTrue);
    expect((await repository.listActiveLists()).single.id, 'preserved');
    expect((await db.query('shopping_lists')).length, 2);
  });

  test(
    'F1-03: remover ausente ou repetir remoção não declara nova exclusão',
    () async {
      expect(await repository.removeActiveList('missing'), isFalse);
      await create();
      expect(await repository.removeActiveList('list-001'), isTrue);
      expect(await repository.removeActiveList('list-001'), isFalse);
    },
  );

  test('CT-046 parcial: remoção de finalizada é recusada e preserva todos os campos', () async {
    await seed(id: 'history', finalized: true);
    final before = await db.query('shopping_lists');
    await expectLater(
      repository.removeActiveList('history'),
      throwsA(isA<FinalizedShoppingListException>()),
    );
    expect(await db.query('shopping_lists'), before);
  });

  test('F1-03: remoções simultâneas confirmam uma única exclusão', () async {
    await create();
    final results = await Future.wait([
      repository.removeActiveList('list-001'),
      repository.removeActiveList('list-001'),
    ]);
    expect(results.where((removed) => removed).length, 1);
    expect(results.where((removed) => !removed).length, 1);
  });

  test(
    'F1-03: falha na inserção é propagada sem falso sucesso nem linha parcial',
    () async {
      await seed(id: 'preserved');
      await db.execute('''
      CREATE TRIGGER fail_creation BEFORE INSERT ON shopping_lists
      BEGIN SELECT RAISE(ABORT, 'simulated storage failure'); END
    ''');
      await expectLater(create(), throwsA(isA<DatabaseException>()));
      expect((await db.query('shopping_lists')).single['id'], 'preserved');
    },
  );

  test(
    'F1-03: dependência impede remoção e preserva pai/filho atomicamente',
    () async {
      await create();
      await db.execute(
        'CREATE TABLE test_child (list_id TEXT REFERENCES shopping_lists(id))',
      );
      await db.insert('test_child', {'list_id': 'list-001'});
      await expectLater(
        repository.removeActiveList('list-001'),
        throwsA(isA<DatabaseException>()),
      );
      expect((await repository.listActiveLists()).single.id, 'list-001');
      expect((await db.query('test_child')).single['list_id'], 'list-001');
    },
  );

  test('F1-03: remoção aguarda transação de finalização já iniciada e recusa histórico', () async {
    await create();
    final ready = Completer<void>();
    final release = Completer<void>();
    final finalization = db.transaction((txn) async {
      await txn.update(
        'shopping_lists',
        {
          'status': 'finalized',
          'finalized_at_utc': '2026-11-09T14:00:00.000Z',
          'finalized_registered_total_cents': 100,
        },
        where: 'id = ?',
        whereArgs: ['list-001'],
      );
      ready.complete();
      await release.future;
    });
    await ready.future;
    final result = expectLater(
      repository.removeActiveList('list-001'),
      throwsA(isA<FinalizedShoppingListException>()),
    );
    release.complete();
    await Future.wait([finalization, result]);
    expect((await db.query('shopping_lists')).single['status'], 'finalized');
  });

  test(
    'F1-03: aceita UTC legado sem fração e preserva frações válidas',
    () async {
      await seed(id: 'seconds', createdAt: '2026-11-09T12:00:00Z');
      await seed(id: 'tenths', createdAt: '2026-11-09T12:00:00.1Z');
      await seed(id: 'micros', createdAt: '2026-11-09T12:00:00.123456Z');
      final before = await db.query('shopping_lists');
      final lists = await repository.listActiveLists();
      expect(
        lists.singleWhere((list) => list.id == 'seconds').createdAt,
        DateTime.utc(2026, 11, 9, 12),
      );
      expect(
        lists.singleWhere((list) => list.id == 'tenths').createdAt,
        DateTime.utc(2026, 11, 9, 12, 0, 0, 100),
      );
      expect(
        lists.singleWhere((list) => list.id == 'micros').createdAt,
        DateTime.utc(2026, 11, 9, 12, 0, 0, 123, 456),
      );
      expect(await db.query('shopping_lists'), before);
    },
  );

  test('F1-03: texto de data inválido ou precisão excessiva não perde informação silenciosamente', () async {
    for (final value in [
      'invalidZ',
      '2026-11-09T25:00:00.000Z',
      '2026-11-09T12:00:00.1234567Z',
    ]) {
      await seed(id: value, createdAt: value);
      await expectLater(repository.listActiveLists(), throwsFormatException);
      expect(await repository.removeActiveList(value), isTrue);
    }
  });

  test(
    'F1-03: data corrompida não é normalizada silenciosamente nem excluída',
    () async {
      await seed(id: 'bad-date', createdAt: '2026-02-30T12:00:00.000Z');
      final before = await db.query('shopping_lists');
      await expectLater(repository.listActiveLists(), throwsFormatException);
      expect(await db.query('shopping_lists'), before);
    },
  );
}
