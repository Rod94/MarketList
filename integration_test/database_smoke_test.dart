import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:market_list/core/database/app_database.dart';
import 'package:market_list/core/database/migrations/v1.dart';
import 'package:market_list/features/shopping/data/sqlite_shopping_repository.dart';
import 'package:market_list/features/shopping/domain/models/shopping_item.dart';
import 'package:market_list/features/shopping/domain/shopping_repository.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late Directory directory;
  late String path;
  late AppDatabase appDatabase;
  final connections = <Database>[];

  Future<Database> openApp() async {
    final db = await appDatabase.open();
    connections.add(db);
    return db;
  }

  Future<Database> openRaw({int? version, OnDatabaseCreateFn? onCreate}) async {
    final db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: version,
        onCreate: onCreate,
        singleInstance: false,
      ),
    );
    connections.add(db);
    return db;
  }

  setUp(() async {
    root = Directory(await getDatabasesPath());
    await root.create(recursive: true);
    directory = await root.createTemp('market_list_db_test_');
    path = p.join(directory.path, 'fixture.db');
    appDatabase = AppDatabase(path: path);
  });

  tearDown(() async {
    for (final db in connections) {
      if (db.isOpen) await db.close();
    }
    connections.clear();
    final resolvedRoot = await root.resolveSymbolicLinks();
    final target = await directory.resolveSymbolicLinks();
    if (!p.isWithin(resolvedRoot, target) ||
        !p.basename(target).startsWith('market_list_db_test_')) {
      throw StateError('Recusando limpeza fora da pasta de teste.');
    }
    await directory.delete(recursive: true);
  });

  testWidgets('F1-02 Android: cria, impõe foreign_keys e preserva ao reabrir', (
    tester,
  ) async {
    final results = await Future.wait([openApp(), openApp()]);
    expect(identical(results[0], results[1]), isTrue);
    var db = results.first;
    expect(await db.getVersion(), AppDatabase.schemaVersion);
    expect((await db.rawQuery('PRAGMA foreign_keys')).single.values.single, 1);
    await db.execute('''
      CREATE TABLE test_children (
        list_id TEXT NOT NULL REFERENCES shopping_lists(id)
      )
    ''');
    await expectLater(
      db.insert('test_children', {'list_id': 'missing'}),
      throwsA(isA<DatabaseException>()),
    );
    final expected = <String, Object?>{
      'id': 'native-list',
      'name': "Compra d'água",
      'status': 'finalized',
      'created_at_utc': '2026-11-09T12:00:00.000Z',
      'finalized_at_utc': '2026-11-09T14:00:00.000Z',
      'budget_cents': 50000,
      'finalized_registered_total_cents': 52780,
      'checkout_paid_cents': 53020,
    };
    await db.insert('shopping_lists', expected);
    await db.close();

    db = await openApp();
    expect(await db.getVersion(), AppDatabase.schemaVersion);
    expect((await db.query('shopping_lists')).single, expected);
    expect((await db.rawQuery('PRAGMA foreign_keys')).single.values.single, 1);
    await db.insert('test_children', {'list_id': 'native-list'});
  });

  testWidgets('F1-02 Android: falha inicial reverte esquema e preserva dados', (
    tester,
  ) async {
    var db = await openRaw();
    await db.execute('CREATE TABLE preserved (value TEXT NOT NULL)');
    await db.insert('preserved', {'value': 'não apagar'});
    await db.execute('''
      CREATE INDEX shopping_lists_by_status_created_at ON preserved(value)
    ''');
    await db.close();

    await expectLater(appDatabase.open(), throwsA(isA<DatabaseException>()));
    db = await openRaw();
    expect(await db.getVersion(), 0);
    expect((await db.query('preserved')).single['value'], 'não apagar');
    expect(
      await db.rawQuery('SELECT name FROM sqlite_master WHERE name = ?', [
        'shopping_lists',
      ]),
      isEmpty,
    );
    await db.execute('DROP INDEX shopping_lists_by_status_created_at');
    await db.close();

    db = await openApp();
    expect(await db.getVersion(), AppDatabase.schemaVersion);
    expect((await db.query('preserved')).single['value'], 'não apagar');
  });

  testWidgets('F1-02 Android: downgrade não apaga banco de versão futura', (
    tester,
  ) async {
    var db = await openRaw(
      version: AppDatabase.schemaVersion + 1,
      onCreate: (db, _) async {
        await db.execute('CREATE TABLE future_data (value TEXT NOT NULL)');
      },
    );
    await db.insert('future_data', {'value': 'versão futura'});
    await db.close();

    await expectLater(appDatabase.open(), throwsArgumentError);
    db = await openRaw();
    expect(await db.getVersion(), AppDatabase.schemaVersion + 1);
    expect((await db.query('future_data')).single['value'], 'versão futura');
  });

  testWidgets(
    'F1-03 Android: cria sem duplicar, reabre, lista e remove ativa',
    (tester) async {
      var db = await openApp();
      final now = DateTime.utc(2026, 11, 9, 12, 0, 0, 0, 1);
      final repository = SqliteShoppingRepository(appDatabase, now: () => now);
      final id = repository.newListId();
      const name = "Compra d'água";
      final results = await Future.wait([
        repository.createList(id: id, name: name, budgetCents: 10000),
        repository.createList(id: id, name: name, budgetCents: 10000),
      ]);
      expect(results.map((list) => list.id).toSet(), {id});
      expect((await db.query('shopping_lists')).length, 1);
      await db.close();

      db = await openApp();
      final reopened = SqliteShoppingRepository(appDatabase);
      final restored = (await reopened.listActiveLists()).single;
      expect(restored.id, id);
      expect(restored.name, name);
      expect(restored.createdAt, now);
      expect(restored.budgetCents, 10000);
      expect(await reopened.removeActiveList(id), isTrue);
      expect(await reopened.removeActiveList(id), isFalse);
      expect(await reopened.listActiveLists(), isEmpty);
    },
  );

  testWidgets(
    'F1-03 Android: finalizada não aparece como ativa nem pode ser alterada',
    (tester) async {
      final db = await openApp();
      await db.insert('shopping_lists', {
        'id': 'history',
        'name': 'Compra finalizada',
        'status': 'finalized',
        'created_at_utc': '2026-11-09T12:00:00.000Z',
        'finalized_at_utc': '2026-11-09T14:00:00.000Z',
        'budget_cents': 50000,
        'finalized_registered_total_cents': 52780,
        'checkout_paid_cents': 53020,
      });
      final before = await db.query('shopping_lists');
      final repository = SqliteShoppingRepository(appDatabase);
      expect(await repository.listActiveLists(), isEmpty);
      await expectLater(
        repository.createList(id: 'history', name: 'Outra compra'),
        throwsA(isA<FinalizedShoppingListException>()),
      );
      await expectLater(
        repository.removeActiveList('history'),
        throwsA(isA<FinalizedShoppingListException>()),
      );
      expect(await db.query('shopping_lists'), before);
    },
  );

  testWidgets(
    'F2-02 Android: migra v1 publicada sem alterar listas históricas',
    (tester) async {
      var db = await openRaw(
        version: 1,
        onCreate: (db, _) => createSchemaV1(db),
      );
      final expected = <String, Object?>{
        'id': 'legacy',
        'name': 'Compra anterior',
        'status': 'finalized',
        'created_at_utc': '2026-11-09T12:00:00.000Z',
        'finalized_at_utc': '2026-11-09T14:00:00.000Z',
        'budget_cents': 50000,
        'finalized_registered_total_cents': 52780,
        'checkout_paid_cents': 53020,
      };
      await db.insert('shopping_lists', expected);
      await db.close();
      db = await openApp();
      expect(await db.getVersion(), 2);
      expect((await db.query('shopping_lists')).single, expected);
      expect(await db.query('shopping_items'), isEmpty);
      await db.close();
      db = await openApp();
      expect((await db.query('shopping_lists')).single, expected);
    },
  );

  testWidgets('F2-02 Android: falha de upgrade reverte v2 e permite retry', (
    tester,
  ) async {
    var db = await openRaw(version: 1, onCreate: (db, _) => createSchemaV1(db));
    await db.insert('shopping_lists', {
      'id': 'legacy',
      'name': 'Preservar',
      'status': 'active',
      'created_at_utc': '2026-11-09T12:00:00.000Z',
    });
    final before = await db.query('shopping_lists');
    await db.execute(
      'CREATE INDEX shopping_items_by_list_sort_order ON shopping_lists(name)',
    );
    await db.close();
    await expectLater(appDatabase.open(), throwsA(isA<DatabaseException>()));
    db = await openRaw();
    expect(await db.getVersion(), 1);
    expect(await db.query('shopping_lists'), before);
    expect(
      await db.rawQuery('SELECT name FROM sqlite_master WHERE name = ?', [
        'shopping_items',
      ]),
      isEmpty,
    );
    await db.execute('DROP INDEX shopping_items_by_list_sort_order');
    await db.close();
    db = await openApp();
    expect(await db.getVersion(), 2);
    expect(await db.query('shopping_lists'), before);
  });

  testWidgets(
    'F2-02 Android: CRUD de itens, null, concorrência, reabertura e cascade',
    (tester) async {
      var db = await openApp();
      final now = DateTime.utc(2026, 11, 10, 12);
      final repository = SqliteShoppingRepository(appDatabase, now: () => now);
      await repository.createList(id: 'list', name: 'Compra');
      Future<ShoppingItem> create() => repository.createItem(
        id: 'item',
        shoppingListId: 'list',
        name: "Carne d'água",
        origin: ShoppingItemOrigin.planned,
      );
      await Future.wait([create(), create()]);
      expect((await db.query('shopping_items')).length, 1);
      expect(
        (await repository.listItems('list')).single.plannedQuantity,
        isNull,
      );
      for (final quantity in <int?>[1, 5, null]) {
        await repository.updateItem(
          id: 'item',
          shoppingListId: 'list',
          name: 'Carne bovina',
          plannedQuantity: quantity,
        );
        expect(
          (await repository.listItems('list')).single.plannedQuantity,
          quantity,
        );
      }
      await db.close();
      db = await openApp();
      expect((await repository.listItems('list')).single.name, 'Carne bovina');
      expect(
        await repository.removeItem(id: 'item', shoppingListId: 'list'),
        isTrue,
      );
      expect(
        await repository.removeItem(id: 'item', shoppingListId: 'list'),
        isFalse,
      );
      expect((await repository.listItems('list')).single.removedAt, now);
      expect(await repository.removeActiveList('list'), isTrue);
      expect(await db.query('shopping_items'), isEmpty);
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    },
  );

  testWidgets(
    'F2-02 Android: falha SQL preserva item e finalizada bloqueia gravações',
    (tester) async {
      final db = await openApp();
      final repository = SqliteShoppingRepository(appDatabase);
      await repository.createList(id: 'list', name: 'Compra');
      Future<ShoppingItem> create({String id = 'item'}) =>
          repository.createItem(
            id: id,
            shoppingListId: 'list',
            name: 'Carne',
            origin: ShoppingItemOrigin.planned,
          );
      await create();
      final before = await db.query('shopping_items');
      await db.execute(
        '''CREATE TRIGGER fail_item BEFORE UPDATE ON shopping_items
      BEGIN SELECT RAISE(ABORT, 'simulated storage failure'); END''',
      );
      await expectLater(
        repository.updateItem(
          id: 'item',
          shoppingListId: 'list',
          name: 'Outro',
          plannedQuantity: 1,
        ),
        throwsA(isA<DatabaseException>()),
      );
      await expectLater(
        repository.removeItem(id: 'item', shoppingListId: 'list'),
        throwsA(isA<DatabaseException>()),
      );
      expect(await db.query('shopping_items'), before);
      await db.execute('DROP TRIGGER fail_item');
      await db.update('shopping_lists', {
        'status': 'finalized',
        'finalized_at_utc': DateTime.now().toUtc().toIso8601String(),
        'finalized_registered_total_cents': 0,
      });
      await expectLater(
        create(),
        throwsA(isA<FinalizedShoppingListException>()),
      );
      await expectLater(
        create(id: 'new'),
        throwsA(isA<FinalizedShoppingListException>()),
      );
      await expectLater(
        repository.updateItem(
          id: 'item',
          shoppingListId: 'list',
          name: 'Outro',
          plannedQuantity: 1,
        ),
        throwsA(isA<FinalizedShoppingListException>()),
      );
      await expectLater(
        repository.removeItem(id: 'item', shoppingListId: 'list'),
        throwsA(isA<FinalizedShoppingListException>()),
      );
      expect(await db.query('shopping_items'), before);
    },
  );

  testWidgets(
    'F1-03 Android: falhas de gravação não retornam sucesso nem perdem dados',
    (tester) async {
      final db = await openApp();
      final repository = SqliteShoppingRepository(appDatabase);
      await repository.createList(id: 'preserved', name: 'Preservar');
      await db.execute('''
      CREATE TRIGGER fail_creation BEFORE INSERT ON shopping_lists
      BEGIN SELECT RAISE(ABORT, 'simulated storage failure'); END
    ''');
      await expectLater(
        repository.createList(id: 'new', name: 'Tentar salvar'),
        throwsA(isA<DatabaseException>()),
      );
      expect((await repository.listActiveLists()).single.id, 'preserved');
      await db.execute('DROP TRIGGER fail_creation');
      await repository.createList(id: 'new', name: 'Tentar salvar');
      await db.execute(
        'CREATE TABLE test_child (list_id TEXT REFERENCES shopping_lists(id))',
      );
      await db.insert('test_child', {'list_id': 'preserved'});
      await expectLater(
        repository.removeActiveList('preserved'),
        throwsA(isA<DatabaseException>()),
      );
      expect((await repository.listActiveLists()).length, 2);
      expect((await db.query('test_child')).single['list_id'], 'preserved');
    },
  );
}
