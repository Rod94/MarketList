import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme/app_spacing.dart';
import '../view_models/shopping_items_view_model.dart';

enum ItemFormResult { saved, removed }

class ItemFormSheet extends StatefulWidget {
  const ItemFormSheet({super.key});
  @override
  State<ItemFormSheet> createState() => _ItemFormSheetState();
}

class _ItemFormSheetState extends State<ItemFormSheet> {
  late final TextEditingController _name;
  late final TextEditingController _quantity;

  @override
  void initState() {
    super.initState();
    final model = context.read<ShoppingItemsViewModel>();
    _name = TextEditingController(text: model.draftName);
    _quantity = TextEditingController(text: model.draftQuantity);
  }

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
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

  @override
  Widget build(BuildContext context) {
    final model = context.watch<ShoppingItemsViewModel>();
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
                        autofocus: true,
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
                        textInputAction: TextInputAction.done,
                        onChanged: model.setDraftQuantity,
                        onSubmitted: (_) => _save(),
                        decoration: InputDecoration(
                          labelText: 'Quantidade planejada (opcional)',
                          hintText: 'Ex.: 5',
                          errorText: model.quantityError,
                          errorMaxLines: 4,
                        ),
                      ),
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
                          model.isSaving ? 'Salvando…' : 'Salvar produto',
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
