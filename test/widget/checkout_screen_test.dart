import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:market_list/app/app.dart';
import 'package:market_list/features/shopping/domain/models/purchase_entry.dart';
import 'package:market_list/features/shopping/domain/models/shopping_item.dart';
import 'package:market_list/features/shopping/domain/models/shopping_list.dart';

import '../support/fake_shopping_repository.dart';

void main() {
  FakeShoppingRepository repository({int? budget, bool withAttention = false}) {
    final repository = FakeShoppingRepository(
      lists: [
        ShoppingList(
          id: 'list',
          name: 'Mercado',
          createdAt: DateTime.utc(2026),
          budgetCents: budget,
        ),
      ],
      items: [
        ShoppingItem(
          id: 'leite',
          shoppingListId: 'list',
          name: 'Leite',
          origin: ShoppingItemOrigin.planned,
          sortOrder: 0,
        ),
        if (withAttention) ...[
          ShoppingItem(
            id: 'azeite',
            shoppingListId: 'list',
            name: 'Azeite',
            origin: ShoppingItemOrigin.planned,
            sortOrder: 1,
          ),
          ShoppingItem(
            id: 'sabao',
            shoppingListId: 'list',
            name: 'Sabonete',
            origin: ShoppingItemOrigin.planned,
            plannedQuantity: 5,
            sortOrder: 2,
          ),
          ShoppingItem(
            id: 'carne',
            shoppingListId: 'list',
            name: 'Carne',
            origin: ShoppingItemOrigin.planned,
            plannedQuantity: 2,
            sortOrder: 3,
          ),
        ],
      ],
    );
    repository.entries.addAll([
      PurchaseEntry(
        id: 'leite-compra',
        shoppingItemId: 'leite',
        directAmountCents: 1000,
      ),
      if (withAttention) ...[
        PurchaseEntry(
          id: 'sabao-compra',
          shoppingItemId: 'sabao',
          quantity: 3,
          unitPriceCents: 350,
        ),
        PurchaseEntry(
          id: 'carne-compra',
          shoppingItemId: 'carne',
          directAmountCents: 400,
        ),
      ],
    ]);
    return repository;
  }

  Future<void> openReview(
    WidgetTester tester,
    FakeShoppingRepository repo,
  ) async {
    await tester.pumpWidget(MarketListApp(repository: repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mercado'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Finalizar compra'));
    await tester.pumpAndSettle();
    expect(find.text('Conferir compra'), findsOneWidget);
  }

  testWidgets(
    'FIN-001/009/012 abre conferência com tudo comprado e sem orçamento',
    (tester) async {
      await openReview(tester, repository());
      expect(find.text('Total calculado pelo app: R\$ 10,00'), findsOneWidget);
      expect(find.text('Nenhum produto precisa de atenção.'), findsOneWidget);
      expect(find.textContaining('Orçamento:'), findsNothing);
      expect(find.text('Leite'), findsNothing);
    },
  );

  testWidgets('FIN-002/003/010/013 agrupa avisos e mostra saldo', (
    tester,
  ) async {
    await openReview(tester, repository(budget: 3000, withAttention: true));
    expect(find.text('Total calculado pelo app: R\$ 24,50'), findsOneWidget);
    expect(find.text('Orçamento: R\$ 30,00'), findsOneWidget);
    expect(find.text('R\$ 5,50 disponíveis'), findsOneWidget);
    expect(find.text('Produtos que precisam de atenção'), findsOneWidget);
    expect(find.text('Azeite'), findsOneWidget);
    expect(find.text('Sem compra registrada'), findsOneWidget);
    expect(find.text('Sabonete'), findsOneWidget);
    expect(find.text('Parcial · faltaram 2'), findsOneWidget);
    expect(find.text('Carne'), findsOneWidget);
    expect(find.textContaining('Quantidade não confirmada'), findsOneWidget);
    expect(find.text('Leite'), findsNothing);
  });

  testWidgets(
    'FIN-011 orçamento zero mostra o excedente e mantém a conferência',
    (tester) async {
      await openReview(tester, repository(budget: 0));
      expect(find.text('Orçamento: R\$ 0,00'), findsOneWidget);
      expect(find.text('R\$ 10,00 acima do orçamento'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Mercado'), findsOneWidget);
    },
  );

  testWidgets('FIN-018 a FIN-021 e FIN-024 validam caixa em centavos', (
    tester,
  ) async {
    await openReview(tester, repository());
    final field = find.byKey(const ValueKey('checkout-paid'));
    for (final (input, message) in [
      ('10,00', 'Valores iguais'),
      ('12,40', 'R\$ 2,40 a mais no caixa'),
      ('7,60', 'R\$ 2,40 a menos no caixa'),
      ('0,00', 'R\$ 10,00 a menos no caixa'),
    ]) {
      await tester.enterText(field, input);
      await tester.pumpAndSettle();
      expect(find.text(message), findsOneWidget);
      expect(find.text('Total calculado pelo app: R\$ 10,00'), findsOneWidget);
    }
    await tester.enterText(field, '10,123');
    await tester.pumpAndSettle();
    expect(find.textContaining('Use um valor como'), findsOneWidget);
    expect(find.textContaining('a menos no caixa'), findsNothing);
    await tester.enterText(field, '');
    await tester.pumpAndSettle();
    expect(find.textContaining('Use um valor como'), findsNothing);
    expect(find.textContaining('a menos no caixa'), findsNothing);
  });
}
