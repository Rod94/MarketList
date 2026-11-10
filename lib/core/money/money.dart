const maxMoneyCents = 9223372036854775807;
final _maxMoney = BigInt.from(maxMoneyCents);

int? parseMoneyCents(String input) {
  final text = input.trim();
  if (text.isEmpty) return null;
  if (!RegExp(r'^\d+(?:,\d{1,2})?$').hasMatch(text)) {
    throw const FormatException('Use um valor como 250,00, sem pontos.');
  }
  final parts = text.split(',');
  final fraction = parts.length == 1 ? '00' : parts[1].padRight(2, '0');
  final cents = int.tryParse('${parts[0]}$fraction');
  if (cents == null || cents < 0) {
    throw const FormatException('O valor é grande demais para ser armazenado.');
  }
  return cents;
}

String formatMoneyCents(int cents) {
  // abs() de int64 mínimo pode continuar negativo; BigInt evita esse overflow.
  final amount = BigInt.from(cents).abs();
  final whole = amount ~/ BigInt.from(100);
  final fraction = (amount % BigInt.from(100)).toString().padLeft(2, '0');
  return '${cents < 0 ? '-' : ''}R\$ $whole,$fraction';
}

void validateMoneyCents(int cents) {
  if (cents < 0 || cents > maxMoneyCents) {
    throw RangeError(
      'Valores monetários devem ser centavos não negativos representáveis em 64 bits.',
    );
  }
}

int checkedMoneySum(Iterable<int> values) {
  var total = BigInt.zero;
  for (final value in values) {
    validateMoneyCents(value);
    total += BigInt.from(value);
  }
  return _toMoneyCents(total);
}

int checkedMoneyProduct(int quantity, int unitPriceCents) {
  if (quantity <= 0) {
    throw ArgumentError.value(
      quantity,
      'quantity',
      'A quantidade deve ser maior que zero.',
    );
  }
  validateMoneyCents(unitPriceCents);
  return _toMoneyCents(BigInt.from(quantity) * BigInt.from(unitPriceCents));
}

int _toMoneyCents(BigInt value) {
  if (value < BigInt.zero || value > _maxMoney) {
    throw RangeError(
      'O resultado é grande demais para ser armazenado em centavos.',
    );
  }
  return value.toInt();
}
