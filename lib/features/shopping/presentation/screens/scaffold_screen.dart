import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/theme_view_model.dart';
import '../../../../core/preferences/theme_preference.dart';

class ScaffoldScreen extends StatelessWidget {
  const ScaffoldScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewModel = context.watch<ThemeViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('MarketList')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.medium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Aparência', style: theme.textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.small),
              Text(
                'Escolha a aparência do aplicativo.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.large),
              InputDecorator(
                decoration: const InputDecoration(labelText: 'Tema'),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<ThemePreference>(
                    value: viewModel.preference,
                    isExpanded: true,
                    itemHeight: null,
                    items: [
                      for (final preference in ThemePreference.values)
                        DropdownMenuItem(
                          value: preference,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              minHeight: AppSpacing.minimumTouchTarget,
                            ),
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(switch (preference) {
                                ThemePreference.system => 'Sistema',
                                ThemePreference.light => 'Claro',
                                ThemePreference.amoled => 'AMOLED',
                              }),
                            ),
                          ),
                        ),
                    ],
                    onChanged: viewModel.isSaving
                        ? null
                        : (preference) {
                            if (preference != null) {
                              viewModel.selectTheme(preference);
                            }
                          },
                  ),
                ),
              ),
              if (viewModel.error case final error?)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    error,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
