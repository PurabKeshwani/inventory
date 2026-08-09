import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:csv/csv.dart';
import '../models/bulk_upload_models.dart';

class BulkUploadService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Maps friendly/typo-tolerant category names to the EXACT table names
  // in Supabase (which contain spaces, per your schema).
  static const Map<String, String> _categoryAliases = {
    'microcontroller': 'Microcontroller',
    'microcontrollers': 'Microcontroller',
    'sensor': 'Sensors',
    'sensors': 'Sensors',
    'communication module': 'Communication Modules',
    'communication modules': 'Communication Modules',
    'display': 'Displays and Indicators',
    'displays': 'Displays and Indicators',
    'displays and indicators': 'Displays and Indicators',
    'actuator': 'Actuators and Motors',
    'actuators': 'Actuators and Motors',
    'actuators and motors': 'Actuators and Motors',
    'power component': 'Power Components',
    'power components': 'Power Components',
    'other': 'Others',
    'others': 'Others',
  };

  String? _resolveCategory(String raw) => _categoryAliases[raw.trim().toLowerCase()];

  Future<BulkUploadReport> uploadFromCsv(String csvContent) async {
    final rows = const CsvToListConverter(eol: '\n').convert(csvContent);

    if (rows.isEmpty) {
      return BulkUploadReport(added: 0, updated: 0, failed: [
        BulkUploadRowResult(rowNumber: 0, skuid: '', message: 'CSV file is empty'),
      ]);
    }

    final header = rows.first.map((h) => h.toString().trim().toLowerCase()).toList();
    final catIdx = header.indexOf('category');
    final skuIdx = header.indexOf('skuid');
    final nameIdx = header.indexOf('name');
    final boxIdx = header.indexOf('boxno');
    final stockIdx = header.indexOf('stock');
    final warningIdx = header.indexOf('warning');

    if (catIdx == -1 || skuIdx == -1 || nameIdx == -1 || stockIdx == -1) {
      return BulkUploadReport(added: 0, updated: 0, failed: [
        BulkUploadRowResult(
          rowNumber: 0,
          skuid: '',
          message:
              'CSV must include columns: category, skuid, name, stock (boxno and warning are optional)',
        ),
      ]);
    }

    final byCategory = <String, List<Map<String, dynamic>>>{};
    final failed = <BulkUploadRowResult>[];

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      final rowNum = i + 1; // account for header row
      if (row.every((c) => c.toString().trim().isEmpty)) continue;

      String cell(int idx) => idx >= 0 && idx < row.length ? row[idx].toString().trim() : '';

      final rawCategory = cell(catIdx);
      final skuid = cell(skuIdx);
      final name = cell(nameIdx);
      final boxno = boxIdx == -1 ? '' : cell(boxIdx);
      final stockRaw = cell(stockIdx);
      final warning = warningIdx == -1 ? '' : cell(warningIdx);

      final category = _resolveCategory(rawCategory);
      if (category == null) {
        failed.add(BulkUploadRowResult(
            rowNumber: rowNum, skuid: skuid, message: 'Unknown category "$rawCategory"'));
        continue;
      }
      if (skuid.isEmpty) {
        failed.add(BulkUploadRowResult(rowNumber: rowNum, skuid: skuid, message: 'Missing SKU ID'));
        continue;
      }
      if (name.isEmpty) {
        failed.add(BulkUploadRowResult(rowNumber: rowNum, skuid: skuid, message: 'Missing name'));
        continue;
      }
      final stock = int.tryParse(stockRaw);
      if (stock == null) {
        failed.add(BulkUploadRowResult(
            rowNumber: rowNum, skuid: skuid, message: 'Invalid stock value "$stockRaw"'));
        continue;
      }

      byCategory.putIfAbsent(category, () => []);
      byCategory[category]!.add({
        'skuid': skuid,
        'name': name,
        'boxno': boxno,
        'stock': stock,
        'warning': warning,
        '_rowNumber': rowNum,
      });
    }

    int added = 0;
    int updated = 0;

    for (final entry in byCategory.entries) {
      final tableName = entry.key;
      final incomingRows = entry.value;
      final incomingSkuids = incomingRows.map((r) => r['skuid'] as String).toList();

      // Check which skuids already exist in this category, so we can report
      // "added" vs "updated" accurately rather than a single vague count.
      Set<String> existingSkuids = {};
      try {
        final existing =
            await _supabase.from(tableName).select('skuid').inFilter('skuid', incomingSkuids);
        existingSkuids = (existing as List).map((e) => e['skuid'].toString()).toSet();
      } catch (e) {
        for (final r in incomingRows) {
          failed.add(BulkUploadRowResult(
            rowNumber: r['_rowNumber'] as int,
            skuid: r['skuid'] as String,
            message: 'Could not check existing stock: $e',
          ));
        }
        continue;
      }

      final upsertPayload = incomingRows
          .map((r) => Map<String, dynamic>.from(r)..remove('_rowNumber'))
          .toList();

      try {
        await _supabase.from(tableName).upsert(upsertPayload, onConflict: 'skuid');
        for (final r in incomingRows) {
          if (existingSkuids.contains(r['skuid'])) {
            updated++;
          } else {
            added++;
          }
        }
      } catch (e) {
        for (final r in incomingRows) {
          failed.add(BulkUploadRowResult(
            rowNumber: r['_rowNumber'] as int,
            skuid: r['skuid'] as String,
            message: 'Database error: $e',
          ));
        }
      }
    }

    return BulkUploadReport(added: added, updated: updated, failed: failed);
  }
}
