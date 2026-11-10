import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:market_list/core/database/app_database.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory directory;
  late String databasePath;
  late AppDatabase appDatabase;
  final connections = <Database>[];

  Future<Database> openApp() async {
    final db = await appDatabase.open();
    connections.add(db);
    return db;
  }

  Future<Database> openRaw({int? version, OnDatabaseCreateFn? onCreate}) async {
    final db = await databaseFactoryFfi.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: version,
        onCreate: onCreate,
        singleInstance: false,
      ),
    );
    connections.add(db);
    return db;
  }

  Map<String, Object?> activeList({String id = 'list-001'}) => {
    'id': id,
    'name': 'Compra da semana',
    'status': 'active',
    'created_at_utc': '2026-11-09T12:00:00.000Z',
  };

  Map<String, Object?> finalizedList() => {
    ...activeList(),
    'status': 'finalized',
    'finalized_at_utc': '2026-11-09T14:00:00.000Z',
    'finalized_registered_total_cents': 52780,
  };

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('market_list_db_test_');
    databasePath = p.join(directory.path, 'shopping.db');
    appDatabase = AppDatabase(factory: databaseFactoryFfi, path: databasePath);
  });

  tearDown(() async {
    for (final db in connections) {
      if (db.isOpen) await db.close();
    }
    connections.clear();

    final tempRoot = await Directory.systemTemp.resolveSymbolicLinks();
    final target = await directory.resolveSymbolicLinks();
    if (!p.isWithin(tempRoot, target) ||
        !p.basename(target).startsWith('market_list_db_test_')) {
      throw StateError('Recusando limpeza fora da pasta temporária do teste.');
    }
    await directory.delete(recursive: true);
  });

  test('F1/F2/F3: cria versão atual com listas, itens e entradas', () async {
    final db = await openApp();

    expect(await db.getVersion(), AppDatabase.schemaVersion);
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = ? AND name NOT LIKE 'sqlite_%'",
      ['table'],
    );
    expect(tables.map((row) => row['name']), [
      'shopping_lists',
      'shopping_items',
      'purchase_entries',
    ]);
    final columns = await db.rawQuery('PRAGMA table_info(shopping_lists)');
    expect(columns.map((row) => row['name']), [
      'id',
      'name',
      'status',
      'created_at_utc',
      'finalized_at_utc',
      'budget_cents',
      'finalized_registered_total_cents',
      'checkout_paid_cents',
    ]);
    final indexes = await db.rawQuery('PRAGMA index_list(shopping_lists)');
    expect(
      indexes.map((row) => row['name']),
      contains('shopping_lists_by_status_created_at'),
    );
  });

  test(
    'F1-02: chaves estrangeiras são habilitadas e realmente aplicadas',
    () async {
      final db = await openApp();
      expect(
        (await db.rawQuery('PRAGMA foreign_keys')).single.values.single,
        1,
      );
      await db.execute('''
      CREATE TABLE test_children (
        id TEXT PRIMARY KEY,
        list_id TEXT NOT NULL REFERENCES shopping_lists(id)
      )
    ''');

      await expectLater(
        db.insert('test_children', {'id': 'child', 'list_id': 'missing'}),
        throwsA(isA<DatabaseException>()),
      );
      await db.insert('shopping_lists', activeList());
      await db.insert('test_children', {'id': 'child', 'list_id': 'list-001'});
      await expectLater(
        db.delete('shopping_lists', where: 'id = ?', whereArgs: ['list-001']),
        throwsA(isA<DatabaseException>()),
      );
    },
  );

  test(
    'F1-02 / CT-049 parcial: reabrir preserva dados e reativa foreign_keys',
    () async {
      var db = await openApp();
      final expected = {
        ...finalizedList(),
        'budget_cents': 50000,
        'checkout_paid_cents': 53020,
      };
      await db.insert('shopping_lists', expected);
      await db.close();

      db = await openApp();
      expect(await db.getVersion(), AppDatabase.schemaVersion);
      expect((await db.query('shopping_lists')).single, expected);
      expect(
        (await db.rawQuery('PRAGMA foreign_keys')).single.values.single,
        1,
      );
    },
  );

  test('F1-02: aberturas simultâneas compartilham a conexão', () async {
    final results = await Future.wait([openApp(), openApp(), openApp()]);
    expect(identical(results[0], results[1]), isTrue);
    expect(identical(results[1], results[2]), isTrue);
    expect(await results.first.getVersion(), AppDatabase.schemaVersion);
  });

  test('F1-02: ID é obrigatório, não vazio e único', () async {
    final db = await openApp();
    await db.insert('shopping_lists', activeList());
    for (final id in [null, '', '   ', 'list-001']) {
      await expectLater(
        db.insert('shopping_lists', {...activeList(), 'id': id}),
        throwsA(isA<DatabaseException>()),
      );
    }
    expect((await db.query('shopping_lists')).length, 1);
  });

  test(
    'F1-02: nome e criação são obrigatórios; nome só com espaços é inválido',
    () async {
      final db = await openApp();
      for (final changes in <Map<String, Object?>>[
        {'name': null},
        {'name': ''},
        {'name': '   '},
        {'created_at_utc': null},
      ]) {
        await expectLater(
          db.insert('shopping_lists', {...activeList(), ...changes}),
          throwsA(isA<DatabaseException>()),
        );
      }
    },
  );

  test('F1-02: aceita somente estados conhecidos', () async {
    final db = await openApp();
    for (final status in [null, 'unknown']) {
      await expectLater(
        db.insert('shopping_lists', {...activeList(), 'status': status}),
        throwsA(isA<DatabaseException>()),
      );
    }
  });

  test('F1-02: datas armazenadas exigem indicação UTC', () async {
    final db = await openApp();
    for (final changes in <Map<String, Object?>>[
      {'created_at_utc': '2026-11-09T09:00:00.000-03:00'},
      {'created_at_utc': '2026-11-09T12:00:00.000'},
      {'finalized_at_utc': '2026-11-09T14:00:00.000-03:00'},
    ]) {
      await expectLater(
        db.insert('shopping_lists', {...finalizedList(), ...changes}),
        throwsA(isA<DatabaseException>()),
      );
    }
  });

  test(
    'F1-02: centavos negativos ou fracionários não são armazenados',
    () async {
      final db = await openApp();
      for (final column in [
        'budget_cents',
        'finalized_registered_total_cents',
        'checkout_paid_cents',
      ]) {
        for (final value in <Object>[-1, 1.5, 'inválido']) {
          await expectLater(
            db.insert('shopping_lists', {...finalizedList(), column: value}),
            throwsA(isA<DatabaseException>()),
          );
        }
      }
    },
  );

  test('F1-02: ativa não pode armazenar campos finais', () async {
    final db = await openApp();
    for (final changes in <Map<String, Object?>>[
      {'finalized_at_utc': '2026-11-09T14:00:00.000Z'},
      {'finalized_registered_total_cents': 0},
      {'checkout_paid_cents': 0},
    ]) {
      await expectLater(
        db.insert('shopping_lists', {...activeList(), ...changes}),
        throwsA(isA<DatabaseException>()),
      );
    }
  });

  test('F1-02: finalizada exige data e total calculado', () async {
    final db = await openApp();
    for (final column in [
      'finalized_at_utc',
      'finalized_registered_total_cents',
    ]) {
      await expectLater(
        db.insert('shopping_lists', {...finalizedList(), column: null}),
        throwsA(isA<DatabaseException>()),
      );
    }
  });

  test(
    'F1-02: zero não vira null e orçamento/caixa não são impostos',
    () async {
      final db = await openApp();
      await db.insert('shopping_lists', {...activeList(), 'budget_cents': 0});
      await db.insert('shopping_lists', {
        ...finalizedList(),
        'id': 'finalized',
        'finalized_registered_total_cents': 0,
        'checkout_paid_cents': 0,
      });
      final active = (await db.query(
        'shopping_lists',
        where: 'id = ?',
        whereArgs: ['list-001'],
      )).single;
      expect(active['budget_cents'], 0);
      expect(active['checkout_paid_cents'], isNull);
      final finalized = (await db.query(
        'shopping_lists',
        where: 'id = ?',
        whereArgs: ['finalized'],
      )).single;
      expect(finalized['budget_cents'], isNull);
      expect(finalized['checkout_paid_cents'], 0);
      expect(finalized['finalized_registered_total_cents'], 0);
    },
  );

  test('F1-02: nome com aspas é dado, sem alterar o esquema', () async {
    final db = await openApp();
    const name = "Compra d'água'); DROP TABLE shopping_lists; --";
    await db.insert('shopping_lists', {...activeList(), 'name': name});

    final rows = await db.query(
      'shopping_lists',
      where: 'name = ?',
      whereArgs: [name],
    );
    expect(rows.single['name'], name);
  });

  test(
    'F1-02: falha de migração reverte DDL e permite tentar de novo',
    () async {
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
    },
  );

  test(
    'F1-02 / CT-049 parcial: recusa downgrade sem apagar dados mais novos',
    () async {
      var db = await openRaw(
        version: AppDatabase.schemaVersion + 1,
        onCreate: (db, _) async {
          await db.execute('CREATE TABLE future_data (value TEXT NOT NULL)');
        },
      );
      await db.insert('future_data', {'value': 'preservar versão futura'});
      await db.close();

      await expectLater(appDatabase.open(), throwsArgumentError);
      db = await openRaw();
      expect(await db.getVersion(), AppDatabase.schemaVersion + 1);
      expect(
        (await db.query('future_data')).single['value'],
        'preservar versão futura',
      );
    },
  );
}
