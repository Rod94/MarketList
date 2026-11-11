import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/money/money.dart';
import '../../shopping/domain/models/shopping_list.dart';
import '../../shopping/domain/models/shopping_snapshot.dart';
import '../../shopping/domain/shopping_calculator.dart';
import '../../shopping/domain/shopping_repository.dart';
import '../data/history_spreadsheet_export.dart';
import '../history_status_text.dart';
import 'history_entry_text.dart';

class HistoryDetailScreen extends StatefulWidget {
  const HistoryDetailScreen({
    required this.listId,
    this.exportSpreadsheet = exportHistorySpreadsheet,
    super.key,
  });

  final String listId;
  final Future<bool> Function(ShoppingSnapshot, HistorySpreadsheetAction)
  exportSpreadsheet;

  @override
  State<HistoryDetailScreen> createState() => _HistoryDetailScreenState();
}

class _HistoryDetailScreenState extends State<HistoryDetailScreen> {
  late Future<ShoppingSnapshot> _detail;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _detail = _load();
  }

  Future<ShoppingSnapshot> _load() =>
      context.read<ShoppingRepository>().loadShoppingSnapshot(widget.listId);

  Future<void> _export(ShoppingSnapshot detail) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final action = await showModalBottomSheet<HistorySpreadsheetAction>(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.save_alt),
                title: const Text('Salvar arquivo'),
                onTap: () =>
                    Navigator.pop(context, HistorySpreadsheetAction.save),
              ),
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('Compartilhar arquivo'),
                onTap: () =>
                    Navigator.pop(context, HistorySpreadsheetAction.share),
              ),
            ],
          ),
        ),
      );
      if (!mounted || action == null) return;
      final completed = await widget.exportSpreadsheet(detail, action);
      if (mounted && completed && action == HistorySpreadsheetAction.save) {
        _showExportMessage('Planilha salva.');
      }
    } catch (_) {
      if (mounted) {
        _showExportMessage(
          'Não foi possível exportar a planilha. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _showExportMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Detalhes da compra')),
    body: SafeArea(
      child: FutureBuilder<ShoppingSnapshot>(
        future: _detail,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Carregando compra finalizada',
              ),
            );
          }
          final detail = snapshot.data;
          if (snapshot.error is ShoppingListNotFoundException ||
              (detail != null &&
                  detail.list.status != ShoppingListStatus.finalized)) {
            return const Center(
              child: Text('Compra finalizada não encontrada.'),
            );
          }
          if (detail == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.medium),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      liveRegion: true,
                      child: const Text(
                        'Não foi possível carregar os detalhes da compra.',
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _detail = _load();
                        });
                      },
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            );
          }

          final items = detail.calculation.items
              .where((summary) => summary.status != ItemPurchaseStatus.removed)
              .toList();
          final labels = MaterialLocalizations.of(context);
          final date = labels.formatFullDate(
            detail.list.finalizedAt!.toLocal(),
          );
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.medium),
            itemCount: items.length + 1,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (context, index) {
              if (index > 0) return _HistoryItem(summary: items[index - 1]);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    detail.list.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text('Finalizada em $date'),
                  const Text('Somente para consulta'),
                  const SizedBox(height: AppSpacing.medium),
                  Text(
                    'Total calculado: ${formatMoneyCents(detail.list.finalizedRegisteredTotalCents!)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (detail.list.budgetCents case final budget?)
                    Text('Orçamento: ${formatMoneyCents(budget)}'),
                  if (detail.list.checkoutPaidCents case final paid?)
                    Text('Valor pago no caixa: ${formatMoneyCents(paid)}'),
                  const SizedBox(height: AppSpacing.small),
                  OutlinedButton.icon(
                    onPressed: _exporting ? null : () => _export(detail),
                    icon: const Icon(Icons.file_download_outlined),
                    label: Text(
                      _exporting ? 'Exportando…' : 'Exportar planilha',
                    ),
                  ),
                  if (items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: AppSpacing.medium),
                      child: Text('Nenhum produto nesta compra.'),
                    ),
                ],
              );
            },
          );
        },
      ),
    ),
  );
}

class _HistoryItem extends StatelessWidget {
  const _HistoryItem({required this.summary});

  final ItemPurchaseSummary summary;

  @override
  Widget build(BuildContext context) {
    final status = summary.status;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.small),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              summary.item.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Text(historyStatusText(status)),
          if (summary.item.plannedQuantity case final planned?)
            Text('Planejado: $planned'),
          if (summary.purchasedQuantity case final purchased?
              when summary.entries.isNotEmpty)
            Text('Quantidade comprada: $purchased'),
          if (summary.purchasedQuantity == null &&
              summary.knownPurchasedQuantity > 0)
            Text('Unidades conhecidas: ${summary.knownPurchasedQuantity}'),
          if (summary.missingQuantity case final missing?
              when status == ItemPurchaseStatus.partial)
            Text('Faltaram: $missing'),
          if (summary.entries.isNotEmpty) ...[
            Text(
              'Subtotal do produto: ${formatMoneyCents(summary.subtotalCents)}',
            ),
            for (final entry in summary.entries)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.small),
                child: Text(historyEntryText(entry)),
              ),
          ],
        ],
      ),
    );
  }
}
