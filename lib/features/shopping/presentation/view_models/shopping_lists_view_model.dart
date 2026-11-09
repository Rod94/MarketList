import 'package:flutter/foundation.dart';

import '../../domain/models/shopping_list.dart';
import '../../domain/shopping_repository.dart';
import '../list_budget_input.dart';

class ShoppingListsViewModel extends ChangeNotifier {
  ShoppingListsViewModel(this._repository);

  final ShoppingRepository _repository;
  List<ShoppingList> _lists = const [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  bool _isSaving = false;
  bool _disposed = false;
  String? _removingId;
  String? _loadError;
  String? _saveError;
  String? _deleteError;
  String? _nameError;
  String? _budgetError;
  String? _pendingCreationId;
  String _draftName = '';
  String _draftBudget = '';

  List<ShoppingList> get lists => _lists;
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  bool get isSaving => _isSaving;
  bool get isBusy => _isLoading || _isSaving || _removingId != null;
  bool get canEditLists =>
      !_disposed && _hasLoaded && _loadError == null && !isBusy;
  String? get removingId => _removingId;
  String? get loadError => _loadError;
  String? get saveError => _saveError;
  String? get deleteError => _deleteError;
  String? get nameError => _nameError;
  String? get budgetError => _budgetError;
  String get draftName => _draftName;
  String get draftBudget => _draftBudget;

  Future<void> load() async {
    if (_disposed || isBusy) return;
    _isLoading = true;
    _loadError = null;
    _notify();
    try {
      final loaded = await _repository.listActiveLists();
      if (_disposed) return;
      _lists = List.unmodifiable(loaded);
      _hasLoaded = true;
    } catch (_) {
      if (!_disposed) {
        _loadError = 'Não foi possível carregar suas listas. Tente novamente.';
      }
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  void setDraftName(String value) {
    if (_disposed || _isSaving) return;
    _draftName = value;
    if (_nameError != null) {
      _nameError = null;
      _notify();
    }
  }

  void setDraftBudget(String value) {
    if (_disposed || _isSaving) return;
    _draftBudget = value;
    if (_budgetError != null) {
      _budgetError = null;
      _notify();
    }
  }

  Future<bool> saveDraft() async {
    if (!canEditLists) return false;
    _nameError = _draftName.trim().isEmpty ? 'Informe o nome da lista.' : null;
    _budgetError = null;
    int? budget;
    try {
      budget = parseListBudget(_draftBudget);
    } on FormatException catch (error) {
      _budgetError = error.message;
    }
    if (_nameError != null || _budgetError != null) {
      _notify();
      return false;
    }

    _isSaving = true;
    _saveError = null;
    _notify();
    try {
      _pendingCreationId ??= _repository.newListId();
      final saved = await _repository.createList(
        id: _pendingCreationId!,
        name: _draftName,
        budgetCents: budget,
      );
      if (_disposed) return false;
      final updated = [..._lists.where((list) => list.id != saved.id), saved]
        ..sort(ShoppingList.compareByNewestCreation);
      _lists = List.unmodifiable(updated);
      _resetDraft();
      return true;
    } on ShoppingListCreationConflict {
      _saveError = 'Esta criação já foi salva com outros dados. Cancele e atualize as listas antes de tentar novamente.';
      return false;
    } on FinalizedShoppingListException {
      _saveError =
          'Esta lista já foi finalizada. Cancele e atualize suas listas.';
      return false;
    } catch (_) {
      _saveError = 'Não foi possível salvar a lista. Seus campos foram mantidos. Tente novamente.';
      return false;
    } finally {
      _isSaving = false;
      _notify();
    }
  }

  Future<bool> removeList(String id) async {
    if (!canEditLists) return false;
    _removingId = id;
    _deleteError = null;
    _notify();
    try {
      final removed = await _repository.removeActiveList(id);
      if (_disposed) return false;
      _lists = List.unmodifiable(_lists.where((list) => list.id != id));
      return removed;
    } on FinalizedShoppingListException {
      _deleteError = 'Esta lista já foi finalizada e não pode ser excluída.';
      return false;
    } catch (_) {
      _deleteError = 'Não foi possível excluir a lista. Tente novamente.';
      return false;
    } finally {
      _removingId = null;
      _notify();
    }
  }

  void clearDraft() {
    if (_disposed || _isSaving) return;
    _resetDraft();
    _notify();
  }

  void _resetDraft() {
    _draftName = '';
    _draftBudget = '';
    _pendingCreationId = null;
    _nameError = null;
    _budgetError = null;
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
