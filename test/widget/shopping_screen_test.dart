import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:market_list/app/app.dart';
import 'package:market_list/features/shopping/domain/models/purchase_entry.dart';
import 'package:market_list/features/shopping/domain/models/shopping_item.dart';
import 'package:market_list/features/shopping/domain/models/shopping_list.dart';

import '../support/fake_shopping_repository.dart';

void main() {
  final list = ShoppingList(
    id: 'list',
    name: 'Compra teste',
    createdAt: DateTime.utc(2026),
  );
  late FakeShoppingRepository repository;
  setUp(() {
    repository = FakeShoppingRepository(lists: [list]);
  });
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(MarketListApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Compra teste'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('add-item')), findsOneWidget);
  }

  Future<void> form(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('add-item')));
    await tester.pumpAndSettle();
  }

  void seedPurchaseStatuses() {
    for (final (index, name) in ['Arroz', 'Feijão', 'Leite', 'Carne'].indexed) {
      repository.items.add(
        ShoppingItem(
          id: 'status-$index',
          shoppingListId: list.id,
          name: name,
          origin: ShoppingItemOrigin.planned,
          sortOrder: index,
          plannedQuantity: 5,
        ),
      );
    }
    repository.entries.addAll([
      PurchaseEntry(
        id: 'partial',
        shoppingItemId: 'status-1',
        quantity: 3,
        unitPriceCents: 350,
      ),
      PurchaseEntry(
        id: 'purchased',
        shoppingItemId: 'status-2',
        quantity: 5,
        unitPriceCents: 422,
      ),
      PurchaseEntry(
        id: 'unknown',
        shoppingItemId: 'status-3',
        directAmountCents: 4782,
      ),
    ]);
  }

  testWidgets('F4-01 diferencia os quatro estados por texto e ícone', (
    tester,
  ) async {
    seedPurchaseStatuses();
    await open(tester);

    for (final (index, (label, icon)) in [
      ('Pendente · Planejado: 5', Icons.circle_outlined),
      ('Parcial · 3 de 5', Icons.timelapse),
      ('Comprado · 5 unidade(s)', Icons.check_circle_outline),
      ('Quantidade não confirmada · Planejado: 5', Icons.help_outline),
    ].indexed) {
      final row = find.byKey(ValueKey('item-status-$index'));
      expect(
        find.descendant(of: row, matching: find.text(label)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.byIcon(icon)),
        findsOneWidget,
      );
      expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
    }
  });

  testWidgets('F4-02 filtra a compra sem mudar posição nem total', (
    tester,
  ) async {
    seedPurchaseStatuses();
    await open(tester);
    expect(find.text('Total registrado: R\$ 79,42'), findsOneWidget);

    await tester.tap(find.text('A comprar'));
    await tester.pumpAndSettle();
    expect(find.text('Arroz'), findsOneWidget);
    expect(find.text('Feijão'), findsOneWidget);
    expect(find.text('Leite'), findsNothing);
    expect(find.text('Carne'), findsOneWidget);
    expect(find.text('Total registrado: R\$ 79,42'), findsOneWidget);

    await tester.tap(find.text('Feijão'));
    await tester.pumpAndSettle();
    final addPrice = find.text('Adicionar outro preço');
    await tester.ensureVisible(addPrice);
    await tester.tap(addPrice);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('purchase-quantity')),
      '2',
    );
    await tester.enterText(
      find.byKey(const ValueKey('purchase-price')),
      '4,20',
    );
    await tester.tap(find.byKey(const ValueKey('save-purchase')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Feijão'), findsNothing);
    expect(find.text('Carne'), findsOneWidget);
    expect(find.text('Total registrado: R\$ 87,82'), findsOneWidget);

    await tester.tap(find.text('Todos'));
    await tester.pumpAndSettle();
    final positions = [
      for (final name in ['Arroz', 'Feijão', 'Leite', 'Carne'])
        tester.getTopLeft(find.text(name)).dy,
    ];
    expect(positions, orderedEquals([...positions]..sort()));
    expect(positions.toSet(), hasLength(4));
    expect(find.text('Total registrado: R\$ 87,82'), findsOneWidget);
  });

  testWidgets(
    'UX-017 mantém total e inclusão acessíveis ao rolar 100 produtos',
    (tester) async {
      repository.items.addAll([
        for (var index = 0; index < 100; index++)
          ShoppingItem(
            id: 'row-$index',
            shoppingListId: list.id,
            name: 'Produto $index',
            origin: ShoppingItemOrigin.planned,
            sortOrder: index,
          ),
      ]);
      repository.entries.add(
        PurchaseEntry(
          id: 'first-price',
          shoppingItemId: 'row-0',
          directAmountCents: 199,
        ),
      );
      await open(tester);
      final total = find.text('Total registrado: R\$ 1,99');
      final add = find.byKey(const ValueKey('add-item'));
      final totalPosition = tester.getCenter(total);
      final addPosition = tester.getCenter(add);
      expect(
        totalPosition.dy,
        greaterThan(tester.getBottomLeft(find.byType(ListView)).dy),
      );
      await tester.scrollUntilVisible(
        find.text('Produto 99'),
        400,
        maxScrolls: 40,
      );
      await tester.pumpAndSettle();
      expect(find.text('Produto 99').hitTestable(), findsOneWidget);
      expect(tester.getCenter(total), totalPosition);
      expect(tester.getCenter(add), addPosition);
      expect(add.hitTestable(), findsOneWidget);
    },
  );

  testWidgets(
    'F3-07 confirma a prévia somente após salvar e mantém o preço em falha',
    (tester) async {
      repository.quickPurchaseHandler = (_, _, _, _) async =>
          throw StateError('falha');
      await open(tester);
      await form(tester);
      await tester.enterText(find.byKey(const ValueKey('item-name')), 'Leite');
      await tester.enterText(find.byKey(const ValueKey('item-quantity')), '3');
      await tester.enterText(find.byKey(const ValueKey('item-price')), '4,22');
      await tester.pumpAndSettle();
      expect(find.text('Prévia do subtotal: R\$ 12,66'), findsOneWidget);
      expect(find.text('Total registrado: R\$ 0,00'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('save-item')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Seus campos foram mantidos'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('item-price')))
            .controller!
            .text,
        '4,22',
      );
      expect(repository.items, isEmpty);
      repository.quickPurchaseHandler = null;
      await tester.tap(find.byKey(const ValueKey('save-item')));
      await tester.pumpAndSettle();
      expect(find.text('Total registrado: R\$ 12,66'), findsOneWidget);
      expect(repository.items.single.plannedQuantity, isNull);
      expect(repository.entries.single.quantity, 3);
    },
  );

  testWidgets('F3-07 registra valor direto gratuito sem inventar quantidade', (
    tester,
  ) async {
    await open(tester);
    await form(tester);
    await tester.enterText(find.byKey(const ValueKey('item-name')), 'Amostra');
    await tester.enterText(find.byKey(const ValueKey('item-price')), '0,00');
    await tester.pumpAndSettle();
    expect(find.text('Valor total (opcional)'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('save-item')));
    await tester.pumpAndSettle();
    expect(repository.entries.single.directAmountCents, 0);
    expect(repository.entries.single.quantity, isNull);
    expect(find.text('Comprado'), findsOneWidget);
  });

  testWidgets(
    'F2-05 oculta removidos da carga e remove somente o produto selecionado',
    (tester) async {
      repository.items.addAll([
        for (var i = 0; i < 3; i++)
          ShoppingItem(
            id: 'i$i',
            shoppingListId: 'list',
            name: 'Produto $i',
            origin: ShoppingItemOrigin.planned,
            sortOrder: i,
            removedAt: i == 2 ? DateTime.utc(2026) : null,
          ),
      ]);
      await open(tester);
      expect(find.text('Produto 2'), findsNothing);
      await tester.tap(find.text('Produto 0'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('remove-item')));
      await tester.pumpAndSettle();
      expect(find.text('Produto 0'), findsNothing);
      expect(find.text('Produto 1'), findsOneWidget);
      expect(find.text('Produto removido.'), findsOneWidget);
      expect(repository.items.length, 3);
      expect(repository.items.first.removedAt, isNotNull);
      await tester.tap(find.byTooltip('Atualizar produtos'));
      await tester.pumpAndSettle();
      expect(find.text('Produto 0'), findsNothing);
      expect(find.text('Produto 2'), findsNothing);
    },
  );
  testWidgets(
    'F2-05 falha mantém campos e produto; retry remove depois de confirmar',
    (tester) async {
      repository.items.add(
        ShoppingItem(
          id: 'i',
          shoppingListId: 'list',
          name: 'Carne',
          plannedQuantity: 5,
          origin: ShoppingItemOrigin.planned,
          sortOrder: 0,
        ),
      );
      repository.itemRemoveHandler = (_, _) async =>
          throw StateError('storage');
      await open(tester);
      await tester.tap(find.text('Carne'));
      await tester.pumpAndSettle();
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
      expect(find.text('Produto removido.'), findsNothing);
      repository.itemRemoveHandler = null;
      await tester.tap(find.byKey(const ValueKey('remove-item')));
      await tester.pumpAndSettle();
      expect(find.text('Nenhum produto nesta lista.'), findsOneWidget);
    },
  );
  testWidgets('F2-05 remoção pendente bloqueia novo toque, salvar e cancelar', (
    tester,
  ) async {
    repository.items.add(
      ShoppingItem(
        id: 'i',
        shoppingListId: 'list',
        name: 'Carne',
        origin: ShoppingItemOrigin.planned,
        sortOrder: 0,
      ),
    );
    final pending = Completer<bool>();
    repository.itemRemoveHandler = (_, _) => pending.future;
    await open(tester);
    await tester.tap(find.text('Carne'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('remove-item')));
    await tester.pump();
    expect(
      tester
          .widget<TextButton>(find.byKey(const ValueKey('remove-item')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('save-item')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(find.byKey(const ValueKey('cancel-item')))
          .onPressed,
      isNull,
    );
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byKey(const ValueKey('item-name')), findsOneWidget);
    pending.complete(true);
    await tester.pumpAndSettle();
    expect(repository.itemRemoveCalls, 1);
    expect(find.text('Produto removido.'), findsOneWidget);
  });

  testWidgets('F2-04 editar item no meio mantém a linha após recarregar', (
    tester,
  ) async {
    repository.items.addAll([
      for (final i in [2, 0, 1])
        ShoppingItem(
          id: 'i$i',
          shoppingListId: 'list',
          name: ['Zebra', 'Leite', 'Arroz'][i],
          origin: ShoppingItemOrigin.planned,
          sortOrder: i,
        ),
    ]);
    await open(tester);
    expect(
      tester.getTopLeft(find.text('Zebra')).dy,
      lessThan(tester.getTopLeft(find.text('Leite')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Leite')).dy,
      lessThan(tester.getTopLeft(find.text('Arroz')).dy),
    );
    await tester.tap(find.text('Leite'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('item-name')), 'Abacate');
    await tester.tap(find.byKey(const ValueKey('save-item')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Atualizar produtos'));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Zebra')).dy,
      lessThan(tester.getTopLeft(find.text('Abacate')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Abacate')).dy,
      lessThan(tester.getTopLeft(find.text('Arroz')).dy),
    );
  });

  testWidgets(
    'F2-03 abre lista e inclui nome sozinho sem quantidade implícita',
    (tester) async {
      await open(tester);
      await form(tester);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('item-quantity')))
            .controller!
            .text,
        isEmpty,
      );
      expect(find.byType(TextField), findsNWidgets(3));
      await tester.enterText(find.byKey(const ValueKey('item-name')), 'Carne');
      await tester.tap(find.byKey(const ValueKey('save-item')));
      await tester.pumpAndSettle();
      expect(find.text('Carne'), findsOneWidget);
      expect(find.textContaining('Quantidade não informada'), findsOneWidget);
      expect(repository.items.single.plannedQuantity, isNull);
    },
  );
  testWidgets('F2-03 edita nome e retira quantidade mantendo identidade', (
    tester,
  ) async {
    repository.items.add(
      ShoppingItem(
        id: 'i',
        shoppingListId: 'list',
        name: 'Leite',
        plannedQuantity: 5,
        origin: ShoppingItemOrigin.planned,
        sortOrder: 0,
      ),
    );
    await open(tester);
    await tester.tap(find.text('Leite'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('item-name')),
      'Leite integral',
    );
    await tester.enterText(find.byKey(const ValueKey('item-quantity')), '');
    await tester.tap(find.byKey(const ValueKey('save-item')));
    await tester.pumpAndSettle();
    expect(repository.items.single.id, 'i');
    expect(repository.items.single.plannedQuantity, isNull);
    expect(find.text('Leite integral'), findsOneWidget);
  });
  testWidgets('F2-03 valida sem fechar nem gravar e cancelar preserva lista', (
    tester,
  ) async {
    await open(tester);
    await form(tester);
    await tester.enterText(find.byKey(const ValueKey('item-quantity')), '0');
    await tester.tap(find.byKey(const ValueKey('save-item')));
    await tester.pumpAndSettle();
    expect(find.text('Informe o nome do produto.'), findsOneWidget);
    expect(find.textContaining('maior que zero'), findsOneWidget);
    expect(repository.itemCreateCalls, 0);
    await tester.tap(find.byKey(const ValueKey('cancel-item')));
    await tester.pumpAndSettle();
    expect(repository.items, isEmpty);
  });
  testWidgets('F2-03 erro mantém campos; retry usa o mesmo ID', (tester) async {
    repository.itemCreateHandler = (_, _, _, _, _) async =>
        throw StateError('storage');
    await open(tester);
    await form(tester);
    await tester.enterText(find.byKey(const ValueKey('item-name')), 'Sabonete');
    await tester.enterText(find.byKey(const ValueKey('item-quantity')), '5');
    await tester.tap(find.byKey(const ValueKey('save-item')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Seus campos foram mantidos'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('item-name')))
          .controller!
          .text,
      'Sabonete',
    );
    repository.itemCreateHandler = null;
    await tester.tap(find.byKey(const ValueKey('save-item')));
    await tester.pumpAndSettle();
    expect(repository.itemCreationIds.toSet().length, 1);
    expect(find.text('Sabonete'), findsOneWidget);
  });
  testWidgets(
    'F2-03 gravação bloqueia salvar/cancelar/voltar e não antecipa sucesso',
    (tester) async {
      final pending = Completer<ShoppingItem>();
      repository.itemCreateHandler = (_, _, _, _, _) => pending.future;
      await open(tester);
      await form(tester);
      await tester.enterText(find.byKey(const ValueKey('item-name')), 'Carne');
      await tester.tap(find.byKey(const ValueKey('save-item')));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('save-item')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(find.byKey(const ValueKey('cancel-item')))
            .onPressed,
        isNull,
      );
      expect(find.text('Produto salvo.'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byKey(const ValueKey('item-name')), findsOneWidget);
      pending.complete(
        ShoppingItem(
          id: 'i',
          shoppingListId: 'list',
          name: 'Carne',
          origin: ShoppingItemOrigin.planned,
          sortOrder: 0,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Produto salvo.'), findsOneWidget);
      expect(repository.itemCreateCalls, 1);
    },
  );
  testWidgets('F2-03 carga com falha oferece retry sem falso vazio', (
    tester,
  ) async {
    repository.itemsLoadHandler = (_) async => throw StateError('storage');
    await open(tester);
    expect(find.text('Nenhum produto nesta lista.'), findsNothing);
    expect(find.text('Tentar novamente'), findsOneWidget);
    repository.itemsLoadHandler = null;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Nenhum produto nesta lista.'), findsOneWidget);
  });
  testWidgets('F2-03 ações acima do teclado em tela pequena e fonte 2x', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      tester.view.resetViewInsets();
    });
    await open(tester);
    await form(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 250);
    await tester.pumpAndSettle();
    final save = find.byKey(const ValueKey('save-item'));
    expect(tester.getBottomRight(save).dy, lessThanOrEqualTo(318));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('cancel-item')));
    await tester.pumpAndSettle();
  });
}
