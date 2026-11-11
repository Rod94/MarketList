import 'purchase_entry.dart';

final class HistoryProductMatch {
  HistoryProductMatch({
    required this.listId,
    required this.listName,
    required this.finalizedAt,
    required this.itemId,
    required this.productName,
    required this.sortOrder,
    required Iterable<PurchaseEntry> entries,
  }) : entries = List.unmodifiable(entries);

  final String listId;
  final String listName;
  final DateTime finalizedAt;
  final String itemId;
  final String productName;
  final int sortOrder;
  final List<PurchaseEntry> entries;

  static int compareByNewest(
    HistoryProductMatch first,
    HistoryProductMatch second,
  ) {
    final byDate = second.finalizedAt.compareTo(first.finalizedAt);
    if (byDate != 0) return byDate;
    final byList = first.listId.compareTo(second.listId);
    if (byList != 0) return byList;
    final byOrder = first.sortOrder.compareTo(second.sortOrder);
    return byOrder != 0 ? byOrder : first.itemId.compareTo(second.itemId);
  }
}
