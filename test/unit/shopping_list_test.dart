import 'package:flutter_test/flutter_test.dart';
import 'package:market_list/features/shopping/domain/models/shopping_list.dart';

void main() {
  final createdAt = DateTime.utc(2026, 11, 9, 12);
  final finalizedAt = DateTime.utc(2026, 11, 9, 14);

  group('F1-01 / CT-001 (domínio): identificação e criação', () {
    test('cria lista ativa com identidade e nome, sem valores implícitos', () {
      final list = ShoppingList(
        id: 'list-001',
        name: 'Compra da semana',
        createdAt: createdAt,
      );

      expect(list.id, 'list-001');
      expect(list.name, 'Compra da semana');
      expect(list.createdAt, createdAt);
      expect(list.status, ShoppingListStatus.active);
      expect(list.finalizedAt, isNull);
      expect(list.budgetCents, isNull);
      expect(list.finalizedRegisteredTotalCents, isNull);
      expect(list.checkoutPaidCents, isNull);
    });

    test('remove espaços externos do nome sem alterar ID ou texto interno', () {
      final list = ShoppingList(
        id: 'opaque-ID-001',
        name: '  Compra  da semana  ',
        createdAt: createdAt,
      );

      expect(list.id, 'opaque-ID-001');
      expect(list.name, 'Compra  da semana');
    });

    for (final invalid in ['', '   ', '\t\n']) {
      test('rejeita ID vazio ${invalid.codeUnits}', () {
        expect(
          () => ShoppingList(id: invalid, name: 'Compra', createdAt: createdAt),
          throwsArgumentError,
        );
      });

      test('rejeita nome vazio ${invalid.codeUnits}', () {
        expect(
          () =>
              ShoppingList(id: 'list-001', name: invalid, createdAt: createdAt),
          throwsArgumentError,
        );
      });
    }
  });

  group('F1-01: datas UTC', () {
    test('normaliza criação local para UTC preservando o instante', () {
      final local = DateTime(2026, 11, 9, 9, 30);
      final list = ShoppingList(
        id: 'list-001',
        name: 'Compra',
        createdAt: local,
      );

      expect(list.createdAt.isUtc, isTrue);
      expect(list.createdAt.isAtSameMomentAs(local), isTrue);
    });

    test('normaliza finalização local para UTC preservando o instante', () {
      final local = DateTime(2026, 11, 9, 10, 30);
      final list = ShoppingList(
        id: 'list-001',
        name: 'Compra',
        createdAt: local.subtract(const Duration(hours: 1)),
        status: ShoppingListStatus.finalized,
        finalizedAt: local,
        finalizedRegisteredTotalCents: 0,
      );

      expect(list.createdAt.isUtc, isTrue);
      expect(list.finalizedAt!.isUtc, isTrue);
      expect(list.finalizedAt!.isAtSameMomentAs(local), isTrue);
    });
  });

  group('F1-01: coerência do estado armazenável', () {
    test('lista finalizada exige data e total calculado', () {
      expect(
        () => ShoppingList(
          id: 'list-001',
          name: 'Compra',
          createdAt: createdAt,
          status: ShoppingListStatus.finalized,
          finalizedRegisteredTotalCents: 100,
        ),
        throwsArgumentError,
      );
      expect(
        () => ShoppingList(
          id: 'list-001',
          name: 'Compra',
          createdAt: createdAt,
          status: ShoppingListStatus.finalized,
          finalizedAt: finalizedAt,
        ),
        throwsArgumentError,
      );
    });

    test('lista ativa não aceita data de finalização', () {
      expect(
        () => ShoppingList(
          id: 'list-001',
          name: 'Compra',
          createdAt: createdAt,
          finalizedAt: finalizedAt,
        ),
        throwsArgumentError,
      );
    });

    test('lista ativa não aceita total final', () {
      expect(
        () => ShoppingList(
          id: 'list-001',
          name: 'Compra',
          createdAt: createdAt,
          finalizedRegisteredTotalCents: 0,
        ),
        throwsArgumentError,
      );
    });

    test('lista ativa não aceita valor do caixa como dado confirmado', () {
      expect(
        () => ShoppingList(
          id: 'list-001',
          name: 'Compra',
          createdAt: createdAt,
          checkoutPaidCents: 100,
        ),
        throwsArgumentError,
      );
    });

    test('não aceita finalização anterior à criação', () {
      expect(
        () => ShoppingList(
          id: 'list-001',
          name: 'Compra',
          createdAt: createdAt,
          status: ShoppingListStatus.finalized,
          finalizedAt: createdAt.subtract(const Duration(microseconds: 1)),
          finalizedRegisteredTotalCents: 0,
        ),
        throwsArgumentError,
      );
    });

    test(
      'aceita mesma data de criação e finalização sem exigir valor do caixa',
      () {
        final list = ShoppingList(
          id: 'list-001',
          name: 'Compra',
          createdAt: createdAt,
          status: ShoppingListStatus.finalized,
          finalizedAt: createdAt,
          finalizedRegisteredTotalCents: 0,
        );

        expect(list.status, ShoppingListStatus.finalized);
        expect(list.finalizedRegisteredTotalCents, 0);
        expect(list.checkoutPaidCents, isNull);
      },
    );
  });

  group('F1-01 / D-019 / D-020: valores em centavos', () {
    test('preserva orçamento, calculado e caixa diferentes, sem bloquear excedente', () {
      final list = ShoppingList(
        id: 'list-001',
        name: 'Compra',
        createdAt: createdAt,
        status: ShoppingListStatus.finalized,
        finalizedAt: finalizedAt,
        budgetCents: 50000,
        finalizedRegisteredTotalCents: 52780,
        checkoutPaidCents: 53020,
      );

      expect(list.budgetCents, 50000);
      expect(list.finalizedRegisteredTotalCents, 52780);
      expect(list.checkoutPaidCents, 53020);
    });

    test('aceita orçamento zero e mantém caixa zero distinto de ausente', () {
      final list = ShoppingList(
        id: 'list-001',
        name: 'Compra',
        createdAt: createdAt,
        status: ShoppingListStatus.finalized,
        finalizedAt: finalizedAt,
        budgetCents: 0,
        finalizedRegisteredTotalCents: 100,
        checkoutPaidCents: 0,
      );

      expect(list.budgetCents, 0);
      expect(list.checkoutPaidCents, 0);
      expect(list.finalizedRegisteredTotalCents, 100);
    });

    test('rejeita orçamento negativo', () {
      expect(
        () => ShoppingList(
          id: 'list-001',
          name: 'Compra',
          createdAt: createdAt,
          budgetCents: -1,
        ),
        throwsArgumentError,
      );
    });

    test('rejeita total calculado negativo', () {
      expect(
        () => ShoppingList(
          id: 'list-001',
          name: 'Compra',
          createdAt: createdAt,
          status: ShoppingListStatus.finalized,
          finalizedAt: finalizedAt,
          finalizedRegisteredTotalCents: -1,
        ),
        throwsArgumentError,
      );
    });

    test('rejeita caixa negativo', () {
      expect(
        () => ShoppingList(
          id: 'list-001',
          name: 'Compra',
          createdAt: createdAt,
          status: ShoppingListStatus.finalized,
          finalizedAt: finalizedAt,
          finalizedRegisteredTotalCents: 100,
          checkoutPaidCents: -1,
        ),
        throwsArgumentError,
      );
    });
  });
}
