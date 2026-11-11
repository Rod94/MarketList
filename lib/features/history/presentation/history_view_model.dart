import 'package:flutter/foundation.dart';

import '../../shopping/domain/models/shopping_list.dart';
import '../../shopping/domain/shopping_repository.dart';

class HistoryViewModel extends ChangeNotifier {
  HistoryViewModel(this._repository);

  final ShoppingRepository _repository;
  List<ShoppingList> _lists = const [];
  bool _loading = false;
  bool _hasLoaded = false;
  bool _disposed = false;
  String? _error;

  List<ShoppingList> get lists => _lists;
  bool get isLoading => _loading;
  bool get hasLoaded => _hasLoaded;
  String? get error => _error;

  Future<void> load() async {
    if (_disposed || _loading) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final lists = await _repository.listFinalizedLists();
      if (!_disposed) {
        _lists = List.unmodifiable(lists);
        _hasLoaded = true;
      }
    } catch (_) {
      if (!_disposed) {
        _error = 'Não foi possível carregar o histórico. Tente novamente.';
      }
    } finally {
      _loading = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
