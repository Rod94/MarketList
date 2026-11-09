import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../core/database/app_database.dart';
import '../core/preferences/theme_preference.dart';
import '../features/shopping/data/sqlite_shopping_repository.dart';
import '../features/shopping/domain/shopping_repository.dart';
import '../features/shopping/presentation/screens/shopping_lists_screen.dart';
import '../features/shopping/presentation/view_models/shopping_lists_view_model.dart';
import 'theme/app_theme.dart';
import 'theme/theme_view_model.dart';

class MarketListApp extends StatelessWidget {
  const MarketListApp({super.key, this.repository});

  final ShoppingRepository? repository;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ShoppingRepository>(
          create: (_) => repository ?? SqliteShoppingRepository(AppDatabase()),
        ),
        ChangeNotifierProvider(create: (_) => ThemeViewModel()),
        ChangeNotifierProvider(
          create: (context) =>
              ShoppingListsViewModel(context.read<ShoppingRepository>())
                ..load(),
        ),
      ],
      child: const _ThemedApp(),
    );
  }
}

class _ThemedApp extends StatelessWidget {
  const _ThemedApp();

  @override
  Widget build(BuildContext context) {
    final preference = context.watch<ThemeViewModel>().preference;

    return MaterialApp(
      title: 'MarketList',
      debugShowCheckedModeBanner: false,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: AppTheme.light,
      darkTheme: AppTheme.amoled,
      themeMode: switch (preference) {
        ThemePreference.system => ThemeMode.system,
        ThemePreference.light => ThemeMode.light,
        ThemePreference.amoled => ThemeMode.dark,
      },
      home: const ShoppingListsScreen(),
    );
  }
}
