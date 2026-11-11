import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:market_list/features/history/presentation/history_view_model.dart';
import 'package:market_list/features/shopping/domain/models/shopping_list.dart';

import '../support/fake_shopping_repository.dart';

void main() {
  ShoppingList finalized(String id, DateTime date) => ShoppingList(
    id: id,
    name: id,
    createdAt: DateTime.utc(2026),
    status: ShoppingListStatus.finalized,
    finalizedAt: date,
    finalizedRegisteredTotalCents: 1234,
  );

  test('F6-01 ordena por conclusão e usa ID para empate', () {
    final date = DateTime.utc(2026, 11);
    final lists = [
      finalized('b', date),
      finalized('a', date),
      finalized('c', date.add(const Duration(microseconds: 1))),
    ];
    lists.sort(ShoppingList.compareByNewestFinalization);
    expect(lists.map((list) => list.id), ['c', 'a', 'b']);
    final active = ShoppingList(id: 'active', name: 'Ativa', createdAt: date);
    expect(
      () => ShoppingList.compareByNewestFinalization(active, lists.first),
      throwsArgumentError,
    );
  });

  test('F6-01 espera a consulta e bloqueia atualização concorrente', () async {
    final pending = Completer<List<ShoppingList>>();
    final repository = FakeShoppingRepository()
      ..historyLoadHandler = () => pending.future;
    final model = HistoryViewModel(repository);
    addTearDown(model.dispose);
    final loading = model.load();
    await model.load();
    expect(model.hasLoaded, isFalse);
    expect(model.isLoading, isTrue);
    expect(repository.historyLoadCalls, 1);
    pending.complete([finalized('history', DateTime.utc(2026, 11))]);
    await loading;
    expect(model.hasLoaded, isTrue);
    expect(model.isLoading, isFalse);
    expect(model.lists.single.id, 'history');
    expect(() => model.lists.clear(), throwsUnsupportedError);
  });

  test('F6-01 falha mantém dados e permite nova consulta', () async {
    final repository = FakeShoppingRepository(
      lists: [finalized('history', DateTime.utc(2026, 11))],
    );
    final model = HistoryViewModel(repository);
    addTearDown(model.dispose);
    await model.load();
    repository.historyLoadHandler = () async => throw StateError('falha');
    await model.load();
    expect(model.error, isNotNull);
    expect(model.lists.single.id, 'history');
    repository.historyLoadHandler = null;
    await model.load();
    expect(model.error, isNull);
    expect(model.lists, hasLength(1));
  });

  test(
    'F6-01 sair durante a carga não notifica um ViewModel descartado',
    () async {
      final pending = Completer<List<ShoppingList>>();
      final repository = FakeShoppingRepository()
        ..historyLoadHandler = () => pending.future;
      final model = HistoryViewModel(repository);
      var notifications = 0;
      model.addListener(() => notifications++);
      final loading = model.load();
      model.dispose();
      pending.complete([]);
      await loading;
      await model.load();
      expect(notifications, 1);
      expect(repository.historyLoadCalls, 1);
    },
  );
}
