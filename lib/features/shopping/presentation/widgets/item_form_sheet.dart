import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/money/money.dart';
import '../../domain/models/purchase_entry.dart';
import '../purchase_status_text.dart';
import '../view_models/shopping_items_view_model.dart';
import 'purchase_entry_sheet.dart';

enum ItemFormResult { saved, removed }

class ItemFormSheet extends StatefulWidget {
  const ItemFormSheet({super.key});
  @override
  State<ItemFormSheet> createState() => _ItemFormSheetState();
}

class _ItemFormSheetState extends State<ItemFormSheet> {
  late final TextEditingController _name;
  late final TextEditingController _quantity;
  late final TextEditingController _price;

  @override
  void initState() {
    super.initState();
    final model = context.read<ShoppingItemsViewModel>();
    _name = TextEditingController(text: model.draftName);
    _quantity = TextEditingController(text: model.draftQuantity);
    _price = TextEditingController(text: model.draftPrice);
  }

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final saved = await context.read<ShoppingItemsViewModel>().saveDraft();
    if (saved && mounted) Navigator.pop(context, ItemFormResult.saved);
  }

  Future<void> _remove() async {
    final removed = await context
        .read<ShoppingItemsViewModel>()
        .removeEditingItem();
    if (removed && mounted) Navigator.pop(context, ItemFormResult.removed);
  }

  Future<void> _openPurchase([PurchaseEntry? entry]) async {
    final model = context.read<ShoppingItemsViewModel>();
    final item = model.editingItem;
    if (item == null || !model.beginPurchase(item, entry: entry)) return;
    try {
      final saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        useSafeArea: true,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        builder: (_) => ChangeNotifierProvider.value(
          value: model,
          child: const PurchaseEntrySheet(),
        ),
      );
      if (saved == true && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Entrada confirmada.')));
      }
    } finally {
      model.clearPurchaseDraft();
    }
  }

  Future<void> _removeEntry(PurchaseEntry entry) async {
    final removed = await context.read<ShoppingItemsViewModel>().removeEntry(
      entry,
    );
    if (removed && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Entrada excluída.')));
    }
  }

  Widget _entries(ShoppingItemsViewModel model) {
    final summary = model.summaryFor(model.editingItem!.id);
    if (summary == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.medium),
        const Divider(),
        Text(
          'Compra registrada',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(purchaseStatusText(summary)),
        Text('Subtotal confirmado: ${formatMoneyCents(summary.subtotalCents)}'),
        for (var index = 0; index < summary.entries.length; index++)
          Builder(
            builder: (context) {
              final entry = summary.entries[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  entry.isDirect
                      ? 'Valor total: ${formatMoneyCents(entry.directAmountCents!)}'
                      : '${entry.quantity} × ${formatMoneyCents(entry.unitPriceCents!)}',
                ),
                subtitle: Text(
                  'Subtotal: ${formatMoneyCents(entry.subtotalCents)}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Editar preço ${index + 1}',
                      onPressed: model.canEdit
                          ? () => _openPurchase(entry)
                          : null,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'Excluir preço ${index + 1}',
                      onPressed: model.canEdit
                          ? () => _removeEntry(entry)
                          : null,
                      icon: model.removingEntryId == entry.id
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              );
            },
          ),
        TextButton.icon(
          onPressed: model.canEdit ? () => _openPurchase() : null,
          icon: const Icon(Icons.add),
          label: Text(
            summary.entries.isEmpty
                ? 'Registrar preço'
                : 'Adicionar outro preço',
          ),
        ),
        if (model.purchaseError != null)
          Semantics(
            liveRegion: true,
            child: Text(
              model.purchaseError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<ShoppingItemsViewModel>();
    final adding = model.editingItem == null;
    final preview = adding ? model.quickPreviewCents : null;
    return PopScope(
      canPop: !model.isSaving,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.medium),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        model.editingItem == null
                            ? 'Adicionar produto'
                            : 'Editar produto',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.medium),
                      TextField(
                        key: const ValueKey('item-name'),
                        controller: _name,
                        autofocus: model.editingItem == null,
                        enabled: !model.isSaving && !model.readOnly,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.next,
                        onChanged: model.setDraftName,
                        decoration: InputDecoration(
                          labelText: 'Produto',
                          hintText: 'Ex.: Arroz 5 kg',
                          errorText: model.nameError,
                          errorMaxLines: 3,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.medium),
                      TextField(
                        key: const ValueKey('item-quantity'),
                        controller: _quantity,
                        enabled: !model.isSaving && !model.readOnly,
                        keyboardType: TextInputType.number,
                        textInputAction: adding
                            ? TextInputAction.next
                            : TextInputAction.done,
                        onChanged: model.setDraftQuantity,
                        onSubmitted: adding ? null : (_) => _save(),
                        decoration: InputDecoration(
                          labelText: adding && model.draftHasPrice
                              ? 'Quantidade comprada (opcional)'
                              : 'Quantidade planejada (opcional)',
                          hintText: 'Ex.: 5',
                          errorText: model.quantityError,
                          errorMaxLines: 4,
                        ),
                      ),
                      if (adding) ...[
                        const SizedBox(height: AppSpacing.medium),
                        TextField(
                          key: const ValueKey('item-price'),
                          controller: _price,
                          enabled: !model.isSaving && !model.readOnly,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textInputAction: TextInputAction.done,
                          onChanged: model.setDraftPrice,
                          onSubmitted: (_) => _save(),
                          decoration: InputDecoration(
                            labelText: model.draftQuantity.trim().isEmpty
                                ? 'Valor total (opcional)'
                                : 'Preço unitário (opcional)',
                            prefixText: 'R\$ ',
                            errorText: model.draftPriceError,
                            errorMaxLines: 3,
                          ),
                        ),
                        if (preview != null)
                          Text(
                            'Prévia do subtotal: ${formatMoneyCents(preview)}',
                          ),
                      ],
                      if (model.editingItem != null) _entries(model),
                      if (model.isSaving)
                        LinearProgressIndicator(
                          semanticsLabel: model.isRemoving
                              ? 'Removendo produto'
                              : 'Salvando produto',
                        ),
                      if (model.saveError != null) ...[
                        const SizedBox(height: AppSpacing.medium),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            model.saveError!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (model.editingItem != null)
                TextButton.icon(
                  key: const ValueKey('remove-item'),
                  onPressed: model.isSaving || model.readOnly ? null : _remove,
                  icon: const Icon(Icons.delete_outline),
                  label: Text(
                    model.isRemoving ? 'Removendo…' : 'Remover produto',
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.medium),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        key: const ValueKey('cancel-item'),
                        onPressed: model.isSaving
                            ? null
                            : () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.small),
                    Expanded(
                      child: FilledButton(
                        key: const ValueKey('save-item'),
                        onPressed: model.isSaving || model.readOnly
                            ? null
                            : _save,
                        child: Text(
                          model.isSaving
                              ? 'Salvando…'
                              : model.editingItem == null
                              ? 'Salvar produto'
                              : 'Salvar planejamento',
                        ),
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
