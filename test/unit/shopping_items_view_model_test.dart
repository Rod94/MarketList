import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:market_list/features/shopping/domain/models/shopping_item.dart';
import 'package:market_list/features/shopping/domain/models/shopping_list.dart';
import 'package:market_list/features/shopping/domain/shopping_repository.dart';
import 'package:market_list/features/shopping/presentation/item_quantity_input.dart';
import 'package:market_list/features/shopping/presentation/view_models/shopping_items_view_model.dart';

import '../support/fake_shopping_repository.dart';

void main() {
  final list = ShoppingList(
    id: 'list',
    name: 'Compra',
    createdAt: DateTime.utc(2026),
  );
  ShoppingItem item({
    String id = 'item',
    int? quantity,
    String name = 'Carne',
  }) => ShoppingItem(
    id: id,
    shoppingListId: 'list',
    name: name,
    plannedQuantity: quantity,
    origin: ShoppingItemOrigin.planned,
    sortOrder: 0,
  );
  late FakeShoppingRepository repository;
  late ShoppingItemsViewModel model;
  setUp(() {
    repository = FakeShoppingRepository();
    model = ShoppingItemsViewModel(repository, list);
  });
  tearDown(() => model.dispose());

  test('quantidade em branco continua null; inteiros positivos são exatos', () {
    expect(parsePlannedQuantity(' '), isNull);
    expect(parsePlannedQuantity(' 5 '), 5);
    for (final value in [
      '0',
      '-1',
      '1,5',
      '1.5',
      'abc',
      '9223372036854775808',
    ]) {
      expect(() => parsePlannedQuantity(value), throwsFormatException);
    }
  });
  test('carga falha não inventa vazio; retry habilita edição', () async {
    repository.itemsLoadHandler = (_) async => throw StateError('storage');
    await model.load();
    expect(model.hasLoaded, isFalse);
    expect(model.canEdit, isFalse);
    expect(model.loadError, isNotNull);
    repository.itemsLoadHandler = (_) async => [item()];
    await model.load();
    expect(model.items.single.name, 'Carne');
    expect(model.canEdit, isTrue);
    expect(() => model.items.clear(), throwsUnsupportedError);
  });
  test(
    'nome/quantidade inválidos mantêm rascunho e não chamam repositório',
    () async {
      await model.load();
      model.beginCreate();
      model.setDraftName(' ');
      model.setDraftQuantity('0');
      expect(await model.saveDraft(), isFalse);
      expect(model.nameError, isNotNull);
      expect(model.quantityError, isNotNull);
      expect(repository.itemCreateCalls, 0);
      expect(model.draftQuantity, '0');
    },
  );
  test(
    'criação aguarda confirmação e bloqueia duplicação/cancelamento',
    () async {
      final pending = Completer<ShoppingItem>();
      repository.itemCreateHandler = (_, _, _, _, _) => pending.future;
      await model.load();
      model.beginCreate();
      model.setDraftName('Carne');
      final saving = model.saveDraft();
      expect(model.items, isEmpty);
      expect(model.isSaving, isTrue);
      expect(await model.saveDraft(), isFalse);
      expect(model.beginCreate(), isFalse);
      model.clearDraft();
      expect(model.draftName, 'Carne');
      pending.complete(item());
      expect(await saving, isTrue);
      expect(model.items.single.name, 'Carne');
      expect(repository.itemCreateCalls, 1);
    },
  );
  test('falha mantém campos e ID de retry; sucesso limpa rascunho', () async {
    repository.itemCreateHandler = (_, _, _, _, _) async =>
        throw StateError('storage');
    await model.load();
    model.beginCreate();
    model.setDraftName('Carne');
    model.setDraftQuantity('5');
    expect(await model.saveDraft(), isFalse);
    expect(model.draftName, 'Carne');
    expect(model.draftQuantity, '5');
    repository.itemCreateHandler = (id, _, name, quantity, _) async =>
        item(id: id, quantity: quantity, name: name);
    expect(await model.saveDraft(), isTrue);
    expect(repository.itemCreationIds.toSet().length, 1);
    expect(model.draftName, isEmpty);
    expect(model.items.single.plannedQuantity, 5);
  });
  test('edição permite retirar quantidade sem duplicar o item', () async {
    repository.items.add(item(quantity: 5));
    await model.load();
    expect(model.beginEdit(model.items.single), isTrue);
    expect(model.draftQuantity, '5');
    model.setDraftQuantity('');
    model.setDraftName('Carne bovina');
    expect(await model.saveDraft(), isTrue);
    expect(model.items.single.name, 'Carne bovina');
    expect(model.items.single.plannedQuantity, isNull);
    expect(repository.itemCreateCalls, 0);
    expect(repository.itemUpdateCalls, 1);
  });
  test(
    'cancelar descarta apenas rascunho e nova inclusão gera outro ID',
    () async {
      repository.itemCreateHandler = (_, _, _, _, _) async =>
          throw StateError('storage');
      await model.load();
      model.beginCreate();
      model.setDraftName('Carne');
      await model.saveDraft();
      model.clearDraft();
      model.beginCreate();
      model.setDraftName('Leite');
      await model.saveDraft();
      expect(repository.itemCreationIds.toSet().length, 2);
    },
  );
  test(
    'finalizada após abrir bloqueia novas gravações e mantém texto',
    () async {
      repository.itemCreateHandler = (_, _, _, _, _) async =>
          throw const FinalizedShoppingListException('list');
      await model.load();
      model.beginCreate();
      model.setDraftName('Carne');
      expect(await model.saveDraft(), isFalse);
      expect(model.readOnly, isTrue);
      expect(model.draftName, 'Carne');
      expect(model.canEdit, isFalse);
    },
  );
  test(
    'F2-04: carga desordenada e edição preservam posição de cadastro',
    () async {
      final ordered = [
        for (var i = 0; i < 3; i++)
          ShoppingItem(
            id: 'i$i',
            shoppingListId: 'list',
            name: ['Zebra', 'Leite', 'Arroz'][i],
            origin: ShoppingItemOrigin.planned,
            sortOrder: i,
          ),
      ];
      repository.items.addAll(ordered.reversed);
      await model.load();
      expect(model.items.map((i) => i.id), ['i0', 'i1', 'i2']);
      model.beginEdit(model.items[1]);
      model.setDraftName('Abacate');
      await model.saveDraft();
      await model.load();
      expect(model.items.map((i) => i.id), ['i0', 'i1', 'i2']);
      expect(model.items[1].name, 'Abacate');
    },
  );

  test(
    'F2-05: projeção oculta removidos e conserva a ordem dos demais',
    () async {
      repository.items.addAll([
        for (var i = 0; i < 3; i++)
          ShoppingItem(
            id: 'i$i',
            shoppingListId: 'list',
            name: 'Produto $i',
            origin: ShoppingItemOrigin.planned,
            sortOrder: i,
            removedAt: i == 1 ? DateTime.utc(2026) : null,
          ),
      ]);
      await model.load();
      expect(model.items.length, 3);
      expect(model.visibleItems.map((i) => i.id), ['i0', 'i2']);
      expect(() => model.visibleItems.clear(), throwsUnsupportedError);
    },
  );
  test(
    'F2-05: remover aguarda commit, bloqueia repetição e oculta só seu item',
    () async {
      repository.items.add(item());
      await model.load();
      model.beginEdit(model.items.single);
      final pending = Completer<bool>();
      repository.itemRemoveHandler = (_, _) => pending.future;
      final removing = model.removeEditingItem();
      expect(model.visibleItems.length, 1);
      expect(model.isRemoving, isTrue);
      expect(await model.removeEditingItem(), isFalse);
      model.clearDraft();
      expect(model.draftName, 'Carne');
      pending.complete(true);
      expect(await removing, isTrue);
      expect(model.visibleItems, isEmpty);
      expect(repository.itemRemoveCalls, 1);
    },
  );
  test('F2-05: falha mantém produto/rascunho e permite retry', () async {
    repository.items.add(item(quantity: 5));
    await model.load();
    model.beginEdit(model.items.single);
    model.setDraftName('Carne bovina');
    repository.itemRemoveHandler = (_, _) async => throw StateError('storage');
    expect(await model.removeEditingItem(), isFalse);
    expect(model.visibleItems.length, 1);
    expect(model.draftName, 'Carne bovina');
    expect(model.draftQuantity, '5');
    expect(model.saveError, isNotNull);
    repository.itemRemoveHandler = null;
    expect(await model.removeEditingItem(), isTrue);
    await model.load();
    expect(model.visibleItems, isEmpty);
    expect(repository.items.single.removedAt, isNotNull);
  });
  test('F2-05: remoção já ausente não declara novo sucesso', () async {
    repository.items.add(item());
    await model.load();
    model.beginEdit(model.items.single);
    repository.itemRemoveHandler = (_, _) async => false;
    expect(await model.removeEditingItem(), isFalse);
    expect(model.saveError, isNotNull);
    expect(model.draftName, 'Carne');
    expect(model.visibleItems, isEmpty);
  });
  test(
    'F2-05: finalizada recusa remoção, preserva item e bloqueia edição',
    () async {
      repository.items.add(item());
      await model.load();
      model.beginEdit(model.items.single);
      repository.itemRemoveHandler = (_, _) async =>
          throw const FinalizedShoppingListException('list');
      expect(await model.removeEditingItem(), isFalse);
      expect(model.readOnly, isTrue);
      expect(model.visibleItems.length, 1);
      expect(model.draftName, 'Carne');
    },
  );

  test('dispose durante carga não notifica nem lança erro', () async {
    final pending = Completer<List<ShoppingItem>>();
    repository.itemsLoadHandler = (_) => pending.future;
    final disposable = ShoppingItemsViewModel(repository, list);
    var notifications = 0;
    disposable.addListener(() => notifications++);
    final loading = disposable.load();
    disposable.dispose();
    pending.complete([item()]);
    await loading;
    expect(notifications, 1);
  });
}
