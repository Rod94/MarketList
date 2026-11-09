import 'package:sqflite/sqflite.dart';

Future<void> createSchemaV1(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE shopping_lists (
      id TEXT NOT NULL PRIMARY KEY CHECK (length(trim(id)) > 0),
      name TEXT NOT NULL CHECK (length(trim(name)) > 0),
      status TEXT NOT NULL CHECK (status IN ('active', 'finalized')),
      created_at_utc TEXT NOT NULL CHECK (substr(created_at_utc, -1) = 'Z'),
      finalized_at_utc TEXT CHECK (
        finalized_at_utc IS NULL OR substr(finalized_at_utc, -1) = 'Z'
      ),
      budget_cents INTEGER CHECK (
        budget_cents IS NULL OR
        (typeof(budget_cents) = 'integer' AND budget_cents >= 0)
      ),
      finalized_registered_total_cents INTEGER CHECK (
        finalized_registered_total_cents IS NULL OR
        (typeof(finalized_registered_total_cents) = 'integer' AND
         finalized_registered_total_cents >= 0)
      ),
      checkout_paid_cents INTEGER CHECK (
        checkout_paid_cents IS NULL OR
        (typeof(checkout_paid_cents) = 'integer' AND checkout_paid_cents >= 0)
      ),
      CHECK (
        (status = 'active' AND finalized_at_utc IS NULL AND
         finalized_registered_total_cents IS NULL AND checkout_paid_cents IS NULL)
        OR
        (status = 'finalized' AND finalized_at_utc IS NOT NULL AND
         finalized_registered_total_cents IS NOT NULL)
      )
    )
  ''');
  await db.execute('''
    CREATE INDEX shopping_lists_by_status_created_at
    ON shopping_lists(status, created_at_utc)
  ''');
}
