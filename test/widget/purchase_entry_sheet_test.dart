import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:market_list/app/app.dart';
import 'package:market_list/features/shopping/domain/models/purchase_entry.dart';
import 'package:market_list/features/shopping/domain/models/shopping_item.dart';
import 'package:market_list/features/shopping/domain/models/shopping_list.dart';
import 'package:market_list/features/shopping/domain/shopping_calculator.dart';

import '../support/fake_shopping_repository.dart';

void main() {
  final list = ShoppingList(
    id: 'list',
    name: 'Compra',
    createdAt: DateTime.utc(2026),
  );
  final item = ShoppingItem(
    id: 'soap',
    shoppingListId: 'list',
    name: 'Sabonete',
    plannedQuantity: 5,
    origin: ShoppingItemOrigin.planned,
    sortOrder: 0,
  );
  late FakeShoppingRepository repository;
  setUp(() {
    repository = FakeShoppingRepository(lists: [list], items: [item]);
  });
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(MarketListApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Compra'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sabonete'));
    await tester.pumpAndSettle();
  }

  Future<void> priceForm(WidgetTester tester, {bool another = false}) async {
    final button = find.text(
      another ? 'Adicionar outro preço' : 'Registrar preço',
    );
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String quantity, String price) async {
    await tester.enterText(
      find.byKey(const ValueKey('purchase-quantity')),
      quantity,
    );
    await tester.enterText(find.byKey(const ValueKey('purchase-price')), price);
    await tester.pump();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('save-purchase')));
    await tester.pumpAndSettle();
  }

  testWidgets('F3-06 / UX-020: dois preços no mesmo produto confirmam 18,90', (
    tester,
  ) async {
    await open(tester);
    await priceForm(tester);
    await enter(tester, '3', '3,50');
    expect(find.text('Prévia do subtotal: R\$ 10,50'), findsOneWidget);
    expect(find.text('Total registrado: R\$ 0,00'), findsOneWidget);
    await save(tester);
    await priceForm(tester, another: true);
    await enter(tester, '2', '4,20');
    await save(tester);
    expect(find.text('Subtotal confirmado: R\$ 18,90'), findsOneWidget);
    expect(repository.items.length, 1);
    expect(repository.entries.length, 2);
    await tester.tap(find.byKey(const ValueKey('cancel-item')));
    await tester.pumpAndSettle();
    expect(find.text('Total registrado: R\$ 18,90'), findsOneWidget);
    expect(find.textContaining('Comprado'), findsOneWidget);
  });
  testWidgets('F3-06 corrige preço sem duplicar e exclui só sua entrada', (
    tester,
  ) async {
    repository.entries.addAll([
      PurchaseEntry(
        id: 'a',
        shoppingItemId: 'soap',
        quantity: 1,
        unitPriceCents: 2590,
      ),
      PurchaseEntry(id: 'b', shoppingItemId: 'soap', directAmountCents: 100),
    ]);
    await open(tester);
    await tester.ensureVisible(find.byTooltip('Editar preço 1'));
    await tester.tap(find.byTooltip('Editar preço 1'));
    await tester.pumpAndSettle();
    await enter(tester, '1', '23,90');
    await save(tester);
    expect(repository.entries.length, 2);
    expect(find.text('Subtotal confirmado: R\$ 24,90'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Excluir preço 2'));
    await tester.tap(find.byTooltip('Excluir preço 2'));
    await tester.pumpAndSettle();
    expect(repository.entries.single.id, 'a');
    expect(find.text('Subtotal confirmado: R\$ 23,90'), findsOneWidget);
  });
  testWidgets('F3-06 direto planejado permanece quantidade não confirmada', (
    tester,
  ) async {
    await open(tester);
    await priceForm(tester);
    await enter(tester, '', '47,82');
    expect(find.text('Valor total (R\$)'), findsOneWidget);
    await save(tester);
    expect(find.text('Subtotal confirmado: R\$ 47,82'), findsOneWidget);
    expect(find.textContaining('Quantidade não confirmada'), findsWidgets);
    expect(repository.entries.single.quantity, isNull);
  });
  testWidgets('F3-06 gratuito explícito conta como compra por unidade', (
    tester,
  ) async {
    await open(tester);
    await priceForm(tester);
    await enter(tester, '5', '0,00');
    await save(tester);
    expect(repository.entries.single.unitPriceCents, 0);
    expect(find.textContaining('Comprado'), findsWidgets);
  });
  testWidgets('F3-06 erro mantém preço/quantidade e ID de retry', (
    tester,
  ) async {
    repository.purchaseCreateHandler = (_, _) async =>
        throw StateError('storage');
    await open(tester);
    await priceForm(tester);
    await enter(tester, '3', '3,50');
    await save(tester);
    expect(
      find.textContaining('Seus campos foram mantidos').last,
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('purchase-price')))
          .controller!
          .text,
      '3,50',
    );
    expect(find.text('Total registrado: R\$ 0,00'), findsOneWidget);
    repository.purchaseCreateHandler = null;
    await save(tester);
    expect(repository.entryCreationIds.toSet().length, 1);
    expect(find.text('Subtotal confirmado: R\$ 10,50'), findsOneWidget);
  });
  testWidgets('F3-06 salvar e cancelar bloqueados até confirmação', (
    tester,
  ) async {
    final pending = Completer<ShoppingCalculation>();
    repository.purchaseCreateHandler = (_, _) => pending.future;
    await open(tester);
    await priceForm(tester);
    await enter(tester, '3', '3,50');
    await tester.tap(find.byKey(const ValueKey('save-purchase')));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('save-purchase')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(find.byKey(const ValueKey('cancel-purchase')))
          .onPressed,
      isNull,
    );
    expect(find.text('Total registrado: R\$ 0,00'), findsOneWidget);
    pending.complete(
      calculateShoppingList(
        shoppingListId: 'list',
        items: [item],
        entries: [
          PurchaseEntry(
            id: 'e',
            shoppingItemId: 'soap',
            quantity: 3,
            unitPriceCents: 350,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Subtotal confirmado: R\$ 10,50'), findsOneWidget);
  });
  testWidgets(
    'F3-06 vazio não grava; quantidade inválida não fecha formulário',
    (tester) async {
      await open(tester);
      await priceForm(tester);
      await save(tester);
      expect(find.text('Informe o preço ou valor total.'), findsOneWidget);
      await enter(tester, '0', '1,00');
      await save(tester);
      expect(repository.entries, isEmpty);
      expect(find.byKey(const ValueKey('purchase-quantity')), findsOneWidget);
    },
  );
  testWidgets(
    'F3-06 confirmação acima do teclado em tela pequena com fonte 2x',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetViewInsets();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      await open(tester);
      await priceForm(tester);
      tester.view.viewInsets = const FakeViewPadding(bottom: 250);
      await tester.pumpAndSettle();
      expect(
        tester.getBottomRight(find.byKey(const ValueKey('save-purchase'))).dy,
        lessThanOrEqualTo(318),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
