enum ShoppingListStatus { active, finalized }

final class ShoppingList {
  ShoppingList({
    required this.id,
    required String name,
    required DateTime createdAt,
    this.status = ShoppingListStatus.active,
    DateTime? finalizedAt,
    this.budgetCents,
    this.finalizedRegisteredTotalCents,
    this.checkoutPaidCents,
  }) : name = name.trim(),
       createdAt = createdAt.toUtc(),
       finalizedAt = finalizedAt?.toUtc() {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(
        id,
        'id',
        'O identificador não pode ser vazio.',
      );
    }
    if (this.name.isEmpty) {
      throw ArgumentError.value(name, 'name', 'O nome não pode ser vazio.');
    }

    _validateCents(budgetCents, 'budgetCents');
    _validateCents(
      finalizedRegisteredTotalCents,
      'finalizedRegisteredTotalCents',
    );
    _validateCents(checkoutPaidCents, 'checkoutPaidCents');

    if (status == ShoppingListStatus.active) {
      if (this.finalizedAt != null ||
          finalizedRegisteredTotalCents != null ||
          checkoutPaidCents != null) {
        throw ArgumentError(
          'Uma lista ativa não pode ter dados de finalização.',
        );
      }
    } else {
      final completion = this.finalizedAt;
      if (completion == null || finalizedRegisteredTotalCents == null) {
        throw ArgumentError(
          'Uma lista finalizada exige data e total calculado.',
        );
      }
      if (completion.isBefore(this.createdAt)) {
        throw ArgumentError.value(
          finalizedAt,
          'finalizedAt',
          'A finalização não pode ser anterior à criação.',
        );
      }
    }
  }

  final String id;
  final String name;
  final DateTime createdAt;
  final ShoppingListStatus status;
  final DateTime? finalizedAt;
  final int? budgetCents;
  final int? finalizedRegisteredTotalCents;
  final int? checkoutPaidCents;

  static void _validateCents(int? value, String field) {
    if (value != null && value < 0) {
      throw ArgumentError.value(value, field, 'O valor não pode ser negativo.');
    }
  }
}
