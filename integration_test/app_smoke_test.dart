import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:market_list/app/app.dart';
import 'package:market_list/core/database/app_database.dart';
import 'package:market_list/core/preferences/theme_preference.dart';
import 'package:market_list/features/shopping/data/sqlite_shopping_repository.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late Directory directory;
  late Database db;
  late SqliteShoppingRepository repository;

  setUp(() async {
    root = Directory(await getDatabasesPath());
    await root.create(recursive: true);
    directory = await root.createTemp('market_list_ui_test_');
    final database = AppDatabase(path: p.join(directory.path, 'ui.db'));
    db = await database.open();
    repository = SqliteShoppingRepository(database);
  });

  tearDown(() async {
    if (db.isOpen) await db.close();
    final resolvedRoot = await root.resolveSymbolicLinks();
    final target = await directory.resolveSymbolicLinks();
    if (!p.isWithin(resolvedRoot, target) ||
        !p.basename(target).startsWith('market_list_ui_test_')) {
      throw StateError('Recusando limpeza fora da pasta de teste.');
    }
    await directory.delete(recursive: true);
  });

  Future<void> openApp(WidgetTester tester) async {
    await tester.pumpWidget(MarketListApp(repository: repository));
    await tester.pumpAndSettle();
    expect(find.text('Minhas listas'), findsOneWidget);
  }

  testWidgets('F0-06: abre aplicativo e seleciona AMOLED no dispositivo', (
    tester,
  ) async {
    await openApp(tester);
    await tester.tap(find.byTooltip('Aparência'));
    await tester.pumpAndSettle();
    expect(find.text('MarketList'), findsOneWidget);

    await tester.tap(find.byType(DropdownButton<ThemePreference>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AMOLED').last);
    await tester.pumpAndSettle();

    expect(
      Theme.of(tester.element(find.byType(Scaffold))).scaffoldBackgroundColor,
      const Color(0xFF000000),
    );
  });

  testWidgets(
    'F1-04 Android: cria com orçamento, retorna à lista e exclui após confirmação',
    (tester) async {
      await openApp(tester);
      await tester.tap(find.text('Nova lista'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('new-list-name')),
        'Compra Android',
      );
      await tester.enterText(
        find.byKey(const ValueKey('new-list-budget')),
        '250,01',
      );
      await tester.pumpAndSettle();
      final save = find.byKey(const ValueKey('save-list'));
      final context = tester.element(save);
      final height = MediaQuery.sizeOf(context).height;
      final keyboard = MediaQuery.viewInsetsOf(context).bottom;
      expect(
        tester.getBottomRight(save).dy,
        lessThanOrEqualTo(height - keyboard),
      );
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('Compra Android'), findsOneWidget);
      expect(find.text('Em andamento'), findsOneWidget);
      expect(find.text('Orçamento: R\$ 250,01'), findsOneWidget);
      expect((await repository.listActiveLists()).single.budgetCents, 25001);
      await tester.tap(find.byTooltip('Excluir lista Compra Android'));
      await tester.pumpAndSettle();
      expect(find.text('Excluir “Compra Android”?'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect((await repository.listActiveLists()).length, 1);
      await tester.tap(find.byTooltip('Excluir lista Compra Android'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();
      expect(await repository.listActiveLists(), isEmpty);
      expect(find.text('Nenhuma lista em andamento.'), findsOneWidget);
    },
  );

  testWidgets(
    'F1-04 Android: falha real de gravação preserva campos e permite retry',
    (tester) async {
      await db.execute('''
      CREATE TRIGGER fail_creation BEFORE INSERT ON shopping_lists
      BEGIN SELECT RAISE(ABORT, 'simulated storage failure'); END
    ''');
      await openApp(tester);
      await tester.tap(find.text('Nova lista'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('new-list-name')),
        'Preservar Android',
      );
      await tester.enterText(
        find.byKey(const ValueKey('new-list-budget')),
        '0',
      );
      await tester.tap(find.byKey(const ValueKey('save-list')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Seus campos foram mantidos'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('new-list-name')))
            .controller!
            .text,
        'Preservar Android',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('new-list-budget')))
            .controller!
            .text,
        '0',
      );
      expect(await repository.listActiveLists(), isEmpty);
      await db.execute('DROP TRIGGER fail_creation');
      await tester.tap(find.byKey(const ValueKey('save-list')));
      await tester.pumpAndSettle();
      expect(find.text('Preservar Android'), findsOneWidget);
      expect((await repository.listActiveLists()).length, 1);
      expect(find.byKey(const ValueKey('new-list-name')), findsNothing);
    },
  );
}
