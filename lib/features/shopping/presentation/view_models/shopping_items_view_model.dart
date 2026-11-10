import 'package:flutter/foundation.dart';

import '../../domain/models/shopping_item.dart';
import '../../domain/models/shopping_list.dart';
import '../../domain/shopping_repository.dart';
import '../item_quantity_input.dart';

class ShoppingItemsViewModel extends ChangeNotifier {
  ShoppingItemsViewModel(this._repository, this.shoppingList)
    : _readOnly = shoppingList.status == ShoppingListStatus.finalized;

  final ShoppingRepository _repository;
  final ShoppingList shoppingList;
  List<ShoppingItem> _items = const [];
  bool _loading = false;
  bool _saving = false;
  bool _hasLoaded = false;
  bool _disposed = false;
  bool _readOnly;
  ShoppingItem? _editingItem;
  String? _creationId;
  String _draftName = '';
  String _draftQuantity = '';
  String? _loadError;
  String? _saveError;
  String? _nameError;
  String? _quantityError;

  List<ShoppingItem> get items => _items;
  bool get isLoading => _loading;
  bool get isSaving => _saving;
  bool get isBusy => _loading || _saving;
  bool get hasLoaded => _hasLoaded;
  bool get readOnly => _readOnly;
  bool get canEdit =>
      !_disposed && _hasLoaded && _loadError == null && !isBusy && !_readOnly;
  ShoppingItem? get editingItem => _editingItem;
  String get draftName => _draftName;
  String get draftQuantity => _draftQuantity;
  String? get loadError => _loadError;
  String? get saveError => _saveError;
  String? get nameError => _nameError;
  String? get quantityError => _quantityError;

  Future<void> load() async {
    if (_disposed || isBusy) return;
    _loading = true;
    _loadError = null;
    _notify();
    try {
      final loaded = await _repository.listItems(shoppingList.id);
      if (_disposed) return;
      _items = List.unmodifiable(loaded);
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
    if (_nameError != null || _quantityError != null) {
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
      _items = List.unmodifiable(updated);
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
    _nameError = null;
    _quantityError = null;
    _saveError = null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
