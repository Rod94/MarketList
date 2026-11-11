import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:market_list/app/app.dart';
import 'package:market_list/features/shopping/domain/models/history_product_match.dart';
import 'package:market_list/features/shopping/domain/models/purchase_entry.dart';
import 'package:market_list/features/shopping/domain/models/shopping_item.dart';
import 'package:market_list/features/shopping/domain/models/shopping_list.dart';

import '../support/fake_shopping_repository.dart';

void main() {
  final input = find.byKey(const ValueKey('history-search-input'));
  final action = find.byTooltip('Buscar produto');
  final empty = find.text('Nenhum produto encontrado no histórico.');

  FakeShoppingRepository fixture() {
    final repository = FakeShoppingRepository(
      lists: [
        for (final (id, name, month) in [
          ('old', 'Compra de outubro', 10),
          ('new', 'Compra de novembro', 11),
        ])
          ShoppingList(
            id: id,
            name: name,
            createdAt: DateTime.utc(2026, month),
            status: ShoppingListStatus.finalized,
            finalizedAt: DateTime.utc(2026, month, 2, 15),
            finalizedRegisteredTotalCents: id == 'old' ? 1900 : 2200,
          ),
      ],
      items: [
        for (final id in ['old', 'new'])
          ShoppingItem(
            id: 'rice-$id',
            shoppingListId: id,
            name: 'Arroz 5 kg',
            origin: ShoppingItemOrigin.planned,
            sortOrder: 0,
          ),
      ],
    );
    repository.entries.addAll([
      PurchaseEntry(
        id: 'a',
        shoppingItemId: 'rice-old',
        quantity: 1,
        unitPriceCents: 1900,
      ),
      PurchaseEntry(
        id: 'b',
        shoppingItemId: 'rice-new',
        directAmountCents: 2200,
      ),
    ]);
    return repository;
  }

  Future<void> open(
    WidgetTester tester,
    FakeShoppingRepository repository,
  ) async {
    await tester.pumpWidget(MarketListApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Histórico'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Buscar no histórico'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'CT-045 exibe compras, datas e preços e abre o detalhe selecionado',
    (tester) async {
      await open(tester, fixture());
      await tester.enterText(input, '  ARROZ  ');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      final recent = find.byKey(const ValueKey('history-product-rice-new'));
      final old = find.byKey(const ValueKey('history-product-rice-old'));
      expect(tester.getTopLeft(recent).dy, lessThan(tester.getTopLeft(old).dy));
      expect(find.textContaining('Compra de novembro ·'), findsOneWidget);
      expect(find.textContaining('Compra de outubro ·'), findsOneWidget);
      expect(find.text('1 × R\$ 19,00 = R\$ 19,00'), findsOneWidget);
      expect(find.text('Valor direto: R\$ 22,00'), findsOneWidget);
      await tester.tap(old);
      await tester.pumpAndSettle();
      expect(find.text('Detalhes da compra'), findsOneWidget);
      expect(find.text('Compra de outubro'), findsOneWidget);
      expect(find.text('Valor direto: R\$ 22,00'), findsNothing);
    },
  );

  testWidgets(
    'F6-04 diferencia pesquisa vazia, falha e ausência de resultado',
    (tester) async {
      final repository = fixture()
        ..historySearchHandler = (_) async => throw StateError('falha');
      await open(tester, repository);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(empty, findsNothing);
      await tester.enterText(input, 'farinha');
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(
        find.text('Não foi possível buscar no histórico.'),
        findsOneWidget,
      );
      repository.historySearchHandler = null;
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(empty, findsOneWidget);
    },
  );

  testWidgets('F6-04 resposta antiga não substitui pesquisa mais recente', (
    tester,
  ) async {
    final repository = fixture();
    final matches = await repository.searchHistoryProducts('arroz');
    final delayed = Completer<List<HistoryProductMatch>>();
    repository.historySearchHandler = (term) =>
        term == 'arroz' ? delayed.future : Future.value([]);
    await open(tester, repository);
    await tester.enterText(input, 'arroz');
    await tester.tap(action);
    await tester.pump();
    await tester.enterText(input, 'farinha');
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(empty, findsOneWidget);
    delayed.complete(matches);
    await tester.pumpAndSettle();
    expect(empty, findsOneWidget);
    expect(find.text('Arroz 5 kg'), findsNothing);
  });
}
