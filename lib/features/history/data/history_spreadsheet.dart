import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../../shopping/domain/models/purchase_entry.dart';
import '../../shopping/domain/models/shopping_list.dart';
import '../../shopping/domain/models/shopping_snapshot.dart';
import '../../shopping/domain/shopping_calculator.dart';
import '../history_status_text.dart';

Uint8List encodeHistorySpreadsheet(ShoppingSnapshot detail) {
  final list = detail.list;
  if (list.status != ShoppingListStatus.finalized) {
    throw ArgumentError('Somente compras finalizadas podem ser exportadas.');
  }

  final workbook = Excel.createExcel();
  workbook.rename('Sheet1', 'Resumo');
  workbook.setDefaultSheet('Resumo');
  _writeSummary(workbook['Resumo'], list);
  _writeItems(workbook['Itens'], detail.calculation.items);
  final bytes = workbook.encode();
  if (bytes == null) throw StateError('Não foi possível gerar a planilha.');
  return Uint8List.fromList(bytes);
}

void _writeSummary(Sheet sheet, ShoppingList list) {
  final date = list.finalizedAt!.toLocal();
  sheet.setColumnWidth(0, 24);
  sheet.setColumnWidth(1, 36);
  _appendHeader(sheet, ['Compra finalizada', 'Valor']);
  sheet.appendRow([TextCellValue('Lista'), TextCellValue(list.name)]);
  sheet.appendRow([
    TextCellValue('Data da compra'),
    DateCellValue(year: date.year, month: date.month, day: date.day),
  ]);
  sheet.appendRow([TextCellValue('Orçamento'), _money(list.budgetCents)]);
  sheet.appendRow([
    TextCellValue('Total calculado'),
    _money(list.finalizedRegisteredTotalCents),
  ]);
  sheet.appendRow([
    TextCellValue('Valor pago no caixa'),
    _money(list.checkoutPaidCents),
  ]);
  _formatMoney(sheet, 1, 3);
  _formatMoney(sheet, 1, 4);
  _formatMoney(sheet, 1, 5);
}

void _writeItems(Sheet sheet, List<ItemPurchaseSummary> items) {
  _appendHeader(sheet, [
    'Item',
    'Produto',
    'Quantidade planejada',
    'Status do item',
    'Tipo de compra',
    'Quantidade da entrada',
    'Preço unitário',
    'Subtotal da entrada',
  ]);
  const widths = [8.0, 32.0, 24.0, 30.0, 19.0, 25.0, 21.0, 23.0];
  for (var column = 0; column < widths.length; column++) {
    sheet.setColumnWidth(column, widths[column]);
  }
  var number = 0;
  var row = 1;
  for (final item in items) {
    if (item.status == ItemPurchaseStatus.removed) continue;
    number++;
    final entries = item.entries.isEmpty
        ? const <PurchaseEntry?>[null]
        : item.entries;
    for (final entry in entries) {
      sheet.appendRow([
        IntCellValue(number),
        TextCellValue(item.item.name),
        _quantity(item.item.plannedQuantity),
        TextCellValue(historyStatusText(item.status)),
        if (entry != null)
          TextCellValue(entry.isDirect ? 'Valor direto' : 'Por unidade'),
        if (entry != null) ...[
          _quantity(entry.quantity),
          _money(entry.unitPriceCents),
          _money(entry.subtotalCents),
        ],
      ]);
      if (entry?.unitPriceCents != null) _formatMoney(sheet, 6, row);
      if (entry != null) _formatMoney(sheet, 7, row);
      row++;
    }
  }
}

void _appendHeader(Sheet sheet, List<String> labels) {
  sheet.appendRow(labels.map(TextCellValue.new).toList());
  for (var column = 0; column < labels.length; column++) {
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: column, rowIndex: 0))
        .cellStyle = CellStyle(
      bold: true,
    );
  }
}

// Excel retains 15 significant digits. Use exact text at the domain's extremes.
const _maxSpreadsheetDigits = 999999999999999;

CellValue? _quantity(int? quantity) {
  if (quantity == null) return null;
  return quantity > _maxSpreadsheetDigits
      ? TextCellValue(quantity.toString())
      : IntCellValue(quantity);
}

CellValue? _money(int? cents) {
  if (cents == null) return null;
  if (cents > _maxSpreadsheetDigits) {
    final decimal = (cents % 100).toString().padLeft(2, '0');
    return TextCellValue('R\$ ${cents ~/ 100},$decimal');
  }
  return DoubleCellValue(cents / 100);
}

void _formatMoney(Sheet sheet, int column, int row) {
  final cell = sheet.cell(
    CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row),
  );
  if (cell.value is DoubleCellValue) {
    cell.cellStyle = CellStyle(
      numberFormat: const CustomNumericNumFormat(formatCode: r'"R$" #,##0.00'),
    );
  }
}
