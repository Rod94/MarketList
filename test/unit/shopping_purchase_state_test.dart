import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:market_list/features/shopping/domain/models/purchase_entry.dart';
import 'package:market_list/features/shopping/domain/models/shopping_item.dart';
import 'package:market_list/features/shopping/domain/models/shopping_list.dart';
import 'package:market_list/features/shopping/domain/shopping_calculator.dart';
import 'package:market_list/features/shopping/domain/shopping_repository.dart';
import 'package:market_list/features/shopping/presentation/view_models/shopping_items_view_model.dart';

import '../support/fake_shopping_repository.dart';

void main() {
  final list = ShoppingList(
    id: 'list',
    name: 'Compra',
    createdAt: DateTime.utc(2026),
  );
  final item = ShoppingItem(
    id: 'item',
    shoppingListId: 'list',
    name: 'Sabonete',
    plannedQuantity: 5,
    origin: ShoppingItemOrigin.planned,
    sortOrder: 0,
  );
  late FakeShoppingRepository repository;
  late ShoppingItemsViewModel model;
  ShoppingCalculation snapshot(List<PurchaseEntry> entries) =>
      calculateShoppingList(
        shoppingListId: 'list',
        items: [item],
        entries: entries,
      );
  PurchaseEntry entry({
    String id = 'entry',
    int quantity = 3,
    int price = 350,
  }) => PurchaseEntry(
    id: id,
    shoppingItemId: 'item',
    quantity: quantity,
    unitPriceCents: price,
  );
  setUp(() {
    repository = FakeShoppingRepository(items: [item]);
    model = ShoppingItemsViewModel(repository, list);
  });
  tearDown(() => model.dispose());

  test('F3-05: antes de carregar total é desconhecido; depois usa fotografia confirmada', () async {
    expect(model.totalCents, isNull);
    repository.entries.add(entry());
    await model.load();
    expect(model.totalCents, 1050);
    expect(model.summaryFor('item')!.subtotalCents, 1050);
  });
  test('CT-033: digitar prévia não altera total confirmado', () async {
    await model.load();
    model.beginPurchase(item);
    model.setPurchaseQuantity('3');
    model.setPurchasePrice('4,22');
    expect(model.purchasePreviewCents, 1266);
    expect(model.totalCents, 0);
    model.clearPurchaseDraft();
    expect(model.purchasePreviewCents, isNull);
    expect(model.totalCents, 0);
  });
  test('CT-034/035: sucesso aguardado confirma fotografia; toque duplo não duplica', () async {
    final pending = Completer<ShoppingCalculation>();
    repository.purchaseCreateHandler = (_, _) => pending.future;
    await model.load();
    model.beginPurchase(item);
    model.setPurchaseQuantity('3');
    model.setPurchasePrice('3,50');
    final saving = model.savePurchaseDraft();
    expect(model.totalCents, 0);
    expect(model.isSaving, isTrue);
    expect(await model.savePurchaseDraft(), isFalse);
    model.clearPurchaseDraft();
    expect(model.purchasePrice, '3,50');
    pending.complete(snapshot([entry()]));
    expect(await saving, isTrue);
    expect(model.totalCents, 1050);
    expect(repository.purchaseCreateCalls, 1);
  });
  test('UX-008: falha mantém texto e ID no retry, sem alterar total', () async {
    repository.purchaseCreateHandler = (_, _) async =>
        throw StateError('storage');
    await model.load();
    model.beginPurchase(item);
    model.setPurchaseQuantity('3');
    model.setPurchasePrice('3,50');
    expect(await model.savePurchaseDraft(), isFalse);
    expect(model.totalCents, 0);
    expect(model.purchaseQuantity, '3');
    expect(model.purchasePrice, '3,50');
    repository.purchaseCreateHandler = (_, value) async => snapshot([value]);
    expect(await model.savePurchaseDraft(), isTrue);
    expect(repository.entryCreationIds.toSet().length, 1);
    expect(model.totalCents, 1050);
  });
  test(
    'entrada incompleta, inválida ou produto overflow não grava nem muda total',
    () async {
      await model.load();
      model.beginPurchase(item);
      expect(await model.savePurchaseDraft(), isFalse);
      model.setPurchasePrice('1,001');
      expect(await model.savePurchaseDraft(), isFalse);
      model.setPurchasePrice('1,00');
      model.setPurchaseQuantity('0');
      expect(await model.savePurchaseDraft(), isFalse);
      model.setPurchasePrice('92233720368547758,07');
      model.setPurchaseQuantity('2');
      expect(model.purchasePreviewCents, isNull);
      expect(await model.savePurchaseDraft(), isFalse);
      expect(repository.purchaseCreateCalls, 0);
      expect(model.totalCents, 0);
    },
  );
  test(
    'D-028: zero explícito salva e branco não equivale a gratuito',
    () async {
      await model.load();
      model.beginPurchase(item);
      model.setPurchasePrice('0,00');
      expect(await model.savePurchaseDraft(), isTrue);
      expect(model.totalCents, 0);
      expect(model.summaryFor('item')!.entries.single.directAmountCents, 0);
    },
  );
  test('CT-022: edição substitui a entrada sem duplicar total', () async {
    repository.entries.add(entry(quantity: 1, price: 2590));
    await model.load();
    model.beginPurchase(item, entry: repository.entries.single);
    model.setPurchasePrice('23,90');
    expect(model.totalCents, 2590);
    expect(await model.savePurchaseDraft(), isTrue);
    expect(model.totalCents, 2390);
    expect(repository.entries.length, 1);
  });
  test('CT-023: exclusão atualiza somente após confirmação', () async {
    repository.entries.addAll([
      entry(),
      entry(id: 'second', quantity: 2, price: 420),
    ]);
    await model.load();
    final pending = Completer<ShoppingCalculation>();
    repository.purchaseRemoveHandler = (_, _, _) => pending.future;
    final removing = model.removeEntry(repository.entries.last);
    expect(model.totalCents, 1890);
    expect(await model.removeEntry(repository.entries.last), isFalse);
    pending.complete(snapshot([entry()]));
    expect(await removing, isTrue);
    expect(model.totalCents, 1050);
  });
  test(
    'falha de excluir preserva entrada e total; overflow do repositório também',
    () async {
      repository.entries.add(entry());
      await model.load();
      repository.purchaseRemoveHandler = (_, _, _) async =>
          throw StateError('storage');
      expect(await model.removeEntry(repository.entries.single), isFalse);
      expect(model.totalCents, 1050);
      expect(model.summaryFor('item')!.entries.length, 1);
      model.beginPurchase(item);
      model.setPurchasePrice('1,00');
      repository.purchaseCreateHandler = (_, _) async =>
          throw RangeError('aggregate');
      expect(await model.savePurchaseDraft(), isFalse);
      expect(model.totalCents, 1050);
      expect(model.purchasePrice, '1,00');
    },
  );
  test(
    'finalizada entre abrir e salvar bloqueia novas operações e mantém campos',
    () async {
      await model.load();
      model.beginPurchase(item);
      model.setPurchasePrice('1,00');
      repository.purchaseCreateHandler = (_, _) async =>
          throw const FinalizedShoppingListException('list');
      expect(await model.savePurchaseDraft(), isFalse);
      expect(model.readOnly, isTrue);
      expect(model.purchasePrice, '1,00');
      expect(model.totalCents, 0);
    },
  );
  test(
    'CT-024/050: remover produto confirmado desconta seu subtotal',
    () async {
      repository.entries.add(entry());
      await model.load();
      model.beginEdit(model.items.single);
      expect(await model.removeEditingItem(), isTrue);
      expect(model.totalCents, 0);
    },
  );
  test(
    'carga com falha preserva fotografia anterior sem substituir por zero',
    () async {
      repository.entries.add(entry());
      await model.load();
      repository.itemsLoadHandler = (_) async => throw StateError('storage');
      await model.load();
      expect(model.totalCents, 1050);
      expect(model.loadError, isNotNull);
    },
  );
}
