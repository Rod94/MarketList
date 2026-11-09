import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme/app_spacing.dart';
import '../view_models/shopping_lists_view_model.dart';

class CreateListSheet extends StatefulWidget {
  const CreateListSheet({super.key});

  @override
  State<CreateListSheet> createState() => _CreateListSheetState();
}

class _CreateListSheetState extends State<CreateListSheet> {
  late final TextEditingController _name;
  late final TextEditingController _budget;

  @override
  void initState() {
    super.initState();
    final viewModel = context.read<ShoppingListsViewModel>();
    _name = TextEditingController(text: viewModel.draftName);
    _budget = TextEditingController(text: viewModel.draftBudget);
  }

  @override
  void dispose() {
    _name.dispose();
    _budget.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final saved = await context.read<ShoppingListsViewModel>().saveDraft();
    if (saved && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ShoppingListsViewModel>();
    return PopScope(
      canPop: !viewModel.isSaving,
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
                        'Nova lista',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.medium),
                      TextField(
                        key: const ValueKey('new-list-name'),
                        controller: _name,
                        autofocus: true,
                        enabled: !viewModel.isSaving,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.next,
                        onChanged: viewModel.setDraftName,
                        decoration: InputDecoration(
                          labelText: 'Nome da lista',
                          hintText: 'Ex.: Compra da semana',
                          errorText: viewModel.nameError,
                          errorMaxLines: 3,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.medium),
                      TextField(
                        key: const ValueKey('new-list-budget'),
                        controller: _budget,
                        enabled: !viewModel.isSaving,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.done,
                        onChanged: viewModel.setDraftBudget,
                        onSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Orçamento (opcional)',
                          hintText: 'Ex.: 250,00',
                          prefixText: 'R\$ ',
                          errorText: viewModel.budgetError,
                          errorMaxLines: 3,
                        ),
                      ),
                      if (viewModel.isSaving) ...[
                        const SizedBox(height: AppSpacing.medium),
                        const LinearProgressIndicator(
                          semanticsLabel: 'Salvando lista',
                        ),
                      ],
                      if (viewModel.saveError != null) ...[
                        const SizedBox(height: AppSpacing.medium),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            viewModel.saveError!,
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
              Padding(
                padding: const EdgeInsets.all(AppSpacing.medium),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        key: const ValueKey('cancel-list'),
                        onPressed: viewModel.isSaving
                            ? null
                            : () => Navigator.pop(context, false),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.small),
                    Expanded(
                      child: FilledButton(
                        key: const ValueKey('save-list'),
                        onPressed: viewModel.isSaving ? null : _submit,
                        child: Text(
                          viewModel.isSaving ? 'Salvando…' : 'Criar lista',
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
