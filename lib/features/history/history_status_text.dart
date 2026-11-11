import '../shopping/domain/shopping_calculator.dart';

String historyStatusText(ItemPurchaseStatus status) => switch (status) {
  ItemPurchaseStatus.pending => 'Não comprado',
  ItemPurchaseStatus.partial => 'Compra parcial',
  ItemPurchaseStatus.purchased => 'Comprado',
  ItemPurchaseStatus.quantityUnconfirmed => 'Quantidade não confirmada',
  ItemPurchaseStatus.removed => 'Removido',
};
