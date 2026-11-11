import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/money/money.dart';
import 'history_detail_screen.dart';
import 'history_search_screen.dart';
import 'history_view_model.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final model = context.watch<HistoryViewModel>();
    final labels = MaterialLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico'),
        actions: [
          IconButton(
            tooltip: 'Buscar no histórico',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const HistorySearchScreen(),
              ),
            ),
            icon: const Icon(Icons.search),
          ),
          IconButton(
            tooltip: 'Atualizar histórico',
            onPressed: model.isLoading ? null : model.load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (model.isLoading)
              const LinearProgressIndicator(
                semanticsLabel: 'Carregando histórico',
              ),
            if (model.error case final error?)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.medium),
                child: Column(
                  children: [
                    Semantics(liveRegion: true, child: Text(error)),
                    TextButton(
                      onPressed: model.isLoading ? null : model.load,
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: model.lists.isEmpty
                  ? Center(
                      child: Text(
                        model.isLoading
                            ? 'Carregando histórico…'
                            : model.hasLoaded && model.error == null
                            ? 'Nenhuma compra finalizada.'
                            : '',
                      ),
                    )
                  : ListView.separated(
                      itemCount: model.lists.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final list = model.lists[index];
                        final date = list.finalizedAt!.toLocal();
                        final day = labels.formatCompactDate(date);
                        final time = labels.formatTimeOfDay(
                          TimeOfDay.fromDateTime(date),
                          alwaysUse24HourFormat: true,
                        );
                        return MergeSemantics(
                          child: ListTile(
                            key: ValueKey('history-${list.id}'),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    HistoryDetailScreen(listId: list.id),
                              ),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            title: Text(list.name),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Finalizada em $day às $time'),
                                Text(
                                  'Total registrado: ${formatMoneyCents(list.finalizedRegisteredTotalCents!)}',
                                ),
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
    );
  }
}
