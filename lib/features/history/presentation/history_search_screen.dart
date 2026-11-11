import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/app_spacing.dart';
import '../../shopping/domain/models/history_product_match.dart';
import '../../shopping/domain/shopping_repository.dart';
import 'history_detail_screen.dart';
import 'history_entry_text.dart';

class HistorySearchScreen extends StatefulWidget {
  const HistorySearchScreen({super.key});

  @override
  State<HistorySearchScreen> createState() => _HistorySearchScreenState();
}

class _HistorySearchScreenState extends State<HistorySearchScreen> {
  final _input = TextEditingController();
  Future<List<HistoryProductMatch>?>? _results;

  void _search() {
    final name = _input.text.trim();
    final repository = context.read<ShoppingRepository>();
    FocusScope.of(context).unfocus();
    setState(() {
      _results = name.isEmpty
          ? null
          : repository
                .searchHistoryProducts(name)
                .then<List<HistoryProductMatch>?>(
                  (matches) => matches,
                  onError: (Object _, StackTrace _) => null,
                );
    });
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final labels = MaterialLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Buscar no histórico')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.medium),
              child: TextField(
                key: const ValueKey('history-search-input'),
                controller: _input,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                decoration: InputDecoration(
                  labelText: 'Nome do produto',
                  suffixIcon: IconButton(
                    tooltip: 'Buscar produto',
                    onPressed: _search,
                    icon: const Icon(Icons.search),
                  ),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<HistoryProductMatch>?>(
                future: _results,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.none) {
                    return const SizedBox.shrink();
                  }
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(
                      child: CircularProgressIndicator(
                        semanticsLabel: 'Buscando produtos',
                      ),
                    );
                  }
                  final results = snapshot.data;
                  if (results == null) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.medium),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Não foi possível buscar no histórico.'),
                            TextButton(
                              onPressed: _search,
                              child: const Text('Tentar novamente'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  if (results.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.medium),
                        child: Text('Nenhum produto encontrado no histórico.'),
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: results.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final result = results[index];
                      final date = labels.formatCompactDate(
                        result.finalizedAt.toLocal(),
                      );
                      return MergeSemantics(
                        child: ListTile(
                          key: ValueKey('history-product-${result.itemId}'),
                          title: Text(result.productName),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${result.listName} · $date'),
                              for (final entry in result.entries)
                                Text(historyEntryText(entry)),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  HistoryDetailScreen(listId: result.listId),
                            ),
                          ),
                        ),
                      );
                    },
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
