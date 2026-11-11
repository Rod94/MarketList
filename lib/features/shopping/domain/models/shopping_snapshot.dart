import '../shopping_calculator.dart';
import 'shopping_list.dart';

final class ShoppingSnapshot {
  const ShoppingSnapshot(this.list, this.calculation);

  final ShoppingList list;
  final ShoppingCalculation calculation;

  bool matchesReview(ShoppingSnapshot reviewed) {
    if (list.id != reviewed.list.id ||
        list.createdAt != reviewed.list.createdAt ||
        list.budgetCents != reviewed.list.budgetCents ||
        calculation.totalCents != reviewed.calculation.totalCents) {
      return false;
    }
    final currentItems = calculation.itemsNeedingAttention.iterator;
    final reviewedItems = reviewed.calculation.itemsNeedingAttention.iterator;
    while (currentItems.moveNext()) {
      if (!reviewedItems.moveNext() ||
          _reviewLine(currentItems.current) !=
              _reviewLine(reviewedItems.current)) {
        return false;
      }
    }
    return !reviewedItems.moveNext();
  }

  static (String, String, ItemPurchaseStatus, int?, int?) _reviewLine(
    ItemPurchaseSummary summary,
  ) => (
    summary.item.id,
    summary.item.name,
    summary.status,
    summary.item.plannedQuantity,
    summary.missingQuantity,
  );
}
