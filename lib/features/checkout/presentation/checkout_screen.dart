import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/money/money.dart';
import '../../shopping/domain/models/shopping_list.dart';
import '../../shopping/domain/shopping_calculator.dart';
import '../../shopping/presentation/list_budget_input.dart';
import '../../shopping/presentation/purchase_status_text.dart';

class CheckoutScreen extends StatelessWidget {
  const CheckoutScreen({
    required this.list,
    required this.calculation,
    super.key,
  });

  final ShoppingList list;
  final ShoppingCalculation calculation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final attention = calculation.itemsNeedingAttention.toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Conferir compra')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.medium),
              child: Text(
                'Total calculado pelo app: ${formatMoneyCents(calculation.totalCents)}',
                style: theme.textTheme.titleLarge,
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.medium),
                children: [
                  if (list.budgetCents case final budget?) ...[
                    Text('Orçamento: ${formatListBudget(budget)}'),
                    Text(remainingBudgetText(budget - calculation.totalCents)),
                    const SizedBox(height: AppSpacing.large),
                  ],
                  if (attention.isEmpty)
                    const Text('Nenhum produto precisa de atenção.')
                  else ...[
                    Text(
                      'Produtos que precisam de atenção',
                      style: theme.textTheme.titleMedium,
                    ),
                    for (final summary in attention)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(summary.item.name),
                        subtitle: Text(switch (summary.status) {
                          ItemPurchaseStatus.pending => 'Sem compra registrada',
                          ItemPurchaseStatus.partial =>
                            'Parcial · faltaram ${summary.missingQuantity}',
                          _ => purchaseStatusText(summary),
                        }),
                      ),
                  ],
                  const SizedBox(height: AppSpacing.large),
                  const Text(
                    'Após confirmar, esta compra ficará somente para consulta.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
