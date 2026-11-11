import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/money/money.dart';

import '../../domain/models/shopping_item.dart';
import '../../domain/models/shopping_list.dart';
import '../../domain/models/purchase_entry.dart';
import '../../domain/shopping_calculator.dart';
import '../../domain/shopping_repository.dart';
import '../item_quantity_input.dart';
import '../list_budget_input.dart';

class ShoppingItemsViewModel extends ChangeNotifier {
  ShoppingItemsViewModel(this._repository, this._shoppingList)
    : _readOnly = _shoppingList.status == ShoppingListStatus.finalized;

  final ShoppingRepository _repository;
  ShoppingList _shoppingList;
  ShoppingList get shoppingList => _shoppingList;
  List<ShoppingItem> _items = const [];
  ShoppingCalculation? _calculation;
  String? _purchaseItemId;
  PurchaseEntry? _editingPurchase;
  String? _entryCreationId;
  String? _removingEntryId;
  String _purchaseQuantity = '';
  String _purchasePrice = '';
  String? _purchaseError;
  String? _purchaseQuantityError;
  String? _purchasePriceError;
  bool _loading = false;
  bool _saving = false;
  bool _removing = false;
  bool _hasLoaded = false;
  bool _disposed = false;
  bool _readOnly;
  ShoppingItem? _editingItem;
  String? _creationId;
  String _draftName = '';
  String _draftQuantity = '';
  String _draftPrice = '';
  String? _quickEntryId;
  String? _draftPriceError;
  String? _loadError;
  String? _saveError;
  String? _nameError;
  String? _quantityError;
  ({String id, DateTime removedAt})? _removalToUndo;
  Timer? _undoTimer;

  List<ShoppingItem> get items => _items;
  List<ShoppingItem> get visibleItems =>
      List.unmodifiable(_items.where((item) => item.removedAt == null));
  bool get isLoading => _loading;
  bool get isSaving => _saving;
  bool get isRemoving => _removing;
  bool get isBusy => _loading || _saving;
  bool get hasLoaded => _hasLoaded;
  bool get readOnly => _readOnly;
  bool get canEdit =>
      !_disposed && _hasLoaded && _loadError == null && !isBusy && !_readOnly;
  bool get hasRemovalToUndo => _removalToUndo != null && !_readOnly;
  ShoppingItem? get editingItem => _editingItem;
  String get draftName => _draftName;
  String get draftQuantity => _draftQuantity;
  String get draftPrice => _draftPrice;
  String? get draftPriceError => _draftPriceError;
  bool get draftHasPrice => _draftPrice.trim().isNotEmpty;
  int? get quickPreviewCents {
    try {
      final price = parseMoneyCents(_draftPrice);
      if (price == null) return null;
      final quantity = parsePlannedQuantity(_draftQuantity);
      return quantity == null ? price : checkedMoneyProduct(quantity, price);
    } on FormatException {
      return null;
    } on RangeError {
      return null;
    }
  }

  String? get loadError => _loadError;
  String? get saveError => _saveError;
  String? get nameError => _nameError;
  String? get quantityError => _quantityError;
  int? get totalCents => _calculation?.totalCents;
  ShoppingCalculation? get calculation => _calculation;
  int? get remainingBudgetCents {
    final budget = shoppingList.budgetCents;
    final total = totalCents;
    return budget == null || total == null ? null : budget - total;
  }

  PurchaseEntry? get editingPurchase => _editingPurchase;
  String? get removingEntryId => _removingEntryId;
  String get purchaseQuantity => _purchaseQuantity;
  String get purchasePrice => _purchasePrice;
  String? get purchaseError => _purchaseError;
  String? get purchaseQuantityError => _purchaseQuantityError;
  String? get purchasePriceError => _purchasePriceError;
  String get purchasePriceLabel => _purchaseQuantity.trim().isEmpty
      ? 'Valor total (R\$)'
      : 'Preço unitário (R\$)';

  ItemPurchaseSummary? summaryFor(String id) {
    for (final summary
        in _calculation?.items ?? const <ItemPurchaseSummary>[]) {
      if (summary.item.id == id) return summary;
    }
    return null;
  }

