import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/money/money.dart';
import '../../../checkout/presentation/checkout_screen.dart';
import '../../../checkout/presentation/checkout_view_model.dart';
import '../../domain/models/shopping_item.dart';
import '../../domain/shopping_calculator.dart';
import '../list_budget_input.dart';
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
  bool _checkoutOpen = false;

  Future<void> _openCheckout() async {
    final model = context.read<ShoppingItemsViewModel>();
    if (_checkoutOpen || !model.canEdit) return;
    _checkoutOpen = true;
    try {
      final review = await model.prepareCheckout();
      if (review == null || !mounted) return;
      model.dismissRemovalUndo();
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider(
            create: (_) =>
                CheckoutViewModel(review, persist: model.confirmCheckout),
            child: const CheckoutScreen(),
          ),
        ),
      );
      if (mounted && model.readOnly && !model.isFinalized) {
        await model.load();
      }
    } finally {
      _checkoutOpen = false;
    }
  }

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
      if (saved == ItemFormResult.saved && context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Produto salvo.')));
      }
    } finally {
      model.clearDraft();
    }
  }

  Future<void> _undoRemoval() async {
    final message = await context.read<ShoppingItemsViewModel>().undoRemoval();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _filterLabel(String text, int count, {required bool showCount}) {
    if (!showCount) return Text(text);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text),
        const SizedBox(width: AppSpacing.small),
        Text('($count)'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<ShoppingItemsViewModel>();
    final allItems = [
      for (final summary
          in model.calculation?.items ?? const <ItemPurchaseSummary>[])
        if (summary.status != ItemPurchaseStatus.removed) summary,
    ];
    final itemsToBuy = allItems
        .where((summary) => summary.status != ItemPurchaseStatus.purchased)
        .toList();
    final filtering = _onlyToBuy && !model.readOnly;
    final visibleItems = filtering ? itemsToBuy : allItems;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final textScaler = MediaQuery.textScalerOf(context);
    final compactAmounts = screenWidth < 360 || textScaler.scale(14) > 20;
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
                tooltip: 'Finalizar compra',
                onPressed: model.canEdit ? _openCheckout : null,
                icon: const Icon(Icons.fact_check_outlined),
              ),
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
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.medium),
                  child: Column(
                    children: [
                      if (model.isFinalized) const Text('Compra finalizada'),
                      const Text('Lista disponível somente para consulta.'),
                      if (model.shoppingList.budgetCents case final budget?
                          when model.isFinalized)
                        Text('Orçamento: ${formatListBudget(budget)}'),
                      if (model.shoppingList.checkoutPaidCents case final paid?)
                        Text(
                          'Valor cobrado no caixa: ${formatMoneyCents(paid)}',
                        ),
                    ],
                  ),
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
              if (model.hasLoaded && !model.readOnly)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.medium,
                  ),
                  child: Wrap(
                    spacing: AppSpacing.small,
                    children: [
                      ChoiceChip(
                        label: _filterLabel(
                          'Todos',
                          allItems.length,
                          showCount: !compactAmounts,
                        ),
                        selected: !_onlyToBuy,
                        onSelected: (_) => setState(() => _onlyToBuy = false),
                      ),
                      ChoiceChip(
                        label: _filterLabel(
                          'A comprar',
                          itemsToBuy.length,
                          showCount: !compactAmounts,
                        ),
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
                              ? filtering
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
                          final subtotalBelow =
                              compactAmounts ||
                              TextPainter.computeWidth(
                                    text: TextSpan(
                                      text: subtotal,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                    ),
                                    textDirection: Directionality.of(context),
                                    textScaler: textScaler,
                                  ) >
                                  screenWidth * .38;
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
                                  Text(
                                    model.isFinalized &&
                                            summary.status ==
                                                ItemPurchaseStatus.pending
                                        ? 'Não comprado'
                                        : purchaseStatusText(summary),
                                  ),
                                  if (subtotalBelow) Text(subtotal),
                                ],
                              ),
                              onTap: model.canEdit && item.removedAt == null
                                  ? () => _openForm(context, item)
                                  : null,
                              trailing: subtotalBelow
                                  ? model.readOnly
                                        ? null
                                        : const Icon(Icons.chevron_right)
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(subtotal),
                                        if (!model.readOnly)
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
                  if (model.hasRemovalToUndo)
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: AppSpacing.small,
                      children: [
                        Semantics(
                          liveRegion: true,
                          child: const Text('Produto removido.'),
                        ),
                        TextButton(
                          onPressed: model.canEdit ? _undoRemoval : null,
                          child: const Text('Desfazer'),
                        ),
                      ],
                    ),
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
                      remainingBudgetText(remaining),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: remaining < 0
                            ? Theme.of(context).colorScheme.error
                            : null,
                      ),
                    ),
                  if (!model.readOnly)
                    FilledButton.icon(
                      key: const ValueKey('add-item'),
                      onPressed: model.canEdit
                          ? () => _openForm(context)
                          : null,
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
