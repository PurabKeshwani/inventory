import 'package:get/get.dart';
import 'package:inventory/src/data/outputComponent.dart';
import 'package:inventory/src/features/authentication/controllers/componentController.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Selectquerycontroller extends GetxController {
  final supabase = Supabase.instance.client;
  final ComponentController componentControl = Get.find<ComponentController>();
  RxList<Outputcomponent> newres = <Outputcomponent>[].obs;
  RxBool isLoading = false.obs;

  static const List<String> allCategoryTables = [
    'Microcontroller',
    'Sensors',
    'Communication Modules',
    'Displays and Indicators',
    'Actuators and Motors',
    'Power Components',
    'Others',
  ];

  Future<void> fetchComponents(String compName, {String? targetTable}) async {
    isLoading.value = true;
    newres.clear();

    final trimmedName = compName.trim();
    List<Outputcomponent> results = [];

    // 1. Try specified target table or controller's ClassName if available
    String preferredTable = targetTable ?? componentControl.ClassName.value;
    if (preferredTable.isNotEmpty) {
      results = await _queryTableForComponent(preferredTable, trimmedName);
    }

    // 2. If no results found in preferred table, search all 7 tables
    if (results.isEmpty) {
      for (final table in allCategoryTables) {
        if (table == preferredTable) continue; // already tried
        final tableResults = await _queryTableForComponent(table, trimmedName);
        if (tableResults.isNotEmpty) {
          results = tableResults;
          // Set the found table name in controller so updates/edits work on the correct table
          componentControl.ClassName.value = table;
          break;
        }
      }
    }

    // 3. Populate observable list
    newres.assignAll(results);
    isLoading.value = false;
  }

  Future<List<Outputcomponent>> _queryTableForComponent(
      String tableName, String compName) async {
    try {
      final response = await supabase
          .from(tableName)
          .select()
          .ilike('name', compName);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((entry) {
        return Outputcomponent(
          skuid: (entry['skuid'] ?? entry['skuId'] ?? 'N/A').toString(),
          boxNo: (entry['boxno'] ?? entry['boxNo'] ?? 'N/A').toString(),
          stock: int.tryParse(entry['stock']?.toString() ?? '0') ?? 0,
          warning: entry['warning']?.toString(),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }
}
