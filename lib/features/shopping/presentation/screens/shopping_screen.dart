import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/money/money.dart';
import '../../domain/models/shopping_item.dart';
import '../../domain/shopping_calculator.dart';
import '../view_models/shopping_items_view_model.dart';
import '../purchase_status_text.dart';
import '../widgets/edit_budget_dialog.dart';
import '../widgets/item_form_sheet.dart';

class ShoppingScreen extends StatefulWidget {
  const ShoppingScreen({super.key});

  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  bool _onlyToBuy = false;

  Future<void> _editBudget(BuildContext context) async {
    final model = context.read<ShoppingItemsViewModel>();
    if (!model.canEdit) return;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ChangeNotifierProvider.value(
        value: model,
        child: const EditBudgetDialog(),
      ),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Orçamento salvo.')));
    }
  }

  Future<void> _openForm(BuildContext context, [ShoppingItem? item]) async {
    final model = context.read<ShoppingItemsViewModel>();
    final started = item == null ? model.beginCreate() : model.beginEdit(item);
    if (!started) return;
    try {
      final saved = await showModalBottomSheet<ItemFormResult>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        useSafeArea: true,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        builder: (_) => ChangeNotifierProvider.value(
          value: model,
          child: const ItemFormSheet(),
        ),
      );
      if (saved != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              saved == ItemFormResult.removed
                  ? 'Produto removido.'
                  : 'Produto salvo.',
            ),
          ),
        );
      }
    } finally {
      model.clearDraft();
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<ShoppingItemsViewModel>();
    final visibleItems = [
      for (final summary
          in model.calculation?.items ?? const <ItemPurchaseSummary>[])
        if (summary.status != ItemPurchaseStatus.removed &&
            (!_onlyToBuy || summary.status != ItemPurchaseStatus.purchased))
          summary,
    ];
    final compactAmounts =
        MediaQuery.sizeOf(context).width < 360 ||
        MediaQuery.textScalerOf(context).scale(14) > 20;
    return PopScope(
      canPop: !model.isSaving,
      child: Scaffold(
        // The form sheet owns the keyboard inset; keep this route steady behind it.
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          title: Text(model.shoppingList.name),
          actions: [
            if (!model.readOnly)
              IconButton(
                tooltip: model.shoppingList.budgetCents == null
                    ? 'Definir orçamento'
                    : 'Editar orçamento',
                onPressed: model.canEdit ? () => _editBudget(context) : null,
                icon: const Icon(Icons.account_balance_wallet_outlined),
              ),
            IconButton(
              tooltip: 'Atualizar produtos',
              onPressed: model.isBusy ? null : model.load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              if (model.isLoading)
                const LinearProgressIndicator(
                  semanticsLabel: 'Carregando produtos',
                ),
              if (model.readOnly)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.medium),
                  child: Text('Lista disponível somente para consulta.'),
                ),
              if (model.loadError != null)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.medium),
                  child: Column(
                    children: [
                      Semantics(
                        liveRegion: true,
                        child: Text(model.loadError!),
                      ),
                      TextButton(
                        onPressed: model.isBusy ? null : model.load,
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                ),
              if (model.hasLoaded)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.medium,
                  ),
                  child: Wrap(
                    spacing: AppSpacing.small,
                    children: [
                      ChoiceChip(
                        label: const Text('Todos'),
                        selected: !_onlyToBuy,
                        onSelected: (_) => setState(() => _onlyToBuy = false),
                      ),
                      ChoiceChip(
                        label: const Text('A comprar'),
                        selected: _onlyToBuy,
                        onSelected: (_) => setState(() => _onlyToBuy = true),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: visibleItems.isEmpty
                    ? Center(
                        child: Text(
                          model.isLoading
                              ? 'Carregando produtos…'
                              : model.hasLoaded && model.loadError == null
                              ? _onlyToBuy
                                    ? 'Nenhum produto a comprar.'
                                    : 'Nenhum produto nesta lista.'
                              : '',
                        ),
                      )
                    : ListView.separated(
                        itemCount: visibleItems.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final summary = visibleItems[index];
                          final item = summary.item;
                          final statusIcon = switch (summary.status) {
                            ItemPurchaseStatus.pending => Icons.circle_outlined,
                            ItemPurchaseStatus.partial => Icons.timelapse,
                            ItemPurchaseStatus.purchased =>
                              Icons.check_circle_outline,
                            ItemPurchaseStatus.quantityUnconfirmed =>
                              Icons.help_outline,
                            ItemPurchaseStatus.removed =>
                              Icons.remove_circle_outline,
                          };
                          final colors = Theme.of(context).colorScheme;
                          final statusColor = switch (summary.status) {
                            ItemPurchaseStatus.purchased => colors.primary,
                            ItemPurchaseStatus.partial => colors.secondary,
                            ItemPurchaseStatus.quantityUnconfirmed =>
                              colors.tertiary,
                            _ => colors.onSurfaceVariant,
                          };
                          final subtotal = summary.entries.isEmpty
                              ? 'Sem preço'
                              : formatMoneyCents(summary.subtotalCents);
                          return MergeSemantics(
                            child: ListTile(
                              key: ValueKey('item-${item.id}'),
                              visualDensity: VisualDensity.compact,
                              leading: ExcludeSemantics(
                                child: Icon(statusIcon, color: statusColor),
                              ),
                              title: Text(item.name),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(purchaseStatusText(summary)),
                                  if (compactAmounts) Text(subtotal),
                                ],
                              ),
                              onTap: model.canEdit && item.removedAt == null
                                  ? () => _openForm(context, item)
                                  : null,
                              trailing: compactAmounts
                                  ? const Icon(Icons.chevron_right)
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(subtotal),
                                        const Icon(Icons.chevron_right),
                                      ],
                                    ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(height: 1),
            SafeArea(
              top: false,
              minimum: const EdgeInsets.symmetric(
                horizontal: AppSpacing.medium,
                vertical: AppSpacing.small,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (model.totalCents case final total?)
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        'Total registrado: ${formatMoneyCents(total)}',
                        textAlign: TextAlign.center,
                        style: compactAmounts
                            ? Theme.of(context).textTheme.titleMedium
                            : Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  if (model.remainingBudgetCents case final remaining?)
                    Text(
                      switch (remaining) {
                        > 0 => '${formatMoneyCents(remaining)} disponíveis',
                        0 => 'Limite atingido',
                        _ =>
                          '${formatMoneyCents(-remaining)} acima do orçamento',
                      },
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: remaining < 0
                            ? Theme.of(context).colorScheme.error
                            : null,
                      ),
                    ),
                  FilledButton.icon(
                    key: const ValueKey('add-item'),
                    onPressed: model.canEdit ? () => _openForm(context) : null,
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar produto'),
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
