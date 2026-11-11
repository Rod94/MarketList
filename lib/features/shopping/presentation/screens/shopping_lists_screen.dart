import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../history/presentation/history_screen.dart';
import '../../../history/presentation/history_view_model.dart';
import '../../domain/models/shopping_list.dart';
import '../../domain/shopping_repository.dart';
import '../list_budget_input.dart';
import '../view_models/shopping_lists_view_model.dart';
import '../view_models/shopping_items_view_model.dart';
import '../widgets/create_list_sheet.dart';
import 'scaffold_screen.dart';
import 'shopping_screen.dart';

class ShoppingListsScreen extends StatelessWidget {
  const ShoppingListsScreen({super.key});

  Future<void> _createList(BuildContext context) async {
    final viewModel = context.read<ShoppingListsViewModel>();
    if (!viewModel.canEditLists) return;
    try {
      final created = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        useSafeArea: true,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        builder: (_) => const CreateListSheet(),
      );
      if (created == true && context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Lista criada.')));
      }
    } finally {
      viewModel.clearDraft();
    }
  }

  Future<void> _deleteList(BuildContext context, ShoppingList list) async {
    final viewModel = context.read<ShoppingListsViewModel>();
    if (!viewModel.canEditLists) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: Text('Excluir “${list.name}”?'),
        content: const Text('Esta lista e seu conteúdo serão excluídos.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final removed = await viewModel.removeList(list.id);
    if (!context.mounted) return;
    final message =
        viewModel.deleteError ??
        (removed ? 'Lista excluída.' : 'Esta lista não está mais disponível.');
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ShoppingListsViewModel>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas listas'),
        actions: [
          IconButton(
            tooltip: 'Histórico',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ChangeNotifierProvider(
                  create: (_) =>
                      HistoryViewModel(context.read<ShoppingRepository>())
                        ..load(),
                  child: const HistoryScreen(),
                ),
              ),
            ),
            icon: const Icon(Icons.history),
          ),
          IconButton(
            tooltip: 'Atualizar listas',
            onPressed: viewModel.isBusy ? null : viewModel.load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Aparência',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ScaffoldScreen()),
            ),
            icon: const Icon(Icons.contrast),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (viewModel.isLoading)
              const LinearProgressIndicator(
                semanticsLabel: 'Carregando listas',
              ),
            if (viewModel.loadError != null)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.medium),
                child: Column(
                  children: [
                    Semantics(
                      liveRegion: true,
                      child: Text(viewModel.loadError!),
                    ),
                    TextButton(
                      onPressed: viewModel.isBusy ? null : viewModel.load,
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: viewModel.lists.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.medium),
                        child: Text(
                          viewModel.isLoading
                              ? 'Carregando listas…'
                              : viewModel.hasLoaded &&
                                    viewModel.loadError == null
                              ? 'Nenhuma lista em andamento.'
                              : '',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.small,
                      ),
                      itemCount: viewModel.lists.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final list = viewModel.lists[index];
                        final local = list.createdAt.toLocal();
                        final labels = MaterialLocalizations.of(context);
                        final date = labels.formatCompactDate(local);
                        final time = labels.formatTimeOfDay(
                          TimeOfDay.fromDateTime(local),
                          alwaysUse24HourFormat: true,
                        );
                        return ListTile(
                          onTap: viewModel.canEditLists
                              ? () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => ChangeNotifierProvider(
                                        create: (_) => ShoppingItemsViewModel(
                                          context.read<ShoppingRepository>(),
                                          list,
                                        )..load(),
                                        child: const ShoppingScreen(),
                                      ),
                                    ),
                                  );
                                  if (context.mounted) await viewModel.load();
                                }
                              : null,
                          title: Text(list.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Em andamento'),
                              Text('Criada em $date às $time'),
                              if (list.budgetCents != null)
                                Text(
                                  'Orçamento: ${formatListBudget(list.budgetCents!)}',
                                ),
                            ],
                          ),
                          trailing: viewModel.removingId == list.id
                              ? const SizedBox.square(
                                  dimension: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    semanticsLabel: 'Excluindo lista',
                                  ),
                                )
                              : IconButton(
                                  tooltip: 'Excluir lista ${list.name}',
                                  onPressed: viewModel.canEditLists
                                      ? () => _deleteList(context, list)
                                      : null,
                                  icon: const Icon(Icons.delete_outline),
                                ),
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
            onPressed: viewModel.canEditLists
                ? () => _createList(context)
                : null,
            icon: const Icon(Icons.add),
            label: const Text('Nova lista'),
          ),
        ),
      ),
    );
  }
}
