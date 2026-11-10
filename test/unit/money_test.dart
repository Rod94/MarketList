import 'package:flutter_test/flutter_test.dart';
import 'package:market_list/core/money/money.dart';

void main() {
  test('F3-01: converte vírgula e centavos sem ponto flutuante', () {
    expect(parseMoneyCents('4,22'), 422);
    expect(parseMoneyCents(' 0001,5 '), 150);
    expect(parseMoneyCents('12'), 1200);
    expect(parseMoneyCents('0,01'), 1);
    expect(parseMoneyCents('92233720368547758,07'), maxMoneyCents);
  });
  test('D-028: branco é ausente, zero é gratuito explícito', () {
    expect(parseMoneyCents(' \t '), isNull);
    expect(parseMoneyCents('0'), 0);
    expect(parseMoneyCents('0,00'), 0);
  });
  for (final invalid in [
    '-1',
    '+1',
    '1.000,00',
    '1.2',
    '1,234',
    '1,',
    ',50',
    'R\$ 4,22',
    'NaN',
    '1e3',
    '92233720368547758,08',
  ]) {
    test('formato/valor inválido: $invalid', () {
      expect(() => parseMoneyCents(invalid), throwsFormatException);
    });
  }
  test(
    'formata zero, frações, extremos e diferenças negativas sem overflow',
    () {
      expect(formatMoneyCents(0), 'R\$ 0,00');
      expect(formatMoneyCents(422), 'R\$ 4,22');
      expect(formatMoneyCents(-1), '-R\$ 0,01');
      expect(formatMoneyCents(maxMoneyCents), 'R\$ 92233720368547758,07');
      expect(
        formatMoneyCents(-9223372036854775808),
        '-R\$ 92233720368547758,08',
      );
    },
  );
  test('roundtrip exato em amostra determinística de centavos', () {
    for (final value in [
      0,
      1,
      10,
      20,
      30,
      99,
      100,
      422,
      1890,
      52780,
      maxMoneyCents,
    ]) {
      expect(parseMoneyCents(formatMoneyCents(value).substring(3)), value);
    }
  });
  test('CT-026: soma exata e agregado vazio zero', () {
    expect(checkedMoneySum([10, 20]), 30);
    expect(checkedMoneySum([]), 0);
    expect(checkedMoneySum([maxMoneyCents, 0]), maxMoneyCents);
    expect(() => checkedMoneySum([maxMoneyCents, 1]), throwsRangeError);
    expect(() => checkedMoneySum([-1, 2]), throwsRangeError);
  });
  test('CT-008: produto exato; gratuito não vira ausência', () {
    expect(checkedMoneyProduct(3, 422), 1266);
    expect(checkedMoneyProduct(maxMoneyCents, 0), 0);
    expect(checkedMoneyProduct(1, maxMoneyCents), maxMoneyCents);
    expect(() => checkedMoneyProduct(2, maxMoneyCents), throwsRangeError);
    expect(() => checkedMoneyProduct(0, 100), throwsArgumentError);
    expect(() => checkedMoneyProduct(-1, 100), throwsArgumentError);
    expect(() => checkedMoneyProduct(1, -1), throwsRangeError);
  });
}
