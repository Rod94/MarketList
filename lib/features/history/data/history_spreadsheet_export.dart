import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../shopping/domain/models/shopping_snapshot.dart';
import 'history_spreadsheet.dart';

enum HistorySpreadsheetAction { save, share }

const _channel = MethodChannel('br.com.rodolpho.marketlist/history_export');

Future<bool> exportHistorySpreadsheet(
  ShoppingSnapshot detail,
  HistorySpreadsheetAction action,
) async {
  final bytes = await compute(encodeHistorySpreadsheet, detail);
  final date = detail.list.finalizedAt!.toLocal().toIso8601String().split(
    'T',
  )[0];
  return await _channel.invokeMethod<bool>(action.name, {
        'fileName': 'MarketList-$date.xlsx',
        'bytes': bytes,
      }) ??
      false;
}
