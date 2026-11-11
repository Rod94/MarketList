import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:market_list/core/database/app_database.dart';
import 'package:market_list/core/database/migrations/v1.dart';
import 'package:market_list/core/database/migrations/v2.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late String path;
  final connections = <Database>[];
  const list = <String, Object?>{
    'id': 'list',
    'name': 'Compra antiga',
    'status': 'finalized',
    'created_at_utc': '2026-11-09T12:00:00.000Z',
    'finalized_at_utc': '2026-11-09T14:00:00.000Z',
    'budget_cents': 50000,
    'finalized_registered_total_cents': 52780,
    'checkout_paid_cents': 53020,
  };
  const item = <String, Object?>{
    'id': 'item',
    'shopping_list_id': 'list',
    'name': 'Sabonete',
    'planned_quantity': null,
    'origin': 'planned',
    'sort_order': 0,
    'removed_at_utc': '2026-11-09T13:00:00Z',
  };
  Future<Database> open({bool legacy = false, bool raw = false}) async {
    final db = legacy || raw
        ? await databaseFactoryFfi.openDatabase(
            path,
            options: OpenDatabaseOptions(
              singleInstance: false,
              version: legacy ? 2 : null,
              onCreate: legacy
                  ? (db, _) async {
                      await createSchemaV1(db);
                      await createSchemaV2(db);
                    }
                  : null,
            ),
          )
        : await AppDatabase(factory: databaseFactoryFfi, path: path).open();
    connections.add(db);
    return db;
  }

  Future<void> seed(Database db) async {
    await db.insert('shopping_lists', list);
    await db.insert('shopping_items', item);
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('market_list_v3_test_');
    path = p.join(directory.path, 'v3.db');
  });
  tearDown(() async {
    for (final db in connections) {
      if (db.isOpen) await db.close();
    }
    connections.clear();
    final root = await Directory.systemTemp.resolveSymbolicLinks();
    final target = await directory.resolveSymbolicLinks();
    if (!p.isWithin(root, target) ||
        !p.basename(target).startsWith('market_list_v3_test_')) {
      throw StateError('Recusando limpeza fora da pasta de teste.');
    }
    await directory.delete(recursive: true);
  });
  test('CT-049: v2 publicada migra preservando listas/itens/remoção e caixa separado', () async {
    var db = await open(legacy: true);
    await seed(db);
    await db.close();
    db = await open();
    expect(await db.getVersion(), 3);
    expect((await db.query('shopping_lists')).single, list);
    expect((await db.query('shopping_items')).single, item);
    expect(await db.query('purchase_entries'), isEmpty);
    expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    await db.close();
    db = await open();
    expect((await db.query('shopping_items')).single, item);
  });
  test(
    'CT-049: falha de v3 reverte DDL/versão, preserva v2 e permite retry',
    () async {
      var db = await open(legacy: true);
      await seed(db);
      await db.execute(
        'CREATE INDEX purchase_entries_by_item ON shopping_items(name)',
      );
      await db.close();
      await expectLater(open(), throwsA(isA<DatabaseException>()));
      db = await open(raw: true);
      expect(await db.getVersion(), 2);
      expect((await db.query('shopping_lists')).single, list);
      expect((await db.query('shopping_items')).single, item);
      expect(
        await db.rawQuery('SELECT name FROM sqlite_master WHERE name = ?', [
          'purchase_entries',
        ]),
        isEmpty,
      );
      await db.execute('DROP INDEX purchase_entries_by_item');
      await db.close();
      db = await open();
      expect(await db.getVersion(), 3);
      expect((await db.query('shopping_lists')).single, list);
    },
  );
  test(
    'F7-02 abre cópia v2 restaurada e migra sem alterar o arquivo de origem',
    () async {
      var db = await open(legacy: true);
      await seed(db);
      await db.close();
      final original = File(path);
      final originalBytes = await original.readAsBytes();
      path = p.join(directory.path, 'restored-v2.db');
      await original.copy(path);
      db = await open();
      expect(await db.getVersion(), AppDatabase.schemaVersion);
      expect((await db.query('shopping_lists')).single, list);
      expect((await db.query('shopping_items')).single, item);
      expect(await db.rawQuery('PRAGMA integrity_check'), [
        {'integrity_check': 'ok'},
      ]);
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      expect(await original.readAsBytes(), originalBytes);
    },
  );

  test('instalação nova e upgrade v2 produzem esquema idêntico', () async {
    var db = await open();
    const sql =
        "SELECT type, name, sql FROM sqlite_master WHERE name NOT LIKE 'sqlite_%' ORDER BY name";
    final fresh = await db.rawQuery(sql);
    await db.close();
    path = p.join(directory.path, 'legacy.db');
    db = await open(legacy: true);
    await db.close();
    db = await open();
    expect(await db.rawQuery(sql), fresh);
  });
  test('CHECKs impõem modos exclusivos/tipos/valores e produto representável no SQL', () async {
    final db = await open();
    await seed(db);
    final base = <String, Object?>{'id': 'entry', 'shopping_item_id': 'item'};
    for (final values in <Map<String, Object?>>[
      {},
      {'quantity': 1},
      {'unit_price_cents': 100},
      {'quantity': 1, 'direct_amount_cents': 100},
      {'quantity': 1, 'unit_price_cents': 100, 'direct_amount_cents': 100},
      {'quantity': 0, 'unit_price_cents': 100},
      {'quantity': -1, 'unit_price_cents': 100},
      {'quantity': 1.5, 'unit_price_cents': 100},
      {'quantity': 1, 'unit_price_cents': -1},
      {'direct_amount_cents': -1},
      {'direct_amount_cents': 1.5},
      {'direct_amount_cents': 'invalid'},
      {'quantity': 2, 'unit_price_cents': 9223372036854775807},
    ]) {
      await expectLater(
        db.insert('purchase_entries', {...base, ...values}),
        throwsA(isA<DatabaseException>()),
        reason: '$values',
      );
    }
    await db.insert('purchase_entries', {
      ...base,
      'quantity': 9223372036854775807,
      'unit_price_cents': 0,
    });
    await db.insert('purchase_entries', {
      ...base,
      'id': 'free-direct',
      'direct_amount_cents': 0,
    });
    expect((await db.query('purchase_entries')).length, 2);
  });
  test('FK, ID obrigatório e unicidade são reais; cascade acompanha exclusão física', () async {
    final db = await open();
    await seed(db);
    final row = <String, Object?>{
      'id': 'entry',
      'shopping_item_id': 'item',
      'direct_amount_cents': 1,
    };
    for (final changes in <Map<String, Object?>>[
      {'id': null},
      {'id': ' '},
      {'shopping_item_id': null},
      {'shopping_item_id': 'missing'},
    ]) {
      await expectLater(
        db.insert('purchase_entries', {...row, ...changes}),
        throwsA(isA<DatabaseException>()),
      );
    }
    await db.insert('purchase_entries', row);
    await expectLater(
      db.insert('purchase_entries', row),
      throwsA(isA<DatabaseException>()),
    );
    await db.delete('shopping_items', where: 'id = ?', whereArgs: ['item']);
    expect(await db.query('purchase_entries'), isEmpty);
  });
}
