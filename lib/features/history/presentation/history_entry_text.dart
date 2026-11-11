import '../../../core/money/money.dart';
import '../../shopping/domain/models/purchase_entry.dart';

String historyEntryText(PurchaseEntry entry) => entry.isDirect
    ? 'Valor direto: ${formatMoneyCents(entry.subtotalCents)}'
    : '${entry.quantity} × ${formatMoneyCents(entry.unitPriceCents!)}'
          ' = ${formatMoneyCents(entry.subtotalCents)}';
