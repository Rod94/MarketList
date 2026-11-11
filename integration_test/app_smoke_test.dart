import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:market_list/app/app.dart';
import 'package:market_list/core/database/app_database.dart';
import 'package:market_list/core/preferences/theme_preference.dart';
import 'package:market_list/core/preferences/theme_preference_store.dart';
import 'package:market_list/features/shopping/data/sqlite_shopping_repository.dart';
import 'package:market_list/features/shopping/domain/models/shopping_item.dart';
import 'package:market_list/features/shopping/domain/models/purchase_entry.dart';
import 'package:market_list/features/shopping/presentation/screens/shopping_screen.dart';
import 'package:market_list/features/shopping/presentation/view_models/shopping_items_view_model.dart';
import 'package:provider/provider.dart';
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

  testWidgets(
    'F6-01 Android lista histórico por conclusão e recupera após reabrir',
    (tester) async {
      var clock = DateTime.utc(2026, 10, 1, 15);
      final database = AppDatabase(path: p.join(directory.path, 'ui.db'));
      repository = SqliteShoppingRepository(database, now: () => clock);
      for (final (id, name, amount) in [
        ('old', 'Compra antiga', 1000),
        ('recent', 'Compra recente', 2000),
      ]) {
        await repository.createList(id: id, name: name);
        await repository.createItemWithPurchase(
          id: 'item-$id',
          shoppingListId: id,
          name: 'Arroz',
          entry: PurchaseEntry(
            id: 'price-$id',
            shoppingItemId: 'item-$id',
            directAmountCents: amount,
          ),
        );
      }
      clock = DateTime.utc(2026, 10, 2, 15);
      await repository.finalizeShoppingList(
        await repository.loadShoppingSnapshot('old'),
      );
      clock = DateTime.utc(2026, 11, 2, 15);
      await repository.finalizeShoppingList(
        await repository.loadShoppingSnapshot('recent'),
      );
      await repository.createList(id: 'active', name: 'Compra ativa');

      Future<void> inspect() async {
        await openApp(tester);
        await tester.tap(find.byTooltip('Histórico'));
        await tester.pumpAndSettle();
        expect(find.text('Compra ativa'), findsNothing);
        expect(find.text('Total registrado: R\$ 10,00'), findsOneWidget);
        expect(find.text('Total registrado: R\$ 20,00'), findsOneWidget);
        expect(find.textContaining('Finalizada em'), findsNWidgets(2));
        expect(
          tester.getTopLeft(find.text('Compra recente')).dy,
          lessThan(tester.getTopLeft(find.text('Compra antiga')).dy),
        );
      }

      await inspect();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await db.close();
      db = await database.open();
      repository = SqliteShoppingRepository(database);
      await inspect();
      expect((await db.query('shopping_lists')).length, 3);
      expect((await db.query('purchase_entries')).length, 2);
    },
  );

  testWidgets(
    'F5 Android confirma após retry e reabre a compra somente para consulta',
    (tester) async {
      const id = 'f5';
      await repository.createList(id: id, name: 'Compra F5', budgetCents: 1000);
      await repository.createItem(
        id: 'sabonete',
        shoppingListId: id,
        name: 'Sabonete',
        origin: ShoppingItemOrigin.planned,
        plannedQuantity: 5,
      );
      await repository.createItem(
        id: 'azeite',
        shoppingListId: id,
        name: 'Azeite',
        origin: ShoppingItemOrigin.planned,
      );
      await repository.createPurchaseEntry(
        shoppingListId: id,
        entry: PurchaseEntry(
          id: 'preco',
          shoppingItemId: 'sabonete',
          quantity: 3,
          unitPriceCents: 350,
        ),
      );
      await db.execute('''
      CREATE TRIGGER fail_checkout AFTER UPDATE OF status ON shopping_lists
      WHEN NEW.status = 'finalized'
      BEGIN SELECT RAISE(ABORT, 'falha simulada'); END
    ''');
      await openApp(tester);
      await tester.tap(find.text('Compra F5'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Finalizar compra'));
      await tester.pumpAndSettle();
      expect(find.text('Parcial · faltaram 2'), findsOneWidget);
      expect(find.text('Sem compra registrada'), findsOneWidget);
      expect(find.text('R\$ 0,50 acima do orçamento'), findsOneWidget);
      final paid = find.byKey(const ValueKey('checkout-paid'));
      await tester.ensureVisible(paid);
      await tester.enterText(paid, '11,50');
      await tester.pumpAndSettle();
      final confirm = find.text('Confirmar finalização');
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('O valor digitado foi mantido'),
        findsOneWidget,
      );
      expect(tester.widget<TextField>(paid).controller!.text, '11,50');
      expect((await repository.listActiveLists()).single.id, id);
      await db.execute('DROP TRIGGER fail_checkout');
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(find.text('Compra finalizada'), findsOneWidget);
      expect(find.text('Não comprado'), findsOneWidget);
      expect(find.text('Total registrado: R\$ 10,50'), findsOneWidget);
      expect(find.text('Valor cobrado no caixa: R\$ 11,50'), findsOneWidget);
      expect(find.byKey(const ValueKey('add-item')), findsNothing);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Minhas listas'), findsOneWidget);
      expect(find.text('Compra F5'), findsNothing);

      await db.close();
      final reopened = AppDatabase(path: p.join(directory.path, 'ui.db'));
      db = await reopened.open();
      final persisted = await SqliteShoppingRepository(reopened)
          .loadShoppingSnapshot(id);
      expect(persisted.list.finalizedRegisteredTotalCents, 1050);
      expect(persisted.list.checkoutPaidCents, 1150);
      expect(persisted.calculation.items.first.missingQuantity, 2);
    },
  );

  testWidgets('F4 Android: filtro, total, orçamento e desfazer', (
    tester,
  ) async {
    await repository.createList(id: 'f4', name: 'Compra F4', budgetCents: 1000);
    await repository.createItem(
      id: 'partial',
      shoppingListId: 'f4',
      name: 'Feijão',
      origin: ShoppingItemOrigin.planned,
      plannedQuantity: 5,
    );
    await repository.createPurchaseEntry(
      shoppingListId: 'f4',
      entry: PurchaseEntry(
        id: 'entry',
        shoppingItemId: 'partial',
        quantity: 3,
        unitPriceCents: 350,
      ),
    );
    await openApp(tester);
    await tester.tap(find.text('Compra F4'));
    await tester.pumpAndSettle();
    expect(find.text('R\$ 0,50 acima do orçamento'), findsOneWidget);
    await tester.tap(find.text('A comprar'));
    await tester.pumpAndSettle();
    expect(find.text('Parcial · 3 de 5'), findsOneWidget);
    expect(find.text('Total registrado: R\$ 10,50'), findsOneWidget);
    await tester.tap(find.text('Feijão'));
    await tester.pumpAndSettle();
    final remove = find.byKey(const ValueKey('remove-item'));
    await tester.ensureVisible(remove);
    await tester.tap(remove);
    await tester.pumpAndSettle();
    expect(find.text('Total registrado: R\$ 0,00'), findsOneWidget);
    await tester.tap(find.text('Desfazer'));
    await tester.pumpAndSettle();
    expect(find.text('Feijão'), findsOneWidget);
    expect(find.text('R\$ 0,50 acima do orçamento'), findsOneWidget);
    expect((await repository.loadShoppingList('f4')).totalCents, 1050);
  });

  testWidgets(
    'F3-07 Android: rollback da inclusão rápida e reabertura com preço',
    (tester) async {
      await repository.createList(id: 'quick', name: 'Compra rápida');
      await db.execute("""
      CREATE TRIGGER fail_quick BEFORE INSERT ON purchase_entries
      BEGIN SELECT RAISE(ABORT, 'simulated failure'); END
    """);
      await openApp(tester);
      await tester.tap(find.text('Compra rápida'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-item')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('item-name')), 'Leite');
      await tester.enterText(find.byKey(const ValueKey('item-quantity')), '3');
      await tester.enterText(find.byKey(const ValueKey('item-price')), '4,22');
      await tester.pumpAndSettle();
      expect(find.text('Prévia do subtotal: R\$ 12,66'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('save-item')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Seus campos foram mantidos'), findsOneWidget);
      expect(await db.query('shopping_items'), isEmpty);
      await db.execute('DROP TRIGGER fail_quick');
      await tester.tap(find.byKey(const ValueKey('save-item')));
      await tester.pumpAndSettle();
      expect(find.text('Total registrado: R\$ 12,66'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await db.close();
      final database = AppDatabase(path: p.join(directory.path, 'ui.db'));
      db = await database.open();
      repository = SqliteShoppingRepository(database);
      expect((await repository.loadShoppingList('quick')).totalCents, 1266);
    },
  );

  testWidgets(
    'F3-06 Android: painel registra dois preços, corrige e exclui sem duplicar',
    (tester) async {
      await repository.createList(id: 'market', name: 'Compra mercado');
      await repository.createItem(
        id: 'soap',
        shoppingListId: 'market',
        name: 'Sabonete',
        plannedQuantity: 5,
        origin: ShoppingItemOrigin.planned,
      );
      await openApp(tester);
      await tester.tap(find.text('Compra mercado'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sabonete'));
      await tester.pumpAndSettle();
      Future<void> register(
        String quantity,
        String price, {
        bool another = false,
      }) async {
        final action = find.text(
          another ? 'Adicionar outro preço' : 'Registrar preço',
        );
        await tester.ensureVisible(action);
        await tester.tap(action);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('purchase-quantity')),
          quantity,
        );
        await tester.enterText(
          find.byKey(const ValueKey('purchase-price')),
          price,
        );
        await tester.tap(find.byKey(const ValueKey('save-purchase')));
        await tester.pumpAndSettle();
      }

      await register('3', '3,50');
      await register('2', '4,20', another: true);
      expect(find.text('Subtotal confirmado: R\$ 18,90'), findsOneWidget);
      expect((await repository.loadShoppingList('market')).totalCents, 1890);
      final firstRow = find.ancestor(
        of: find.text('3 × R\$ 3,50'),
        matching: find.byType(ListTile),
      );
      final edit = find.descendant(
        of: firstRow,
        matching: find.byIcon(Icons.edit_outlined),
      );
      await tester.ensureVisible(edit);
      await tester.tap(edit);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('purchase-price')),
        '3,00',
      );
      await tester.tap(find.byKey(const ValueKey('save-purchase')));
      await tester.pumpAndSettle();
      expect((await db.query('purchase_entries')).length, 2);
      expect(find.text('Subtotal confirmado: R\$ 17,40'), findsOneWidget);
      final secondRow = find.ancestor(
        of: find.text('2 × R\$ 4,20'),
        matching: find.byType(ListTile),
      );
      final remove = find.descendant(
        of: secondRow,
        matching: find.byIcon(Icons.delete_outline),
      );
      await tester.ensureVisible(remove);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(find.text('Subtotal confirmado: R\$ 9,00'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('cancel-item')));
      await tester.pumpAndSettle();
      expect(find.text('Total registrado: R\$ 9,00'), findsOneWidget);
    },
  );

  testWidgets(
    'F3-06 Android: valor direto com falha SQL mantém campos e total',
    (tester) async {
      await repository.createList(id: 'market', name: 'Compra mercado');
      await repository.createItem(
        id: 'meat',
        shoppingListId: 'market',
        name: 'Carne',
        origin: ShoppingItemOrigin.planned,
      );
      await db.execute(
        '''CREATE TRIGGER fail_entry_form BEFORE INSERT ON purchase_entries
      BEGIN SELECT RAISE(ABORT, 'simulated storage failure'); END''',
      );
      await openApp(tester);
      await tester.tap(find.text('Compra mercado'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Carne'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Registrar preço'));
      await tester.tap(find.text('Registrar preço'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('purchase-price')),
        '47,82',
      );
      await tester.tap(find.byKey(const ValueKey('save-purchase')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Seus campos foram mantidos'), findsWidgets);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('purchase-price')))
            .controller!
            .text,
        '47,82',
      );
      expect(find.text('Total registrado: R\$ 0,00'), findsOneWidget);
      await db.execute('DROP TRIGGER fail_entry_form');
      await tester.tap(find.byKey(const ValueKey('save-purchase')));
      await tester.pumpAndSettle();
      expect((await repository.loadShoppingList('market')).totalCents, 4782);
      expect((await db.query('purchase_entries')).single['quantity'], isNull);
    },
  );

  testWidgets(
    'F3-05 Android: total do ViewModel só muda após commit; erro preserva prévia',
    (tester) async {
      await repository.createList(id: 'price', name: 'Compra financeira');
      final item = await repository.createItem(
        id: 'soap',
        shoppingListId: 'price',
        name: 'Sabonete',
        plannedQuantity: 5,
        origin: ShoppingItemOrigin.planned,
      );
      await repository.createPurchaseEntry(
        shoppingListId: 'price',
        entry: PurchaseEntry(
          id: 'first',
          shoppingItemId: 'soap',
          quantity: 3,
          unitPriceCents: 350,
        ),
      );
      await openApp(tester);
      await tester.tap(find.text('Compra financeira'));
      await tester.pumpAndSettle();
      final model = tester
          .element(find.byType(ShoppingScreen))
          .read<ShoppingItemsViewModel>();
      expect(model.totalCents, 1050);
      model.beginPurchase(item);
      model.setPurchaseQuantity('2');
      model.setPurchasePrice('4,20');
      expect(model.purchasePreviewCents, 840);
      expect(model.totalCents, 1050);
      await db.execute(
        '''CREATE TRIGGER fail_purchase BEFORE INSERT ON purchase_entries
      BEGIN SELECT RAISE(ABORT, 'simulated storage failure'); END''',
      );
      expect(await model.savePurchaseDraft(), isFalse);
      expect(model.totalCents, 1050);
      expect(model.purchasePrice, '4,20');
      await db.execute('DROP TRIGGER fail_purchase');
      expect(await model.savePurchaseDraft(), isTrue);
      expect(model.totalCents, 1890);
      expect((await repository.loadShoppingList('price')).totalCents, 1890);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'F2-05 Android: remoção falha sem perder campos, retry oculta e preserva registro',
    (tester) async {
      await repository.createList(id: 'remove', name: 'Remocao Android');
      for (final name in ['Carne', 'Leite', 'Removido']) {
        await repository.createItem(
          id: name,
          shoppingListId: 'remove',
          name: name,
          plannedQuantity: 5,
          origin: ShoppingItemOrigin.planned,
        );
      }
      await repository.removeItem(id: 'Removido', shoppingListId: 'remove');
      await openApp(tester);
      await tester.tap(find.text('Remocao Android'));
      await tester.pumpAndSettle();
      expect(find.text('Removido'), findsNothing);
      await tester.tap(find.text('Leite'));
      await tester.pumpAndSettle();
      await db.execute(
        '''CREATE TRIGGER fail_remove BEFORE UPDATE ON shopping_items
      BEGIN SELECT RAISE(ABORT, 'simulated storage failure'); END''',
      );
      await tester.tap(find.byKey(const ValueKey('remove-item')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Não foi possível remover'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('item-quantity')))
            .controller!
            .text,
        '5',
      );
      expect(
        (await repository.listItems('remove'))
            .firstWhere((i) => i.id == 'Leite')
            .removedAt,
        isNull,
      );
      await db.execute('DROP TRIGGER fail_remove');
      await tester.tap(find.byKey(const ValueKey('remove-item')));
      await tester.pumpAndSettle();
      expect(find.text('Leite'), findsNothing);
      expect(find.text('Carne'), findsOneWidget);
      expect((await repository.listItems('remove')).length, 3);
      expect(
        (await repository.listItems('remove'))
            .firstWhere((i) => i.id == 'Leite')
            .removedAt,
        isNotNull,
      );
      await tester.tap(find.byTooltip('Voltar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remocao Android'));
      await tester.pumpAndSettle();
      expect(find.text('Leite'), findsNothing);
      expect(find.text('Carne'), findsOneWidget);
    },
  );

  testWidgets(
    'F2-04 Android: editar produto no meio mantém posição após reabrir tela',
    (tester) async {
      await repository.createList(id: 'order', name: 'Ordem Android');
      for (final name in ['Zebra', 'Leite', 'Arroz']) {
        await repository.createItem(
          id: name,
          shoppingListId: 'order',
          name: name,
          origin: ShoppingItemOrigin.planned,
        );
      }
      await openApp(tester);
      await tester.tap(find.text('Ordem Android'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leite'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('item-name')),
        'Abacate',
      );
      await tester.tap(find.byKey(const ValueKey('save-item')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Voltar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ordem Android'));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('Zebra')).dy,
        lessThan(tester.getTopLeft(find.text('Abacate')).dy),
      );
      expect(
        tester.getTopLeft(find.text('Abacate')).dy,
        lessThan(tester.getTopLeft(find.text('Arroz')).dy),
      );
      expect((await repository.listItems('order')).map((item) => item.id), [
        'Zebra',
        'Leite',
        'Arroz',
      ]);
    },
  );

  testWidgets('F2-03 Android: inclui e edita produto com quantidade opcional', (
    tester,
  ) async {
    await repository.createList(id: 'products', name: 'Produtos Android');
    await openApp(tester);
    await tester.tap(find.text('Produtos Android'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-item')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('item-name')), 'Carne');
    final save = find.byKey(const ValueKey('save-item'));
    final context = tester.element(save);
    expect(
      tester.getBottomRight(save).dy,
      lessThanOrEqualTo(
        MediaQuery.sizeOf(context).height -
            MediaQuery.viewInsetsOf(context).bottom,
      ),
    );
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(
      (await repository.listItems('products')).single.plannedQuantity,
      isNull,
    );
    await tester.tap(find.text('Carne'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('item-quantity')), '5');
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect((await repository.listItems('products')).single.plannedQuantity, 5);
    await tester.tap(find.text('Carne'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('item-name')),
      'Carne bovina',
    );
    await tester.enterText(find.byKey(const ValueKey('item-quantity')), '');
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(
      (await repository.listItems('products')).single.plannedQuantity,
      isNull,
    );
    expect(find.text('Carne bovina'), findsOneWidget);
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Produtos Android'));
    await tester.pumpAndSettle();
    expect(find.text('Carne bovina'), findsOneWidget);
  });

  testWidgets('F2-03 Android: erro SQL de item mantém formulário e retry', (
    tester,
  ) async {
    await repository.createList(id: 'products', name: 'Produtos Android');
    await db.execute('''CREATE TRIGGER fail_item BEFORE INSERT ON shopping_items
      BEGIN SELECT RAISE(ABORT, 'simulated storage failure'); END''');
    await openApp(tester);
    await tester.tap(find.text('Produtos Android'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-item')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('item-name')), 'Sabonete');
    await tester.enterText(find.byKey(const ValueKey('item-quantity')), '5');
    await tester.tap(find.byKey(const ValueKey('save-item')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Seus campos foram mantidos'), findsOneWidget);
    expect(await repository.listItems('products'), isEmpty);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('item-quantity')))
          .controller!
          .text,
      '5',
    );
    await db.execute('DROP TRIGGER fail_item');
    await tester.tap(find.byKey(const ValueKey('save-item')));
    await tester.pumpAndSettle();
    expect((await repository.listItems('products')).single.plannedQuantity, 5);
  });

  testWidgets('F4-05 Android: aparência persistida volta ao recriar o app', (
    tester,
  ) async {
    final path = p.join(directory.path, 'preferences.db');
    final store = ThemePreferenceStore(path: path);
    expect(await store.read(), ThemePreference.system);
    await tester.pumpWidget(
      MarketListApp(repository: repository, persistTheme: store.save),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Aparência'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<ThemePreference>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AMOLED').last);
    await tester.pumpAndSettle();
    expect(await store.read(), ThemePreference.amoled);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    final reopened = ThemePreferenceStore(path: path);
    await tester.pumpWidget(
      MarketListApp(
        repository: repository,
        initialTheme: await reopened.read(),
        persistTheme: reopened.save,
      ),
    );
    await tester.pumpAndSettle();
    final scaffold = tester.element(find.byType(Scaffold));
    expect(Theme.of(scaffold).scaffoldBackgroundColor, const Color(0xFF000000));
  });

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
