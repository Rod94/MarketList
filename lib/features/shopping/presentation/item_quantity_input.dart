int? parsePlannedQuantity(String input) {
  final value = input.trim();
  if (value.isEmpty) return null;
  final quantity = RegExp(r'^\d+$').hasMatch(value)
      ? int.tryParse(value)
      : null;
  if (quantity == null || quantity <= 0) {
    throw const FormatException(
      'Informe uma quantidade inteira maior que zero ou deixe em branco.',
    );
  }
  return quantity;
}
