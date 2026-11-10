import '../../../../core/money/money.dart';

final class PurchaseEntry {
  PurchaseEntry({
    required this.id,
    required this.shoppingItemId,
    this.quantity,
    this.unitPriceCents,
    this.directAmountCents,
  }) : subtotalCents = _subtotal(quantity, unitPriceCents, directAmountCents) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(
        id,
        'id',
        'O identificador não pode ser vazio.',
      );
    }
    if (shoppingItemId.trim().isEmpty) {
      throw ArgumentError.value(
        shoppingItemId,
        'shoppingItemId',
        'O identificador do produto não pode ser vazio.',
      );
    }
  }

  final String id;
  final String shoppingItemId;
  final int? quantity;
  final int? unitPriceCents;
  final int? directAmountCents;
  final int subtotalCents;
  bool get isDirect => directAmountCents != null;

  static int _subtotal(int? quantity, int? unitPrice, int? direct) {
    if (quantity != null && unitPrice != null && direct == null) {
      return checkedMoneyProduct(quantity, unitPrice);
    }
    if (quantity == null && unitPrice == null && direct != null) {
      validateMoneyCents(direct);
      return direct;
    }
    throw ArgumentError(
      'Use quantidade e preço unitário OU valor total sem quantidade.',
    );
  }
}
