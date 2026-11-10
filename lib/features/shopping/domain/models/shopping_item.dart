enum ShoppingItemOrigin { planned, atStore }

final class ShoppingItem {
  ShoppingItem({
    required this.id,
    required this.shoppingListId,
    required String name,
    required this.origin,
    required this.sortOrder,
    this.plannedQuantity,
    DateTime? removedAt,
  }) : name = name.trim(),
       removedAt = removedAt?.toUtc() {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(
        id,
        'id',
        'O identificador não pode ser vazio.',
      );
    }
    if (shoppingListId.trim().isEmpty) {
      throw ArgumentError.value(
        shoppingListId,
        'shoppingListId',
        'O identificador da lista não pode ser vazio.',
      );
    }
    if (this.name.isEmpty) {
      throw ArgumentError.value(name, 'name', 'O nome não pode ser vazio.');
    }
    if (plannedQuantity != null && plannedQuantity! <= 0) {
      throw ArgumentError.value(
        plannedQuantity,
        'plannedQuantity',
        'A quantidade planejada deve ser maior que zero quando informada.',
      );
    }
    if (sortOrder < 0) {
      throw ArgumentError.value(
        sortOrder,
        'sortOrder',
        'A posição não pode ser negativa.',
      );
    }
  }

  final String id;
  final String shoppingListId;
  final String name;
  final ShoppingItemOrigin origin;
  final int sortOrder;
  final int? plannedQuantity;
  final DateTime? removedAt;

  static int compareBySortOrder(ShoppingItem first, ShoppingItem second) {
    final byPosition = first.sortOrder.compareTo(second.sortOrder);
    return byPosition != 0 ? byPosition : first.id.compareTo(second.id);
  }
}
