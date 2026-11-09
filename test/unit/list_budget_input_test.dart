import 'package:flutter_test/flutter_test.dart';
import 'package:market_list/features/shopping/presentation/list_budget_input.dart';

void main() {
  test('F1-04: orçamento vazio é ausente, zero é explícito', () {
    expect(parseListBudget('  '), isNull);
    expect(parseListBudget('0'), 0);
    expect(parseListBudget('0,00'), 0);
  });

  test('F1-04: orçamento vira centavos exatos sem double', () {
    expect(parseListBudget(' 250,01 '), 25001);
    expect(parseListBudget('12,3'), 1230);
    expect(parseListBudget('100'), 10000);
    expect(parseListBudget('0001,05'), 105);
  });

  for (final invalid in ['-1', 'abc', '1.000,00', '1,001', '1,', ',50']) {
    test('F1-04: orçamento inválido $invalid', () {
      expect(() => parseListBudget(invalid), throwsFormatException);
    });
  }

  test('F1-04: capacidade inteira não pode causar overflow silencioso', () {
    expect(parseListBudget('92233720368547758,07'), 9223372036854775807);
    expect(
      () => parseListBudget('92233720368547758,08'),
      throwsFormatException,
    );
  });

  test('F1-04: exibição do orçamento preserva centavos e zero', () {
    expect(formatListBudget(25001), 'R\$ 250,01');
    expect(formatListBudget(0), 'R\$ 0,00');
    expect(formatListBudget(9223372036854775807), 'R\$ 92233720368547758,07');
  });
}
