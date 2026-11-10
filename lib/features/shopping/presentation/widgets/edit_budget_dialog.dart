import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../list_budget_input.dart';
import '../view_models/shopping_items_view_model.dart';

class EditBudgetDialog extends StatefulWidget {
  const EditBudgetDialog({super.key});

  @override
  State<EditBudgetDialog> createState() => _EditBudgetDialogState();
}

class _EditBudgetDialogState extends State<EditBudgetDialog> {
  late final TextEditingController _amount;
  String? _error;

  @override
  void initState() {
    super.initState();
    final budget = context
        .read<ShoppingItemsViewModel>()
        .shoppingList
        .budgetCents;
    _amount = TextEditingController(
      text: budget == null ? '' : formatListBudget(budget).substring(3),
    );
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final model = context.read<ShoppingItemsViewModel>();
    if (!model.canEdit) return;
    final error = await model.saveBudget(_amount.text);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<ShoppingItemsViewModel>();
    return PopScope(
      canPop: !model.isSaving,
      child: AlertDialog(
        scrollable: true,
        title: const Text('Orçamento'),
        content: TextField(
          key: const ValueKey('edit-budget'),
          controller: _amount,
          autofocus: true,
          enabled: !model.isSaving,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _save(),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          decoration: InputDecoration(
            labelText: 'Orçamento (opcional)',
            prefixText: 'R\$ ',
            helperText: 'Deixe vazio para retirar.',
            errorText: _error,
            errorMaxLines: 3,
          ),
        ),
        actions: [
          TextButton(
            onPressed: model.isSaving
                ? null
                : () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: model.canEdit ? _save : null,
            child: Text(model.isSaving ? 'Salvando…' : 'Salvar orçamento'),
          ),
        ],
      ),
    );
  }
}
