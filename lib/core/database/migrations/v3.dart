import 'package:sqflite/sqflite.dart';

Future<void> createSchemaV3(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE purchase_entries (
      id TEXT NOT NULL PRIMARY KEY CHECK (length(trim(id)) > 0),
      shopping_item_id TEXT NOT NULL REFERENCES shopping_items(id) ON DELETE CASCADE,
      quantity INTEGER,
      unit_price_cents INTEGER,
      direct_amount_cents INTEGER,
      CHECK (
        (typeof(quantity) = 'integer' AND quantity > 0 AND
         typeof(unit_price_cents) = 'integer' AND unit_price_cents >= 0 AND
         direct_amount_cents IS NULL AND
         (unit_price_cents = 0 OR quantity <= 9223372036854775807 / unit_price_cents))
        OR
        (quantity IS NULL AND unit_price_cents IS NULL AND
         typeof(direct_amount_cents) = 'integer' AND direct_amount_cents >= 0)
      )
    )
  ''');
  await db.execute(
    'CREATE INDEX purchase_entries_by_item ON purchase_entries(shopping_item_id)',
  );
}
