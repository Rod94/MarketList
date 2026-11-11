import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:market_list/app/app.dart';
import 'package:market_list/features/shopping/domain/models/purchase_entry.dart';
import 'package:market_list/features/shopping/domain/models/shopping_item.dart';
import 'package:market_list/features/shopping/domain/models/shopping_list.dart';

import '../support/fake_shopping_repository.dart';

void main() {
  final finalized = ShoppingList(
    id: 'old',
    name: 'Compra de outubro',
    createdAt: DateTime.utc(2026, 10),
    status: ShoppingListStatus.finalized,
    finalizedAt: DateTime.utc(2026, 10, 2),
    finalizedRegisteredTotalCents: 2100,
  );

  ShoppingItem item(
    String id,
    String name,
    int order, {
    String listId = 'old',
    int? planned,
    bool removed = false,
  }) => ShoppingItem(
    id: id,
    shoppingListId: listId,
    name: name,
    origin: ShoppingItemOrigin.planned,
    sortOrder: order,
    plannedQuantity: planned,
    removedAt: removed ? DateTime.utc(2026, 10, 1) : null,
  );

  Future<void> openHistory(
    WidgetTester tester,
    FakeShoppingRepository repository,
  ) async {
    await tester.pumpWidget(MarketListApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Histórico'));
    await tester.pumpAndSettle();
  }

  Future<void> openDetail(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('history-old')));
    await tester.pumpAndSettle();
    expect(find.text('Detalhes da compra'), findsOneWidget);
  }

  testWidgets(
    'CT-012/017 e FIN-007/016 exibem entradas antigas em somente leitura',
    (tester) async {
      final repository = FakeShoppingRepository(
        lists: [
          finalized,
          ShoppingList(
            id: 'later',
            name: 'Compra posterior',
            createdAt: DateTime.utc(2026, 11),
          ),
        ],
        items: [
          item('soap', 'Sabonete', 0, planned: 5),
          item('oil', 'Azeite', 1),
          item('cheese', 'Queijo', 2, planned: 4),
          item('removed', 'Removido da compra', 3, removed: true),
          item('later-soap', 'Sabonete', 0, listId: 'later'),
        ],
      );
      repository.entries.addAll([
        PurchaseEntry(
          id: 'a',
          shoppingItemId: 'soap',
          quantity: 2,
          unitPriceCents: 350,
        ),
        PurchaseEntry(
          id: 'b',
          shoppingItemId: 'soap',
          quantity: 1,
          unitPriceCents: 420,
        ),
        PurchaseEntry(
          id: 'c',
          shoppingItemId: 'cheese',
          quantity: 1,
          unitPriceCents: 290,
        ),
        PurchaseEntry(
          id: 'd',
          shoppingItemId: 'cheese',
          directAmountCents: 690,
        ),
        PurchaseEntry(
          id: 'later',
          shoppingItemId: 'later-soap',
          quantity: 1,
          unitPriceCents: 999,
        ),
      ]);
      await openHistory(tester, repository);
      await openDetail(tester);
      expect(find.text('Compra de outubro'), findsOneWidget);
      expect(find.text('Somente para consulta'), findsOneWidget);
      expect(find.text('Compra parcial'), findsOneWidget);
      expect(find.text('Planejado: 5'), findsOneWidget);
      expect(find.text('Quantidade comprada: 3'), findsOneWidget);
      expect(find.text('Faltaram: 2'), findsOneWidget);
      expect(find.text('2 × R\$ 3,50 = R\$ 7,00'), findsOneWidget);
      expect(find.text('1 × R\$ 4,20 = R\$ 4,20'), findsOneWidget);
      expect(find.text('Subtotal do produto: R\$ 11,20'), findsOneWidget);
      expect(find.text('Azeite'), findsOneWidget);
      expect(find.text('Não comprado'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Valor direto: R\$ 6,90'), 120);
      expect(find.text('Quantidade não confirmada'), findsOneWidget);
      expect(find.text('Unidades conhecidas: 1'), findsOneWidget);
      expect(find.text('Removido da compra'), findsNothing);
      expect(find.textContaining('R\$ 9,99'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Histórico'), findsOneWidget);
    },
  );

  testWidgets('F6-02 falha recuperável e compra finalizada vazia', (
    tester,
  ) async {
    final repository = FakeShoppingRepository(lists: [finalized])
      ..itemsLoadHandler = (_) async => throw StateError('falha');
    await openHistory(tester, repository);
    await openDetail(tester);
    expect(
      find.text('Não foi possível carregar os detalhes da compra.'),
      findsOneWidget,
    );
    expect(find.text('Nenhum produto nesta compra.'), findsNothing);
    repository.itemsLoadHandler = null;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Nenhum produto nesta compra.'), findsOneWidget);
  });

  testWidgets('F6-02 entrada desatualizada não abre compra ativa', (
    tester,
  ) async {
    final repository = FakeShoppingRepository(
      lists: [finalized],
      items: [item('private', 'Produto de compra ativa', 0)],
    );
    await openHistory(tester, repository);
    repository.lists[0] = ShoppingList(
      id: finalized.id,
      name: 'Ativa',
      createdAt: finalized.createdAt,
    );
    await openDetail(tester);
    expect(find.text('Compra finalizada não encontrada.'), findsOneWidget);
    expect(find.text('Produto de compra ativa'), findsNothing);
  });
}
