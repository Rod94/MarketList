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
}
