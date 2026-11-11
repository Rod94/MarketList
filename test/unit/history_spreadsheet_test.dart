import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:market_list/core/money/money.dart';
import 'package:market_list/features/history/data/history_spreadsheet.dart';
import 'package:market_list/features/shopping/domain/models/purchase_entry.dart';
import 'package:market_list/features/shopping/domain/models/shopping_item.dart';
import 'package:market_list/features/shopping/domain/models/shopping_list.dart';
import 'package:market_list/features/shopping/domain/models/shopping_snapshot.dart';
import 'package:market_list/features/shopping/domain/shopping_calculator.dart';

void main() {
  final createdAt = DateTime.utc(2026, 10, 1, 12);
  final finalizedAt = DateTime.utc(2026, 10, 2, 12);

  ShoppingItem item(
    String id,
    int order, {
    int? planned,
    bool removed = false,
  }) => ShoppingItem(
    id: id,
    shoppingListId: 'list',
    name: id,
    origin: ShoppingItemOrigin.planned,
    sortOrder: order,
    plannedQuantity: planned,
    removedAt: removed ? createdAt : null,
  );

  ShoppingSnapshot snapshot({
    List<ShoppingItem> items = const [],
    List<PurchaseEntry> entries = const [],
    int? budget,
    int? paid,
    bool finalized = true,
  }) {
    final calculation = calculateShoppingList(
      shoppingListId: 'list',
      items: items,
      entries: entries,
    );
    return ShoppingSnapshot(
      ShoppingList(
        id: 'list',
        name: 'Compra & ação <outubro>',
        createdAt: createdAt,
        status: finalized
            ? ShoppingListStatus.finalized
            : ShoppingListStatus.active,
        finalizedAt: finalized ? finalizedAt : null,
        finalizedRegisteredTotalCents: finalized
            ? calculation.totalCents
            : null,
        budgetCents: budget,
        checkoutPaidCents: paid,
      ),
      calculation,
    );
  }

  CellValue? cell(Sheet sheet, String address) =>
      sheet.cell(CellIndex.indexByString(address)).value;

  test('EXP-001/002 exporta resumo e cada entrada com tipos de célula', () {
    final detail = snapshot(
      budget: 0,
      paid: 1335,
      items: [
        item('Arroz', 0, planned: 5),
        item('=2+2', 1),
        item('Café', 2, planned: 2),
        item('Removido', 3, removed: true),
      ],
      entries: [
        PurchaseEntry(
          id: 'a',
          shoppingItemId: 'Arroz',
          quantity: 2,
          unitPriceCents: 422,
        ),
        PurchaseEntry(
          id: 'b',
          shoppingItemId: 'Arroz',
          quantity: 1,
          unitPriceCents: 0,
        ),
        PurchaseEntry(id: 'c', shoppingItemId: 'Arroz', directAmountCents: 478),
        PurchaseEntry(id: 'd', shoppingItemId: '=2+2', directAmountCents: 0),
        PurchaseEntry(
          id: 'e',
          shoppingItemId: 'Removido',
          directAmountCents: 333,
        ),
      ],
    );
    final workbook = Excel.decodeBytes(encodeHistorySpreadsheet(detail));
    expect(workbook.tables.keys, ['Resumo', 'Itens']);
    final summary = workbook['Resumo'];
    expect(cell(summary, 'B2'), TextCellValue('Compra & ação <outubro>'));
    final local = finalizedAt.toLocal();
    expect(
      cell(summary, 'B3'),
      DateCellValue(year: local.year, month: local.month, day: local.day),
    );
    expect(cell(summary, 'B4'), IntCellValue(0));
    expect(
      summary
          .cell(CellIndex.indexByString('B4'))
          .cellStyle
          ?.numberFormat
          .formatCode,
      r'"R$" #,##0.00',
    );
    expect(cell(summary, 'B5'), DoubleCellValue(13.22));
    expect(cell(summary, 'B6'), DoubleCellValue(13.35));

    final items = workbook['Itens'];
    expect(items.maxRows, 6);
    expect(cell(items, 'C2'), IntCellValue(5));
    expect(cell(items, 'D2'), TextCellValue('Quantidade não confirmada'));
    expect(cell(items, 'F2'), IntCellValue(2));
    expect(cell(items, 'G2'), DoubleCellValue(4.22));
    expect(cell(items, 'H2'), DoubleCellValue(8.44));
    expect(cell(items, 'A3'), IntCellValue(1));
    expect(cell(items, 'G3'), IntCellValue(0));
    expect(cell(items, 'H3'), IntCellValue(0));
    expect(cell(items, 'E4'), TextCellValue('Valor direto'));
    expect(cell(items, 'F4'), isNull);
    expect(cell(items, 'G4'), isNull);
    expect(cell(items, 'H4'), DoubleCellValue(4.78));
    expect(cell(items, 'B5'), TextCellValue('=2+2'));
    expect(cell(items, 'C5'), isNull);
    expect(cell(items, 'H5'), IntCellValue(0));
    expect(cell(items, 'B6'), TextCellValue('Café'));
    expect(cell(items, 'D6'), TextCellValue('Não comprado'));
    expect(cell(items, 'H6'), isNull);
  });

  test('EXP-002 deixa campos opcionais vazios e preserva total zero', () {
    final workbook = Excel.decodeBytes(encodeHistorySpreadsheet(snapshot()));
    expect(cell(workbook['Resumo'], 'B4'), isNull);
    expect(cell(workbook['Resumo'], 'B5'), IntCellValue(0));
    expect(cell(workbook['Resumo'], 'B6'), isNull);
    expect(workbook['Itens'].maxRows, 1);
  });

  test(
    'EXP-003 preserva centavos e quantidades acima da precisão do Excel',
    () {
      final detail = snapshot(
        items: [item('Arroz', 0, planned: maxMoneyCents)],
        entries: [
          PurchaseEntry(
            id: 'a',
            shoppingItemId: 'Arroz',
            directAmountCents: maxMoneyCents,
          ),
        ],
      );
      final workbook = Excel.decodeBytes(encodeHistorySpreadsheet(detail));
      expect(
        cell(workbook['Resumo'], 'B5'),
        TextCellValue(r'R$ 92233720368547758,07'),
      );
      expect(
        cell(workbook['Itens'], 'C2'),
        TextCellValue('9223372036854775807'),
      );
      expect(cell(workbook['Itens'], 'H2'), cell(workbook['Resumo'], 'B5'));
    },
  );

  test('EXP-004 recusa exportação de compra ativa', () {
    expect(
      () => encodeHistorySpreadsheet(snapshot(finalized: false)),
      throwsArgumentError,
    );
  });
}
