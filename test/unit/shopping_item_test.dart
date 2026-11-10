import 'package:flutter_test/flutter_test.dart';
import 'package:market_list/features/shopping/domain/models/shopping_item.dart';

void main() {
  ShoppingItem createItem({
    String id = 'item-001',
    String shoppingListId = 'list-001',
    String name = 'Carne',
    int? plannedQuantity,
    ShoppingItemOrigin origin = ShoppingItemOrigin.planned,
    int sortOrder = 0,
    DateTime? removedAt,
  }) => ShoppingItem(
    id: id,
    shoppingListId: shoppingListId,
    name: name,
    plannedQuantity: plannedQuantity,
    origin: origin,
    sortOrder: sortOrder,
    removedAt: removedAt,
  );

  group('F2-01 / CT-006 / UX-002: quantidade planejada opcional', () {
    test('omitir quantidade preserva null, sem assumir uma unidade', () {
      final item = createItem();

      expect(item.plannedQuantity, isNull);
      expect(item.plannedQuantity, isNot(1));
    });

    test('null explícito e uma unidade são valores distintos', () {
      final unspecified = createItem(plannedQuantity: null);
      final oneUnit = createItem(plannedQuantity: 1);

      expect(unspecified.plannedQuantity, isNull);
      expect(oneUnit.plannedQuantity, 1);
      expect(unspecified.plannedQuantity, isNot(oneUnit.plannedQuantity));
    });

    test(
      'preserva cinco unidades planejadas sem registrar compra ou preço',
      () {
        final item = createItem(name: 'Sabonete', plannedQuantity: 5);

        expect(item.name, 'Sabonete');
        expect(item.plannedQuantity, 5);
      },
    );

    for (final quantity in [0, -1, -5]) {
      test('rejeita quantidade planejada $quantity', () {
        expect(
          () => createItem(plannedQuantity: quantity),
          throwsA(
            isA<ArgumentError>().having(
              (error) => error.name,
              'campo inválido',
              'plannedQuantity',
            ),
          ),
        );
      });
    }
  });

  group('F2-01: identidade, vínculo e nome livre', () {
    test('preserva IDs opacos e vínculo com a lista', () {
      final item = createItem(id: 'opaque-item', shoppingListId: 'opaque-list');

      expect(item.id, 'opaque-item');
      expect(item.shoppingListId, 'opaque-list');
    });

    test('remove só espaços externos e aceita apresentação no nome', () {
      final item = createItem(name: '  Arroz  5 kg  ');

      expect(item.name, 'Arroz  5 kg');
    });

    test('itens distintos podem ter o mesmo nome', () {
      final first = createItem(id: 'item-001', name: 'Leite');
      final second = createItem(id: 'item-002', name: 'Leite');

      expect(first.name, second.name);
      expect(first.id, isNot(second.id));
    });

    for (final invalid in ['', '   ', '\t\n']) {
      test('rejeita ID vazio ${invalid.codeUnits}', () {
        expect(() => createItem(id: invalid), throwsArgumentError);
      });

      test('rejeita vínculo vazio ${invalid.codeUnits}', () {
        expect(() => createItem(shoppingListId: invalid), throwsArgumentError);
      });

      test('rejeita nome vazio ${invalid.codeUnits}', () {
        expect(() => createItem(name: invalid), throwsArgumentError);
      });
    }
  });

  group('F2-01: representação de origem, posição e remoção', () {
    test(
      'representa planejamento e inclusão no mercado sem exigir quantidade',
      () {
        final planned = createItem();
        final atStore = createItem(origin: ShoppingItemOrigin.atStore);

        expect(planned.origin, ShoppingItemOrigin.planned);
        expect(atStore.origin, ShoppingItemOrigin.atStore);
        expect(atStore.plannedQuantity, isNull);
      },
    );

    test('preserva posição fornecida, incluindo a primeira posição zero', () {
      expect(createItem(sortOrder: 0).sortOrder, 0);
      expect(createItem(sortOrder: 7).sortOrder, 7);
    });

    test('rejeita posição negativa', () {
      expect(() => createItem(sortOrder: -1), throwsArgumentError);
    });

    test('item não removido mantém data ausente', () {
      expect(createItem().removedAt, isNull);
    });

    test('normaliza remoção para UTC preservando o instante', () {
      final local = DateTime(2026, 11, 10, 9, 30);
      final item = createItem(removedAt: local);

      expect(item.removedAt!.isUtc, isTrue);
      expect(item.removedAt!.isAtSameMomentAs(local), isTrue);
    });

    test(
      'preserva representação histórica sem apagar nome ou planejamento',
      () {
        final removedAt = DateTime.utc(2026, 11, 10, 12);
        final item = createItem(
          name: 'Sabonete',
          plannedQuantity: 5,
          sortOrder: 3,
          removedAt: removedAt,
        );

        expect(item.name, 'Sabonete');
        expect(item.plannedQuantity, 5);
        expect(item.sortOrder, 3);
        expect(item.removedAt, removedAt);
      },
    );
  });
}
