import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:market_list/app/theme/theme_view_model.dart';
import 'package:market_list/core/preferences/theme_preference.dart';

void main() {
  late ThemeViewModel viewModel;

  setUp(() => viewModel = ThemeViewModel());
  tearDown(() => viewModel.dispose());

  test('F0-05: demonstração começa acompanhando o sistema', () {
    expect(viewModel.preference, ThemePreference.system);
  });

  test('F0-05: mudança de tema atualiza estado e notifica a interface', () {
    var notifications = 0;
    viewModel.addListener(() => notifications++);

    viewModel.selectTheme(ThemePreference.amoled);
    expect(viewModel.preference, ThemePreference.amoled);
    expect(notifications, 1);

    viewModel.selectTheme(ThemePreference.light);
    expect(viewModel.preference, ThemePreference.light);
    expect(notifications, 2);
  });

  test('F0-05: selecionar o mesmo tema não notifica novamente', () {
    var notifications = 0;
    viewModel.addListener(() => notifications++);

    viewModel.selectTheme(ThemePreference.system);

    expect(notifications, 0);
  });

  test(
    'D-033: só muda a aparência após persistir e protege contra toque duplo',
    () async {
      final pending = Completer<void>();
      final calls = <ThemePreference>[];
      final model = ThemeViewModel(
        persist: (preference) {
          calls.add(preference);
          return pending.future;
        },
      );
      addTearDown(model.dispose);
      final saving = model.selectTheme(ThemePreference.amoled);
      expect(model.isSaving, isTrue);
      expect(model.preference, ThemePreference.system);
      await model.selectTheme(ThemePreference.light);
      expect(calls, [ThemePreference.amoled]);
      pending.complete();
      await saving;
      expect(model.preference, ThemePreference.amoled);
      expect(model.isSaving, isFalse);
    },
  );

  test('D-033: falha preserva a aparência e permite tentar de novo', () async {
    var fail = true;
    final model = ThemeViewModel(
      initialPreference: ThemePreference.light,
      persist: (_) async {
        if (fail) throw StateError('falha');
      },
    );
    addTearDown(model.dispose);
    await model.selectTheme(ThemePreference.amoled);
    expect(model.preference, ThemePreference.light);
    expect(model.error, isNotNull);
    fail = false;
    await model.selectTheme(ThemePreference.amoled);
    expect(model.preference, ThemePreference.amoled);
    expect(model.error, isNull);
  });
}
