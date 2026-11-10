import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:market_list/app/app.dart';
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
      expect(find.byType(TextField), findsNWidgets(2));
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
