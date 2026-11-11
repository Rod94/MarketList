import '../../../core/money/money.dart';

int? parseListBudget(String input) => parseMoneyCents(input);

String formatListBudget(int cents) => formatMoneyCents(cents);

String remainingBudgetText(int cents) => switch (cents) {
  > 0 => '${formatMoneyCents(cents)} disponíveis',
  0 => 'Limite atingido',
  _ => '${formatMoneyCents(-cents)} acima do orçamento',
};
