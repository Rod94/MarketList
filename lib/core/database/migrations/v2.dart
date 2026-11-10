import 'package:sqflite/sqflite.dart';

Future<void> createSchemaV2(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE shopping_items (
      id TEXT NOT NULL PRIMARY KEY CHECK (length(trim(id)) > 0),
      shopping_list_id TEXT NOT NULL REFERENCES shopping_lists(id) ON DELETE CASCADE,
      name TEXT NOT NULL CHECK (length(trim(name)) > 0),
      planned_quantity INTEGER CHECK (
        planned_quantity IS NULL OR
        (typeof(planned_quantity) = 'integer' AND planned_quantity > 0)
      ),
      origin TEXT NOT NULL CHECK (origin IN ('planned', 'at_store')),
      sort_order INTEGER NOT NULL CHECK (
        typeof(sort_order) = 'integer' AND sort_order >= 0
      ),
      removed_at_utc TEXT CHECK (
        removed_at_utc IS NULL OR substr(removed_at_utc, -1) = 'Z'
      )
    )
  ''');
  await db.execute('''
    CREATE UNIQUE INDEX shopping_items_by_list_sort_order
    ON shopping_items(shopping_list_id, sort_order)
  ''');
}
