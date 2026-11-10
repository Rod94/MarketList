import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/money/money.dart';
import '../view_models/shopping_items_view_model.dart';

class PurchaseEntrySheet extends StatefulWidget {
  const PurchaseEntrySheet({super.key});
  @override
  State<PurchaseEntrySheet> createState() => _PurchaseEntrySheetState();
}

class _PurchaseEntrySheetState extends State<PurchaseEntrySheet> {
  late final TextEditingController _quantity;
  late final TextEditingController _price;
  @override
  void initState() {
    super.initState();
    final model = context.read<ShoppingItemsViewModel>();
    _quantity = TextEditingController(text: model.purchaseQuantity);
    _price = TextEditingController(text: model.purchasePrice);
  }

  @override
  void dispose() {
    _quantity.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final saved = await context
        .read<ShoppingItemsViewModel>()
        .savePurchaseDraft();
    if (saved && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<ShoppingItemsViewModel>();
    final preview = model.purchasePreviewCents;
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
                        model.editingPurchase == null
                            ? 'Registrar preço'
                            : 'Corrigir entrada',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.medium),
                      TextField(
                        key: const ValueKey('purchase-quantity'),
                        controller: _quantity,
                        autofocus: true,
                        enabled: !model.isSaving && !model.readOnly,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        onChanged: model.setPurchaseQuantity,
                        decoration: InputDecoration(
                          labelText: 'Quantidade comprada (opcional)',
                          hintText: 'Sem quantidade: informe o valor total',
                          errorText: model.purchaseQuantityError,
                          errorMaxLines: 4,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.medium),
                      TextField(
                        key: const ValueKey('purchase-price'),
                        controller: _price,
                        enabled: !model.isSaving && !model.readOnly,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.done,
                        onChanged: model.setPurchasePrice,
                        onSubmitted: (_) => _save(),
                        decoration: InputDecoration(
                          labelText: model.purchasePriceLabel,
                          hintText: 'Ex.: 4,22',
                          errorText: model.purchasePriceError,
                          errorMaxLines: 4,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.medium),
                      Text(
                        preview == null
                            ? 'A prévia aparece ao preencher um valor válido.'
                            : 'Prévia do subtotal: ${formatMoneyCents(preview)}',
                      ),
                      if (model.isSaving)
                        const LinearProgressIndicator(
                          semanticsLabel: 'Gravando entrada',
                        ),
                      if (model.purchaseError != null)
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            model.purchaseError!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
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
                        key: const ValueKey('cancel-purchase'),
                        onPressed: model.isSaving
                            ? null
                            : () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.small),
                    Expanded(
                      child: FilledButton(
                        key: const ValueKey('save-purchase'),
                        onPressed: model.isSaving || model.readOnly
                            ? null
                            : _save,
                        child: Text(
                          model.isSaving ? 'Gravando…' : 'Confirmar entrada',
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
