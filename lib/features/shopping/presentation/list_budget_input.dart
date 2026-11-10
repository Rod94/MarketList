import '../../../core/money/money.dart';

int? parseListBudget(String input) => parseMoneyCents(input);

String formatListBudget(int cents) => formatMoneyCents(cents);