  int? get purchasePreviewCents {
    try {
      return _buildPurchase('preview').subtotalCents;
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  Future<void> load() async {
    if (_disposed || isBusy) return;
    _loading = true;
    _loadError = null;
    _notify();
    try {
      final loaded = await _repository.loadShoppingList(shoppingList.id);
      if (_disposed) return;
      _acceptCalculation(loaded);
      _hasLoaded = true;
    } catch (_) {
      if (!_disposed) {
        _loadError = 'Não foi possível carregar os produtos. Tente novamente.';
      }
    } finally {
      _loading = false;
      _notify();
    }
  }

  Future<String?> saveBudget(String input) async {
    if (!canEdit) return 'O orçamento não está disponível para edição.';
    final int? budget;
    try {
      budget = parseListBudget(input);
    } on FormatException catch (error) {
      return error.message;
    }
    _saving = true;
    _notify();
    try {
      _shoppingList = await _repository.updateListBudget(
        shoppingList.id,
        budget,
      );
      return null;
    } on FinalizedShoppingListException {
      _readOnly = true;
      return 'A lista finalizada está disponível somente para consulta.';
    } catch (_) {
      return 'Não foi possível salvar. O valor digitado foi mantido.';
    } finally {
      _saving = false;
      _notify();
    }
  }

  bool beginCreate() {
    if (!canEdit) return false;
    _resetDraft();
    return true;
  }

  bool beginEdit(ShoppingItem item) {
    if (!canEdit ||
        item.shoppingListId != shoppingList.id ||
        item.removedAt != null) {
      return false;
    }
    _resetDraft();
    _editingItem = item;
    _draftName = item.name;
    _draftQuantity = item.plannedQuantity?.toString() ?? '';
    return true;
  }

  void setDraftName(String value) {
    if (_disposed || _saving) return;
    _draftName = value;
    _nameError = null;
    _notify();
  }

  void setDraftQuantity(String value) {
    if (_disposed || _saving) return;
    _draftQuantity = value;
    _quantityError = null;
    _notify();
  }

  void setDraftPrice(String value) {
    if (_disposed || _saving) return;
    _draftPrice = value;
    _draftPriceError = null;
    _notify();
  }

  Future<bool> saveDraft() async {
    if (!canEdit) return false;
    _nameError = _draftName.trim().isEmpty
        ? 'Informe o nome do produto.'
        : null;
    _quantityError = null;
    int? quantity;
    try {
      quantity = parsePlannedQuantity(_draftQuantity);
    } on FormatException catch (error) {
      _quantityError = error.message;
    }
    _draftPriceError = null;
    int? price;
    if (_editingItem == null) {
      try {
        price = parseMoneyCents(_draftPrice);
      } on FormatException catch (error) {
        _draftPriceError = error.message;
      }
    }
    if (_nameError != null ||
        _quantityError != null ||
        _draftPriceError != null) {
      _notify();
      return false;
    }
    _saving = true;
    _saveError = null;
    _notify();
    try {
      final editing = _editingItem;
      final ShoppingItem saved;
      if (editing == null) {
        _creationId ??= _repository.newItemId();
        if (price != null) {
          _quickEntryId ??= _repository.newEntryId();
          final entry = PurchaseEntry(
            id: _quickEntryId!,
            shoppingItemId: _creationId!,
            quantity: quantity,
            unitPriceCents: quantity == null ? null : price,
            directAmountCents: quantity == null ? price : null,
          );
          final calculation = await _repository.createItemWithPurchase(
            id: _creationId!,
            shoppingListId: shoppingList.id,
            name: _draftName,
            entry: entry,
          );
          if (_disposed) return false;
          _acceptCalculation(calculation);
          _resetDraft();
          return true;
        }
        saved = await _repository.createItem(
          id: _creationId!,
          shoppingListId: shoppingList.id,
          name: _draftName,
          plannedQuantity: quantity,
          origin: ShoppingItemOrigin.planned,
        );
      } else {
        saved = await _repository.updateItem(
          id: editing.id,
          shoppingListId: shoppingList.id,
          name: _draftName,
          plannedQuantity: quantity,
        );
      }
      if (_disposed) return false;
      final updated = [..._items];
      final index = updated.indexWhere((item) => item.id == saved.id);
      if (index < 0) {
        updated.add(saved);
      } else {
        updated[index] = saved;
      }
      _updateConfirmedItems(updated);
      _resetDraft();
      return true;
    } on FinalizedShoppingListException {
      _readOnly = true;
      _saveError =
          'Esta lista foi finalizada e está disponível somente para consulta.';
      return false;
    } on ShoppingItemCreationConflict {
      _saveError = 'Esta inclusão já foi salva com outros dados. Cancele e atualize os produtos.';
      return false;
    } on PurchaseEntryCreationConflict {
      _saveError = 'Esta inclusão já foi salva com outros dados. Cancele e atualize os produtos.';
      return false;
    } on RangeError {
      _saveError =
          'O valor ultrapassa o limite da compra. Seus campos foram mantidos.';
      return false;
    } on RemovedShoppingItemException {
      _saveError =
          'Este produto já foi removido. Cancele e atualize os produtos.';
      return false;
    } on ShoppingItemNotFoundException {
      _saveError = 'Este produto não está mais disponível. Cancele e atualize os produtos.';
      return false;
    } on ShoppingListNotFoundException {
      _readOnly = true;
      _saveError =
          'Esta lista não está mais disponível. Seus campos foram mantidos.';
      return false;
    } catch (_) {
      _saveError = 'Não foi possível salvar o produto. Seus campos foram mantidos. Tente novamente.';
      return false;
    } finally {
      _saving = false;
      _notify();
    }
  }

  Future<bool> removeEditingItem() async {
    final editing = _editingItem;
    if (!canEdit || editing == null) return false;
    _saving = true;
    _removing = true;
    _saveError = null;
    _notify();
    try {
      final removedAt = await _repository.removeItemForUndo(
        id: editing.id,
        shoppingListId: shoppingList.id,
      );
      if (_disposed) return false;
      _updateConfirmedItems(_items.where((item) => item.id != editing.id));
      if (removedAt == null) {
        _saveError = 'Este produto já não está disponível. Cancele e atualize os produtos.';
        return false;
      }
      _clearUndo();
      _removalToUndo = (id: editing.id, removedAt: removedAt);
      _undoTimer = Timer(const Duration(seconds: 5), () {
        _clearUndo();
        _notify();
      });
      _resetDraft();
      return true;
    } on FinalizedShoppingListException {
      _readOnly = true;
      _saveError = 'Esta lista foi finalizada e não permite remover produtos.';
      return false;
    } on ShoppingListNotFoundException {
      _readOnly = true;
      _saveError =
          'Esta lista não está mais disponível. Seus campos foram mantidos.';
      return false;
    } catch (_) {
      _saveError = 'Não foi possível remover o produto. Seus campos foram mantidos. Tente novamente.';
      return false;
    } finally {
      _saving = false;
      _removing = false;
      _notify();
    }
  }

  Future<String> undoRemoval() async {
    final removal = _removalToUndo;
    if (removal == null || !canEdit) {
      return 'Não foi possível desfazer a remoção.';
    }
    _saving = true;
    _notify();
    try {
      final restored = await _repository.restoreRemovedItem(
        id: removal.id,
        shoppingListId: shoppingList.id,
        removedAt: removal.removedAt,
      );
      _clearUndo();
      if (restored == null) return 'Esta remoção já não pode ser desfeita.';
      if (!_disposed) _acceptCalculation(restored);
      return 'Produto restaurado.';
    } on FinalizedShoppingListException {
      _readOnly = true;
      _clearUndo();
      return 'Esta lista foi finalizada e só pode ser consultada.';
    } on ShoppingListNotFoundException {
      _readOnly = true;
      _clearUndo();
      return 'Esta lista não está mais disponível.';
    } on RangeError {
      return 'Restaurar o produto ultrapassaria o limite do total.';
    } catch (_) {
      return 'Não foi possível restaurar o produto.';
    } finally {
      _saving = false;
      _notify();
    }
  }

  void _clearUndo() {
    _undoTimer?.cancel();
    _undoTimer = null;
    _removalToUndo = null;
  }

  bool beginPurchase(ShoppingItem item, {PurchaseEntry? entry}) {
    if (!canEdit ||
        item.shoppingListId != shoppingList.id ||
        item.removedAt != null ||
        (entry != null && entry.shoppingItemId != item.id)) {
      return false;
    }
    _resetPurchaseDraft();
    _purchaseItemId = item.id;
    _editingPurchase = entry;
    _purchaseQuantity = entry?.quantity?.toString() ?? '';
    final price = entry?.unitPriceCents ?? entry?.directAmountCents;
    _purchasePrice = price == null
        ? ''
        : formatMoneyCents(price).replaceFirst('R\$ ', '');
    return true;
  }

  void setPurchaseQuantity(String value) {
    if (_disposed || _saving) return;
    _purchaseQuantity = value;
    _purchaseQuantityError = null;
    _notify();
  }

  void setPurchasePrice(String value) {
    if (_disposed || _saving) return;
    _purchasePrice = value;
    _purchasePriceError = null;
    _notify();
  }

  PurchaseEntry _buildPurchase(String id) {
    final quantity = parsePlannedQuantity(_purchaseQuantity);
    final price = parseMoneyCents(_purchasePrice);
    if (price == null) {
      throw const FormatException('Informe o preço ou valor total.');
    }
    return PurchaseEntry(
      id: id,
      shoppingItemId: _purchaseItemId ?? 'preview',
      quantity: quantity,
      unitPriceCents: quantity == null ? null : price,
      directAmountCents: quantity == null ? price : null,
    );
  }

  Future<bool> savePurchaseDraft() async {
    if (!canEdit || _purchaseItemId == null) return false;
    _purchaseQuantityError = null;
    _purchasePriceError = null;
    _purchaseError = null;
    try {
      parsePlannedQuantity(_purchaseQuantity);
    } on FormatException catch (error) {
      _purchaseQuantityError = error.message;
    }
    try {
      if (parseMoneyCents(_purchasePrice) == null) {
        _purchasePriceError = 'Informe o preço ou valor total.';
      }
    } on FormatException catch (error) {
      _purchasePriceError = error.message;
    }
    if (_purchaseQuantityError != null || _purchasePriceError != null) {
      _notify();
      return false;
    }
    _saving = true;
    _notify();
    try {
      final editing = _editingPurchase;
      _entryCreationId ??= editing?.id ?? _repository.newEntryId();
      final candidate = _buildPurchase(_entryCreationId!);
      final result = editing == null
          ? await _repository.createPurchaseEntry(
              shoppingListId: shoppingList.id,
              entry: candidate,
            )
          : await _repository.updatePurchaseEntry(
              shoppingListId: shoppingList.id,
              entry: candidate,
            );
      if (_disposed) return false;
      _acceptCalculation(result);
      _resetPurchaseDraft();
      return true;
    } catch (error) {
      _purchaseError = _purchaseFailure(error);
      return false;
    } finally {
      _saving = false;
      _notify();
    }
  }

  Future<bool> removeEntry(PurchaseEntry entry) async {
    final item = summaryFor(entry.shoppingItemId)?.item;
    if (!canEdit || item == null || item.removedAt != null) return false;
    _saving = true;
    _removingEntryId = entry.id;
    _purchaseError = null;
    _notify();
    try {
      final result = await _repository.removePurchaseEntry(
        shoppingListId: shoppingList.id,
        shoppingItemId: entry.shoppingItemId,
        entryId: entry.id,
      );
      if (_disposed) return false;
      _acceptCalculation(result);
      if (_editingPurchase?.id == entry.id) _resetPurchaseDraft();
      return true;
    } catch (error) {
      _purchaseError = _purchaseFailure(error);
      return false;
    } finally {
      _saving = false;
      _removingEntryId = null;
      _notify();
    }
  }

  String _purchaseFailure(Object error) {
    if (error is FinalizedShoppingListException ||
        error is ShoppingListNotFoundException) {
      _readOnly = true;
      return 'Esta lista não permite alterações. Seus campos foram mantidos.';
    }
    if (error is RangeError) {
      return 'O valor, quantidade ou total é grande demais. Seus campos foram mantidos.';
    }
    if (error is PurchaseEntryCreationConflict) {
      return 'Esta entrada já foi salva com outros dados. Cancele e atualize os produtos.';
    }
    if (error is PurchaseEntryNotFoundException ||
        error is RemovedShoppingItemException ||
        error is ShoppingItemNotFoundException) {
      return 'A entrada ou produto não está mais disponível. Cancele e atualize os produtos.';
    }
    return 'Não foi possível gravar a entrada. Seus campos foram mantidos. Tente novamente.';
  }

  void clearPurchaseDraft() {
    if (_disposed || _saving) return;
    _resetPurchaseDraft();
    _notify();
  }

  void _resetPurchaseDraft() {
    _purchaseItemId = null;
    _editingPurchase = null;
    _entryCreationId = null;
    _purchaseQuantity = '';
    _purchasePrice = '';
    _purchaseError = null;
    _purchaseQuantityError = null;
    _purchasePriceError = null;
  }

  void _acceptCalculation(ShoppingCalculation calculation) {
    _calculation = calculation;
    _items = _ordered(calculation.items.map((summary) => summary.item));
  }

  void _updateConfirmedItems(Iterable<ShoppingItem> values) {
    final items = values.toList();
    final ids = items.map((item) => item.id).toSet();
    _acceptCalculation(
      calculateShoppingList(
        shoppingListId: shoppingList.id,
        items: items,
        entries: (_calculation?.items ?? const <ItemPurchaseSummary>[])
            .expand((summary) => summary.entries)
            .where((entry) => ids.contains(entry.shoppingItemId)),
      ),
    );
  }

  void clearDraft() {
    if (_disposed || _saving) return;
    _resetDraft();
    _notify();
  }

  void _resetDraft() {
    _editingItem = null;
    _creationId = null;
    _draftName = '';
    _draftQuantity = '';
    _draftPrice = '';
    _quickEntryId = null;
    _draftPriceError = null;
    _nameError = null;
    _quantityError = null;
    _saveError = null;
  }

  static List<ShoppingItem> _ordered(Iterable<ShoppingItem> items) {
    final ordered = items.toList()..sort(ShoppingItem.compareBySortOrder);
    return List.unmodifiable(ordered);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _clearUndo();
    super.dispose();
  }
}
