import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:market_list/features/shopping/domain/models/shopping_list.dart';
import 'package:market_list/features/shopping/domain/shopping_repository.dart';
import 'package:market_list/features/shopping/presentation/view_models/shopping_lists_view_model.dart';

import '../support/fake_shopping_repository.dart';

void main() {
  late FakeShoppingRepository repository;
  late ShoppingListsViewModel viewModel;
  final existing = ShoppingList(
    id: 'existing',
    name: 'Casa',
    createdAt: DateTime.utc(2026, 11, 8),
  );

  setUp(() {
    repository = FakeShoppingRepository(lists: [existing]);
    viewModel = ShoppingListsViewModel(repository);
  });
  tearDown(() => viewModel.dispose());

  test('F1-04: carregamento distingue início, espera e sucesso', () async {
    final pending = Completer<List<ShoppingList>>();
    repository.loadHandler = () => pending.future;
    expect(viewModel.hasLoaded, isFalse);
    final loading = viewModel.load();
    await viewModel.load();
    expect(viewModel.isLoading, isTrue);
    expect(viewModel.canEditLists, isFalse);
    expect(repository.loadCalls, 1);
    pending.complete([existing]);
    await loading;
    expect(viewModel.lists.single.id, 'existing');
    expect(viewModel.hasLoaded, isTrue);
    expect(viewModel.canEditLists, isTrue);
  });

  test(
    'F1-04: falha de carga é recuperável e não apaga cache confirmado',
    () async {
      await viewModel.load();
      repository.loadHandler = () async => throw StateError('storage failure');
      await viewModel.load();
      expect(viewModel.loadError, isNotNull);
      expect(viewModel.lists.single.id, 'existing');
      expect(viewModel.canEditLists, isFalse);
      repository.loadHandler = null;
      await viewModel.load();
      expect(viewModel.loadError, isNull);
      expect(viewModel.canEditLists, isTrue);
    },
  );

  test('F1-04: valida formulário sem gravar ou gerar ID inválido', () async {
    await viewModel.load();
    viewModel.setDraftName('  ');
    viewModel.setDraftBudget('abc');
    expect(await viewModel.saveDraft(), isFalse);
    expect(viewModel.nameError, isNotNull);
    expect(viewModel.budgetError, isNotNull);
    expect(repository.createCalls, 0);
    expect(repository.idCalls, 0);
  });

  test(
    'F1-04: aguarda persistência e bloqueia toque duplo/remoção/cancelamento',
    () async {
      await viewModel.load();
      final pending = Completer<ShoppingList>();
      repository.createHandler = (_, _, _) => pending.future;
      viewModel.setDraftName('Mercado');
      viewModel.setDraftBudget('100,01');
      final saving = viewModel.saveDraft();
      expect(viewModel.isSaving, isTrue);
      expect(viewModel.lists.length, 1);
      expect(await viewModel.saveDraft(), isFalse);
      expect(await viewModel.removeList('existing'), isFalse);
      viewModel.clearDraft();
      viewModel.setDraftName('Não alterar enquanto salva');
      expect(viewModel.draftName, 'Mercado');
      expect(repository.createCalls, 1);
      expect(repository.removeCalls, 0);
      pending.complete(
        ShoppingList(
          id: repository.creationIds.single,
          name: 'Mercado',
          createdAt: DateTime.utc(2026, 11, 9),
          budgetCents: 10001,
        ),
      );
      expect(await saving, isTrue);
      expect(viewModel.lists.first.name, 'Mercado');
      expect(viewModel.lists.first.budgetCents, 10001);
      expect(viewModel.isSaving, isFalse);
      expect(viewModel.draftName, isEmpty);
    },
  );

  test('F1-04: falha mantém inputs e retry usa o mesmo ID', () async {
    await viewModel.load();
    repository.createHandler = (_, _, _) async => throw StateError('disk full');
    viewModel.setDraftName('Mercado');
    viewModel.setDraftBudget('0');
    expect(await viewModel.saveDraft(), isFalse);
    expect(viewModel.saveError, isNotNull);
    expect(viewModel.draftName, 'Mercado');
    expect(viewModel.draftBudget, '0');
    expect(viewModel.lists.length, 1);
    repository.createHandler = null;
    expect(await viewModel.saveDraft(), isTrue);
    expect(repository.creationIds.toSet().length, 1);
    expect(repository.idCalls, 1);
    expect(viewModel.saveError, isNull);
  });

  test(
    'F1-04: conflito preserva rascunho e não duplica lista confirmada',
    () async {
      await viewModel.load();
      repository.createHandler = (id, _, _) async =>
          throw ShoppingListCreationConflict(id);
      viewModel.setDraftName('Outro nome');
      expect(await viewModel.saveDraft(), isFalse);
      expect(viewModel.saveError, contains('outros dados'));
      expect(viewModel.draftName, 'Outro nome');
      expect(viewModel.lists.length, 1);
    },
  );

  test('F1-04: nova inclusão recebe novo ID após sucesso ou cancelamento explícito', () async {
    await viewModel.load();
    viewModel.setDraftName('Primeira');
    expect(await viewModel.saveDraft(), isTrue);
    viewModel.setDraftName('Segunda');
    expect(await viewModel.saveDraft(), isTrue);
    expect(repository.creationIds.toSet().length, 2);
    viewModel.setDraftName('Descartar');
    viewModel.clearDraft();
    expect(viewModel.draftName, isEmpty);
    expect(viewModel.draftBudget, isEmpty);
  });

  test('F1-04: retorno repetido de ID confirmado não duplica cache', () async {
    await viewModel.load();
    repository.createHandler = (_, _, _) async => existing;
    viewModel.setDraftName('Casa');
    expect(await viewModel.saveDraft(), isTrue);
    expect(viewModel.lists.length, 1);
  });

  test(
    'F1-04: remoção só aparece após persistir e bloqueia ações concorrentes',
    () async {
      await viewModel.load();
      final pending = Completer<bool>();
      repository.removeHandler = (_) => pending.future;
      final removing = viewModel.removeList('existing');
      expect(viewModel.removingId, 'existing');
      expect(viewModel.lists.single.id, 'existing');
      expect(await viewModel.removeList('existing'), isFalse);
      viewModel.setDraftName('Aguardar');
      expect(await viewModel.saveDraft(), isFalse);
      expect(repository.createCalls, 0);
      pending.complete(true);
      expect(await removing, isTrue);
      expect(viewModel.lists, isEmpty);
    },
  );

  test('F1-04: falha de remoção não apaga item nem confirma sucesso', () async {
    await viewModel.load();
    repository.removeHandler = (_) async => throw StateError('storage failure');
    expect(await viewModel.removeList('existing'), isFalse);
    expect(viewModel.deleteError, isNotNull);
    expect(viewModel.lists.single.id, 'existing');
  });

  test(
    'F1-04: repositório finalizado é tratado com mensagem compreensível',
    () async {
      await viewModel.load();
      repository.removeHandler = (id) async =>
          throw FinalizedShoppingListException(id);
      expect(await viewModel.removeList('existing'), isFalse);
      expect(viewModel.deleteError, contains('finalizada'));
      expect(viewModel.lists.single.id, 'existing');
    },
  );

  test('F1-04: ausente sai do cache sem declarar exclusão nova', () async {
    await viewModel.load();
    repository.removeHandler = (_) async => false;
    expect(await viewModel.removeList('existing'), isFalse);
    expect(viewModel.lists, isEmpty);
    expect(viewModel.deleteError, isNull);
  });

  test(
    'F1-04: operação finalizada após dispose não notifica widget removido',
    () async {
      final disposable = ShoppingListsViewModel(repository);
      final pending = Completer<List<ShoppingList>>();
      repository.loadHandler = () => pending.future;
      final loading = disposable.load();
      disposable.dispose();
      pending.complete([existing]);
      await expectLater(loading, completes);
    },
  );
}
