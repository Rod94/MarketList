import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'migrations/v1.dart';
import 'migrations/v2.dart';

final class AppDatabase {
  AppDatabase({DatabaseFactory? factory, this.path})
    : _factory = factory ?? databaseFactory;

  static const schemaVersion = 2;
  static const fileName = 'market_list.db';

  final DatabaseFactory _factory;
  final String? path;

  Future<Database> open() async {
    final databasePath =
        path ?? p.join(await _factory.getDatabasesPath(), fileName);

    return _factory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        singleInstance: true,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        // sqflite já executa onCreate em uma transação, incluindo a versão.
        onCreate: (db, _) async {
          await createSchemaV1(db);
          await createSchemaV2(db);
        },
        onUpgrade: (db, oldVersion, _) async {
          if (oldVersion < 2) await createSchemaV2(db);
        },
        onDowngrade: onDatabaseVersionChangeError,
      ),
    );
  }
}
