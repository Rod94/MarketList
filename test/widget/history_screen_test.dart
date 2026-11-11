import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:market_list/app/app.dart';
import 'package:market_list/features/shopping/domain/models/shopping_list.dart';

import '../support/fake_shopping_repository.dart';

void main() {
  ShoppingList history(String id, String name, DateTime date) => ShoppingList(
    id: id,
    name: name,
    createdAt: DateTime.utc(2026),
    status: ShoppingListStatus.finalized,
    finalizedAt: date,
    finalizedRegisteredTotalCents: 12345,
    checkoutPaidCents: 13000,
  );

  Future<void> open(
    WidgetTester tester,
    FakeShoppingRepository repository,
  ) async {
    await tester.pumpWidget(MarketListApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Histórico'));
    await tester.pumpAndSettle();
    expect(find.text('Histórico'), findsOneWidget);
  }

  testWidgets('F6-01 lista compras finalizadas com data e total persistido', (
    tester,
  ) async {
    final repository = FakeShoppingRepository(
      lists: [
        history('old', 'Compra antiga', DateTime.utc(2026, 10, 10, 15)),
        history('recent', 'Compra recente', DateTime.utc(2026, 11, 10, 15)),
        ShoppingList(
          id: 'active',
          name: 'Compra ativa',
          createdAt: DateTime.utc(2026),
        ),
      ],
    );
    await open(tester, repository);
    expect(find.text('Compra ativa'), findsNothing);
    expect(find.textContaining('Finalizada em'), findsNWidgets(2));
    expect(find.text('Total registrado: R\$ 123,45'), findsNWidgets(2));
    expect(
      tester.getTopLeft(find.text('Compra recente')).dy,
      lessThan(tester.getTopLeft(find.text('Compra antiga')).dy),
    );
    expect(
      tester
          .widget<ListTile>(find.byKey(const ValueKey('history-recent')))
          .onTap,
      isNotNull,
    );
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('F6-01 histórico vazio distingue ausência de compras', (
    tester,
  ) async {
    await open(tester, FakeShoppingRepository());
    expect(find.text('Nenhuma compra finalizada.'), findsOneWidget);
  });

  testWidgets('F6-01 erro oferece nova tentativa sem apresentar falso vazio', (
    tester,
  ) async {
    final repository = FakeShoppingRepository()
      ..historyLoadHandler = () async => throw StateError('falha');
    await open(tester, repository);
    expect(
      find.textContaining('Não foi possível carregar o histórico'),
      findsOneWidget,
    );
    expect(find.text('Nenhuma compra finalizada.'), findsNothing);
    repository.historyLoadHandler = null;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma compra finalizada.'), findsOneWidget);
  });

  testWidgets('F6-01 total e nome longo cabem em tela estreita com fonte 2x', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await open(
      tester,
      FakeShoppingRepository(
        lists: [
          history(
            'long',
            'Compra histórica do supermercado para toda a família',
            DateTime.utc(2026, 11),
          ),
        ],
      ),
    );
    final total = find.text('Total registrado: R\$ 123,45');
    await tester.scrollUntilVisible(total, 120);
    await tester.pumpAndSettle();
    final viewport = tester.getRect(find.byType(ListView));
    final amount = tester.getRect(total);
    expect(amount.top, greaterThanOrEqualTo(viewport.top));
    expect(amount.bottom, lessThanOrEqualTo(viewport.bottom));
    expect(tester.takeException(), isNull);
  });
}
