import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'theme_preference.dart';

final class ThemePreferenceStore {
  ThemePreferenceStore({DatabaseFactory? factory, this.path})
    : _factory = factory ?? databaseFactory;

  final DatabaseFactory _factory;
  final String? path;

  Future<Database> _open() async => _factory.openDatabase(
    path ??
        p.join(await _factory.getDatabasesPath(), 'market_list_settings.db'),
    options: OpenDatabaseOptions(
      version: 1,
      singleInstance: false,
      onCreate: (db, _) => db.execute(
        'CREATE TABLE appearance (id INTEGER PRIMARY KEY, theme TEXT NOT NULL)',
      ),
      onDowngrade: onDatabaseVersionChangeError,
    ),
  );

  Future<ThemePreference> read() async {
    final db = await _open();
    try {
      final rows = await db.query(
        'appearance',
        where: 'id = ?',
        whereArgs: [1],
      );
      final name = rows.firstOrNull?['theme'];
      return ThemePreference.values.firstWhere(
        (preference) => preference.name == name,
        orElse: () => ThemePreference.system,
      );
    } finally {
      await db.close();
    }
  }

  Future<void> save(ThemePreference preference) async {
    final db = await _open();
    try {
      await db.insert('appearance', {
        'id': 1,
        'theme': preference.name,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } finally {
      await db.close();
    }
  }
}
