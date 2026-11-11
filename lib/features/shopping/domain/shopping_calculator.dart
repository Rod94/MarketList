import '../../../core/money/money.dart';
import 'models/purchase_entry.dart';
import 'models/shopping_item.dart';

enum ItemPurchaseStatus {
  pending,
  partial,
  purchased,
  quantityUnconfirmed,
  removed,
}

final class ItemPurchaseSummary {
  const ItemPurchaseSummary._({
    required this.item,
    required this.entries,
    required this.subtotalCents,
    required this.knownPurchasedQuantity,
    required this.purchasedQuantity,
    required this.missingQuantity,
    required this.status,
  });

  final ShoppingItem item;
  final List<PurchaseEntry> entries;
  final int subtotalCents;
  final int knownPurchasedQuantity;
  final int? purchasedQuantity;
  final int? missingQuantity;
  final ItemPurchaseStatus status;
}

final class ShoppingCalculation {
  const ShoppingCalculation._(this.items, this.totalCents);
  final List<ItemPurchaseSummary> items;
  final int totalCents;

  Iterable<ItemPurchaseSummary> get itemsNeedingAttention => items.where(
    (summary) => switch (summary.status) {
      ItemPurchaseStatus.pending ||
      ItemPurchaseStatus.partial ||
      ItemPurchaseStatus.quantityUnconfirmed => true,
      ItemPurchaseStatus.purchased || ItemPurchaseStatus.removed => false,
    },
  );
}

ShoppingCalculation calculateShoppingList({
  required String shoppingListId,
  required Iterable<ShoppingItem> items,
  required Iterable<PurchaseEntry> entries,
}) {
  if (shoppingListId.trim().isEmpty) {
    throw ArgumentError('Identificador de lista vazio.');
  }
  final orderedItems = items.toList()..sort(ShoppingItem.compareBySortOrder);
  final grouped = <String, List<PurchaseEntry>>{};
  for (final item in orderedItems) {
    if (item.shoppingListId != shoppingListId || grouped.containsKey(item.id)) {
      throw ArgumentError('Item duplicado ou vinculado a outra lista.');
    }
    grouped[item.id] = [];
  }
  final entryIds = <String>{};
  for (final entry in entries) {
    final group = grouped[entry.shoppingItemId];
    if (group == null || !entryIds.add(entry.id)) {
      throw ArgumentError(
        'Entrada duplicada ou vinculada a produto fora da lista.',
      );
    }
    group.add(entry);
  }
  final summaries = [
    for (final item in orderedItems) _summarize(item, grouped[item.id]!),
  ];
  final total = checkedMoneySum(
    summaries
        .where((s) => s.status != ItemPurchaseStatus.removed)
        .map((s) => s.subtotalCents),
  );
  return ShoppingCalculation._(List.unmodifiable(summaries), total);
}

ItemPurchaseSummary _summarize(ShoppingItem item, List<PurchaseEntry> entries) {
  final subtotal = checkedMoneySum(entries.map((entry) => entry.subtotalCents));
  var units = BigInt.zero;
  var hasDirect = false;
  for (final entry in entries) {
    hasDirect = hasDirect || entry.isDirect;
    units += BigInt.from(entry.quantity ?? 0);
  }
  if (units > BigInt.from(maxMoneyCents)) {
    throw RangeError(
      'A quantidade acumulada não cabe em um inteiro de 64 bits.',
    );
  }
  final knownQuantity = units.toInt();
  final planned = item.plannedQuantity;
  final ItemPurchaseStatus status;
  if (item.removedAt != null) {
    status = ItemPurchaseStatus.removed;
  } else if (entries.isEmpty) {
    status = ItemPurchaseStatus.pending;
  } else if (planned == null) {
    status = ItemPurchaseStatus.purchased;
  } else if (hasDirect) {
    status = ItemPurchaseStatus.quantityUnconfirmed;
  } else {
    status = knownQuantity < planned
        ? ItemPurchaseStatus.partial
        : ItemPurchaseStatus.purchased;
  }
  final missing = planned == null || hasDirect
      ? null
      : planned > knownQuantity
      ? planned - knownQuantity
      : 0;
  return ItemPurchaseSummary._(
    item: item,
    entries: List.unmodifiable(entries),
    subtotalCents: subtotal,
    knownPurchasedQuantity: knownQuantity,
    purchasedQuantity: hasDirect ? null : knownQuantity,
    missingQuantity: missing,
    status: status,
  );
}
