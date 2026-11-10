import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../domain/models/shopping_item.dart';
import '../view_models/shopping_items_view_model.dart';
import '../widgets/item_form_sheet.dart';

class ShoppingScreen extends StatelessWidget {
  const ShoppingScreen({super.key});

  Future<void> _openForm(BuildContext context, [ShoppingItem? item]) async {
    final model = context.read<ShoppingItemsViewModel>();
    final started = item == null ? model.beginCreate() : model.beginEdit(item);
    if (!started) return;
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
          child: const ItemFormSheet(),
        ),
      );
      if (saved == true && context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Produto salvo.')));
      }
    } finally {
      model.clearDraft();
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<ShoppingItemsViewModel>();
    return PopScope(
      canPop: !model.isSaving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(model.shoppingList.name),
          actions: [
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
              Expanded(
                child: model.items.isEmpty
                    ? Center(
                        child: Text(
                          model.isLoading
                              ? 'Carregando produtos…'
                              : model.hasLoaded && model.loadError == null
                              ? 'Nenhum produto nesta lista.'
                              : '',
                        ),
                      )
                    : ListView.separated(
                        itemCount: model.items.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = model.items[index];
                          return ListTile(
                            key: ValueKey('item-${item.id}'),
                            title: Text(item.name),
                            subtitle: Text(
                              item.removedAt != null
                                  ? 'Removido'
                                  : item.plannedQuantity == null
                                  ? 'Pendente · Quantidade não informada'
                                  : 'Pendente · Planejado: ${item.plannedQuantity}',
                            ),
                            onTap: model.canEdit && item.removedAt == null
                                ? () => _openForm(context, item)
                                : null,
                            trailing: const Icon(Icons.chevron_right),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.medium),
            child: FilledButton.icon(
              key: const ValueKey('add-item'),
              onPressed: model.canEdit ? () => _openForm(context) : null,
              icon: const Icon(Icons.add),
              label: const Text('Adicionar produto'),
            ),
          ),
        ),
      ),
    );
  }
}
