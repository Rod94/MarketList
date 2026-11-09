import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:market_list/app/app.dart';
import 'package:market_list/features/shopping/domain/models/shopping_list.dart';

import '../support/fake_shopping_repository.dart';

void main() {
  final existing = ShoppingList(
    id: 'existing',
    name: 'Casa',
    createdAt: DateTime.utc(2026, 11, 9),
  );

  Future<void> open(
    WidgetTester tester,
    FakeShoppingRepository repository,
  ) async {
    await tester.pumpWidget(MarketListApp(repository: repository));
    await tester.pumpAndSettle();
  }

  Future<void> openForm(WidgetTester tester) async {
    await tester.tap(find.text('Nova lista'));
    await tester.pumpAndSettle();
  }

  testWidgets('F1-04: inicia em Minhas listas com estado vazio real', (
    tester,
  ) async {
    final repository = FakeShoppingRepository();
    await open(tester, repository);
    expect(find.text('Minhas listas'), findsOneWidget);
    expect(find.text('Nenhuma lista em andamento.'), findsOneWidget);
    expect(find.text('Nova lista'), findsOneWidget);
    expect(repository.loadCalls, 1);
  });

  testWidgets(
    'F1-04: carregamento/erro não aparecem como lista vazia e retry funciona',
    (tester) async {
      final repository = FakeShoppingRepository();
      final pending = Completer<List<ShoppingList>>();
      repository.loadHandler = () => pending.future;
      await tester.pumpWidget(MarketListApp(repository: repository));
      await tester.pump();
      expect(find.text('Carregando listas…'), findsOneWidget);
      expect(find.text('Nenhuma lista em andamento.'), findsNothing);
      pending.completeError(StateError('storage failure'));
      await tester.pumpAndSettle();
      expect(find.text('Tentar novamente'), findsOneWidget);
      expect(find.text('Nenhuma lista em andamento.'), findsNothing);
      repository.loadHandler = null;
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(find.text('Nenhuma lista em andamento.'), findsOneWidget);
    },
  );

  testWidgets(
    'CT-001 UI: cria com nome/orçamento e retorna à lista confirmada',
    (tester) async {
      final repository = FakeShoppingRepository();
      await open(tester, repository);
      await openForm(tester);
      await tester.enterText(
        find.byKey(const ValueKey('new-list-name')),
        'Compra da semana',
      );
      await tester.enterText(
        find.byKey(const ValueKey('new-list-budget')),
        '250,01',
      );
      await tester.tap(find.byKey(const ValueKey('save-list')));
      await tester.pumpAndSettle();
      expect(find.text('Compra da semana'), findsOneWidget);
      expect(find.text('Em andamento'), findsOneWidget);
      expect(find.text('Orçamento: R\$ 250,01'), findsOneWidget);
      expect(find.text('Lista criada.'), findsOneWidget);
      expect(find.byKey(const ValueKey('new-list-name')), findsNothing);
      expect(repository.lists.single.budgetCents, 25001);
    },
  );

  testWidgets('F1-04: valida nome/orçamento sem fechar formulário nem gravar', (
    tester,
  ) async {
    final repository = FakeShoppingRepository();
    await open(tester, repository);
    await openForm(tester);
    await tester.enterText(
      find.byKey(const ValueKey('new-list-budget')),
      'abc',
    );
    await tester.tap(find.byKey(const ValueKey('save-list')));
    await tester.pumpAndSettle();
    expect(find.text('Informe o nome da lista.'), findsOneWidget);
    expect(find.text('Use um valor como 250,00, sem pontos.'), findsOneWidget);
    expect(repository.createCalls, 0);
    expect(find.byKey(const ValueKey('new-list-name')), findsOneWidget);
  });

  testWidgets('F1-04: falha mantém texto e retry não troca identidade', (
    tester,
  ) async {
    final repository = FakeShoppingRepository();
    repository.createHandler = (_, _, _) async => throw StateError('disk full');
    await open(tester, repository);
    await openForm(tester);
    await tester.enterText(
      find.byKey(const ValueKey('new-list-name')),
      'Preservar',
    );
    await tester.enterText(find.byKey(const ValueKey('new-list-budget')), '0');
    await tester.tap(find.byKey(const ValueKey('save-list')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Seus campos foram mantidos'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('new-list-name')))
          .controller!
          .text,
      'Preservar',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('new-list-budget')))
          .controller!
          .text,
      '0',
    );
    repository.createHandler = null;
    await tester.tap(find.byKey(const ValueKey('save-list')));
    await tester.pumpAndSettle();
    expect(find.text('Preservar'), findsOneWidget);
    expect(repository.creationIds.toSet().length, 1);
  });

  testWidgets(
    'F1-04: salvar bloqueia toque duplo, cancelar e voltar antes do commit',
    (tester) async {
      final repository = FakeShoppingRepository();
      final pending = Completer<ShoppingList>();
      repository.createHandler = (_, _, _) => pending.future;
      await open(tester, repository);
      await openForm(tester);
      await tester.enterText(
        find.byKey(const ValueKey('new-list-name')),
        'Aguardar',
      );
      await tester.tap(find.byKey(const ValueKey('save-list')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('save-list')));
      await tester.tap(find.byKey(const ValueKey('cancel-list')));
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('Salvando…'), findsOneWidget);
      expect(find.byKey(const ValueKey('new-list-name')), findsOneWidget);
      expect(repository.createCalls, 1);
      expect(find.text('Lista criada.'), findsNothing);
      pending.complete(
        ShoppingList(
          id: repository.creationIds.single,
          name: 'Aguardar',
          createdAt: DateTime.utc(2026, 11, 9),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Aguardar'), findsOneWidget);
      expect(find.text('Lista criada.'), findsOneWidget);
    },
  );

  testWidgets('F1-04: cancelar descarta apenas rascunho e não grava', (
    tester,
  ) async {
    final repository = FakeShoppingRepository();
    await open(tester, repository);
    await openForm(tester);
    await tester.enterText(
      find.byKey(const ValueKey('new-list-name')),
      'Descartar',
    );
    await tester.tap(find.byKey(const ValueKey('cancel-list')));
    await tester.pumpAndSettle();
    expect(repository.createCalls, 0);
    await openForm(tester);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('new-list-name')))
          .controller!
          .text,
      isEmpty,
    );
  });

  testWidgets('F1-04: toque duplo em Nova lista não empilha formulários', (
    tester,
  ) async {
    await open(tester, FakeShoppingRepository());
    final position = tester.getCenter(find.text('Nova lista'));
    await tester.tapAt(position);
    await tester.tapAt(position);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cancel-list')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('new-list-name')), findsNothing);
    expect(find.text('Minhas listas'), findsOneWidget);
  });

  testWidgets('F1-04: toque duplo em excluir não empilha confirmações', (
    tester,
  ) async {
    final repository = FakeShoppingRepository(lists: [existing]);
    await open(tester, repository);
    final position = tester.getCenter(find.byTooltip('Excluir lista Casa'));
    await tester.tapAt(position);
    await tester.tapAt(position);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(repository.removeCalls, 0);
  });

  testWidgets(
    'CT-002 UI: excluir exige confirmação com nome e aguarda persistência',
    (tester) async {
      final repository = FakeShoppingRepository(lists: [existing]);
      await open(tester, repository);
      await tester.tap(find.byTooltip('Excluir lista Casa'));
      await tester.pumpAndSettle();
      expect(find.text('Excluir “Casa”?'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(repository.removeCalls, 0);
      expect(find.text('Casa'), findsOneWidget);
      final pending = Completer<bool>();
      repository.removeHandler = (_) => pending.future;
      await tester.tap(find.byTooltip('Excluir lista Casa'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(find.text('Casa'), findsOneWidget);
      expect(find.text('Lista excluída.'), findsNothing);
      pending.complete(true);
      await tester.pumpAndSettle();
      expect(find.text('Casa'), findsNothing);
      expect(find.text('Lista excluída.'), findsOneWidget);
    },
  );

  testWidgets('F1-04: erro de exclusão não remove linha nem mostra sucesso', (
    tester,
  ) async {
    final repository = FakeShoppingRepository(lists: [existing]);
    repository.removeHandler = (_) async => throw StateError('storage failure');
    await open(tester, repository);
    await tester.tap(find.byTooltip('Excluir lista Casa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    expect(find.text('Casa'), findsOneWidget);
    expect(
      find.text('Não foi possível excluir a lista. Tente novamente.'),
      findsOneWidget,
    );
    expect(find.text('Lista excluída.'), findsNothing);
  });

  testWidgets(
    'F1-04 / UX-005/018 parcial: teclado, fonte 2x e tela pequena mantêm ações acessíveis',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 250);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await open(tester, FakeShoppingRepository());
      await openForm(tester);
      expect(
        tester.getBottomRight(find.byKey(const ValueKey('save-list'))).dy,
        lessThanOrEqualTo(318),
      );
      expect(
        find.byKey(const ValueKey('cancel-list')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('F1-04: aparência continua acessível e voltar preserva listas', (
    tester,
  ) async {
    final repository = FakeShoppingRepository(lists: [existing]);
    await open(tester, repository);
    await tester.tap(find.byTooltip('Aparência'));
    await tester.pumpAndSettle();
    expect(find.text('Sistema'), findsOneWidget);
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    expect(find.text('Casa'), findsOneWidget);
    expect(repository.loadCalls, 1);
  });
}
