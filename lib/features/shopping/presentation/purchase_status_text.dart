import '../domain/shopping_calculator.dart';

String purchaseStatusText(
  ItemPurchaseSummary summary,
) => switch (summary.status) {
  ItemPurchaseStatus.pending =>
    summary.item.plannedQuantity == null
        ? 'Pendente · Quantidade não informada'
        : 'Pendente · Planejado: ${summary.item.plannedQuantity}',
  ItemPurchaseStatus.partial =>
    'Parcial · ${summary.knownPurchasedQuantity} de ${summary.item.plannedQuantity}',
  ItemPurchaseStatus.purchased =>
    summary.purchasedQuantity == null
        ? 'Comprado'
        : 'Comprado · ${summary.purchasedQuantity} unidade(s)',
  ItemPurchaseStatus.quantityUnconfirmed =>
    'Quantidade não confirmada · Planejado: ${summary.item.plannedQuantity}',
  ItemPurchaseStatus.removed => 'Removido',
};
