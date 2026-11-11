import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/money/money.dart';
import '../../shopping/domain/shopping_calculator.dart';
import '../../shopping/presentation/list_budget_input.dart';
import '../../shopping/presentation/purchase_status_text.dart';
import 'checkout_view_model.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _paidController = TextEditingController();

  @override
  void dispose() {
    _paidController.dispose();
    super.dispose();
  }

  Future<void> _confirm(BuildContext context, CheckoutViewModel model) async {
    FocusScope.of(context).unfocus();
    if (await model.confirm() && context.mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final model = context.watch<CheckoutViewModel>();
    final list = model.review.list;
    final calculation = model.review.calculation;
    final attention = calculation.itemsNeedingAttention.toList();
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final compact =
        MediaQuery.sizeOf(context).width < 360 ||
        MediaQuery.textScalerOf(context).scale(14) > 20;
    return PopScope(
      canPop: !model.isSaving,
      child: Scaffold(
        appBar: AppBar(title: const Text('Conferir compra')),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.medium),
                child: Text(
                  'Total calculado pelo app: ${formatMoneyCents(calculation.totalCents)}',
                  style: compact
                      ? theme.textTheme.titleMedium
                      : theme.textTheme.titleLarge,
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.medium),
                  children: [
                    if (list.budgetCents case final budget?) ...[
                      Text('Orçamento: ${formatListBudget(budget)}'),
                      Text(
                        remainingBudgetText(budget - calculation.totalCents),
                      ),
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
                            ItemPurchaseStatus.pending =>
                              'Sem compra registrada',
                            ItemPurchaseStatus.partial =>
                              'Parcial · faltaram ${summary.missingQuantity}',
                            _ => purchaseStatusText(summary),
                          }),
                        ),
                    ],
                    const SizedBox(height: AppSpacing.large),
                    TextField(
                      key: const ValueKey('checkout-paid'),
                      controller: _paidController,
                      enabled: !model.isSaving,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: model.setPaidInput,
                      decoration: InputDecoration(
                        labelText: 'Valor cobrado no caixa (opcional)',
                        prefixText: 'R\$ ',
                        errorText: model.paidError,
                        errorMaxLines: 3,
                      ),
                    ),
                    if (model.differenceCents case final difference?)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.small),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(switch (difference) {
                            > 0 =>
                              '${formatMoneyCents(difference)} a mais no caixa',
                            0 => 'Valores iguais',
                            _ =>
                              '${formatMoneyCents(-difference)} a menos no caixa',
                          }),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.large),
                    const Text(
                      'Após confirmar, esta compra ficará somente para consulta.',
                    ),
                  ],
                ),
              ),
              if (model.saveError case final error?)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.medium,
                  ),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      error,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.medium,
                  vertical: AppSpacing.small,
                ),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: AppSpacing.small,
                  children: [
                    if (!keyboardOpen)
                      TextButton(
                        onPressed: model.isSaving
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Voltar e revisar'),
                      ),
                    FilledButton(
                      onPressed: model.canConfirm
                          ? () => _confirm(context, model)
                          : null,
                      child: Text(
                        model.isSaving
                            ? 'Finalizando…'
                            : 'Confirmar finalização',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
