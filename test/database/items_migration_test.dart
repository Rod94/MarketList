import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:market_list/core/database/app_database.dart';
import 'package:market_list/core/database/migrations/v1.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late String path;
  final connections = <Database>[];
  const active = <String, Object?>{
    'id': 'active',
    'name': "Compra d'água",
    'status': 'active',
    'created_at_utc': '2026-11-09T12:00:00.000Z',
    'finalized_at_utc': null,
    'budget_cents': 0,
    'finalized_registered_total_cents': null,
    'checkout_paid_cents': null,
  };
  const finalized = <String, Object?>{
    'id': 'history',
    'name': 'Compra encerrada',
    'status': 'finalized',
    'created_at_utc': '2026-11-09T12:00:00.000001Z',
    'finalized_at_utc': '2026-11-09T14:00:00.000Z',
    'budget_cents': 50000,
    'finalized_registered_total_cents': 52780,
    'checkout_paid_cents': 53020,
  };
  const item = <String, Object?>{
    'id': 'item',
    'shopping_list_id': 'active',
    'name': 'Carne',
    'planned_quantity': null,
    'origin': 'planned',
    'sort_order': 0,
    'removed_at_utc': null,
  };

  Future<Database> open({bool legacy = false, bool raw = false}) async {
    final db = raw || legacy
        ? await databaseFactoryFfi.openDatabase(
            path,
            options: OpenDatabaseOptions(
              singleInstance: false,
              version: legacy ? 1 : null,
              onCreate: legacy ? (db, _) => createSchemaV1(db) : null,
            ),
          )
        : await AppDatabase(factory: databaseFactoryFfi, path: path).open();
    connections.add(db);
    return db;
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('market_list_v2_test_');
    path = p.join(directory.path, 'migration.db');
  });

  tearDown(() async {
    for (final db in connections) {
      if (db.isOpen) await db.close();
    }
    connections.clear();
    final root = await Directory.systemTemp.resolveSymbolicLinks();
    final target = await directory.resolveSymbolicLinks();
    if (!p.isWithin(root, target) ||
        !p.basename(target).startsWith('market_list_v2_test_')) {
      throw StateError('Recusando limpeza fora da pasta de teste.');
    }
    await directory.delete(recursive: true);
  });

  test('CT-049: v1 publicada migra preservando todos os campos e totais independentes', () async {
    var db = await open(legacy: true);
    await db.insert('shopping_lists', active);
    await db.insert('shopping_lists', finalized);
    final before = await db.query('shopping_lists', orderBy: 'id');
    final oldSchema = await db.rawQuery(
      "SELECT sql FROM sqlite_master WHERE name = 'shopping_lists'",
    );
    await db.close();
    db = await open();
    expect(await db.getVersion(), 2);
    expect(await db.query('shopping_lists', orderBy: 'id'), before);
    expect(
      await db.rawQuery(
        "SELECT sql FROM sqlite_master WHERE name = 'shopping_lists'",
      ),
      oldSchema,
    );
    expect(await db.query('shopping_items'), isEmpty);
    expect((await db.rawQuery('PRAGMA foreign_keys')).single.values.single, 1);
    expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    await db.close();
    db = await open();
    expect(await db.query('shopping_lists', orderBy: 'id'), before);
  });

  test('instalação nova e upgrade geram o mesmo esquema v2', () async {
    var db = await open();
    final freshSchema = await db.rawQuery(
      "SELECT type, name, sql FROM sqlite_master WHERE name NOT LIKE 'sqlite_%' ORDER BY name",
    );
    await db.close();
    // Segundo arquivo exclusivo desta fixture, sem apagar o primeiro banco.
    path = p.join(directory.path, 'legacy.db');
    db = await open(legacy: true);
    await db.close();
    db = await open();
    expect(
      await db.rawQuery(
        "SELECT type, name, sql FROM sqlite_master WHERE name NOT LIKE 'sqlite_%' ORDER BY name",
      ),
      freshSchema,
    );
  });

  test('CT-049: falha após CREATE TABLE reverte v2 e preserva v1 para retry', () async {
    var db = await open(legacy: true);
    await db.insert('shopping_lists', finalized);
    await db.execute(
      'CREATE INDEX shopping_items_by_list_sort_order ON shopping_lists(name)',
    );
    await db.close();
    await expectLater(open(), throwsA(isA<DatabaseException>()));
    db = await open(raw: true);
    expect(await db.getVersion(), 1);
    expect((await db.query('shopping_lists')).single, finalized);
    expect(
      await db.rawQuery('SELECT name FROM sqlite_master WHERE name = ?', [
        'shopping_items',
      ]),
      isEmpty,
    );
    await db.execute('DROP INDEX shopping_items_by_list_sort_order');
    await db.close();
    db = await open();
    expect(await db.getVersion(), 2);
    expect((await db.query('shopping_lists')).single, finalized);
  });

  test(
    'FK real rejeita órfãos e exclusão de pai elimina apenas seus dependentes',
    () async {
      final db = await open();
      await expectLater(
        db.insert('shopping_items', item),
        throwsA(isA<DatabaseException>()),
      );
      await db.insert('shopping_lists', active);
      await db.insert('shopping_lists', {...active, 'id': 'other'});
      await db.insert('shopping_items', item);
      await db.insert('shopping_items', {
        ...item,
        'id': 'other-item',
        'shopping_list_id': 'other',
      });
      await db.delete('shopping_lists', where: 'id = ?', whereArgs: ['active']);
      expect((await db.query('shopping_items')).single['id'], 'other-item');
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    },
  );

  test('CHECKs recusam quantidade inválida, posição inválida, origem e campos vazios', () async {
    final db = await open();
    await db.insert('shopping_lists', active);
    for (final changes in <Map<String, Object?>>[
      {'id': null},
      {'id': ''},
      {'name': null},
      {'name': '   '},
      {'shopping_list_id': null},
      {'origin': null},
      {'origin': 'unknown'},
      {'planned_quantity': 0},
      {'planned_quantity': -1},
      {'planned_quantity': 1.5},
      {'planned_quantity': 'invalid'},
      {'sort_order': null},
      {'sort_order': -1},
      {'sort_order': 0.5},
      {'sort_order': 'invalid'},
      {'removed_at_utc': '2026-11-10T12:00:00-03:00'},
    ]) {
      await expectLater(
        db.insert('shopping_items', {...item, ...changes}),
        throwsA(isA<DatabaseException>()),
        reason: '$changes',
      );
    }
    expect(await db.query('shopping_items'), isEmpty);
  });

  test('restrições de ID e posição por lista; quantidade ausente ou positiva é válida', () async {
    final db = await open();
    await db.insert('shopping_lists', active);
    await db.insert('shopping_items', item);
    for (final changes in [
      <String, Object?>{'sort_order': 1},
      {'id': 'other'},
    ]) {
      await expectLater(
        db.insert('shopping_items', {...item, ...changes}),
        throwsA(isA<DatabaseException>()),
      );
    }
    await db.insert('shopping_items', {
      ...item,
      'id': 'positive',
      'sort_order': 1,
      'planned_quantity': 5,
    });
    expect(
      (await db.query(
        'shopping_items',
        orderBy: 'sort_order',
      )).map((r) => r['planned_quantity']),
      [null, 5],
    );
  });
}
