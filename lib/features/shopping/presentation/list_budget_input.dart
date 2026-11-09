int? parseListBudget(String input) {
  final text = input.trim();
  if (text.isEmpty) return null;
  if (!RegExp(r'^\d+(?:,\d{1,2})?$').hasMatch(text)) {
    throw const FormatException('Use um valor como 250,00, sem pontos.');
  }
  final parts = text.split(',');
  final fraction = parts.length == 1 ? '00' : parts[1].padRight(2, '0');
  // Converter a string inteira evita overflow intermediário ao multiplicar.
  final cents = int.tryParse('${parts[0]}$fraction');
  if (cents == null) {
    throw const FormatException('O valor é grande demais para ser armazenado.');
  }
  return cents;
}

String formatListBudget(int cents) =>
    'R\$ ${cents ~/ 100},${(cents % 100).toString().padLeft(2, '0')}';
