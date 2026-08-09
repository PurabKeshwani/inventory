import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory/src/services/microcontroller_service.dart';
import 'package:inventory/src/services/sensor_service.dart';
import 'package:inventory/src/services/communication_module_service.dart';
import 'package:inventory/src/services/display_indicator_service.dart';
import 'package:inventory/src/services/actuator_motor_service.dart';
import 'package:inventory/src/services/powercomponent_service.dart';
import 'package:inventory/src/services/other_components_service.dart';
import '../models/analytics_models.dart';

class AnalyticsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // issuedate/returndate are stored as 'd/M/yyyy' strings (no zero-padding),
  // NOT ISO dates — DateTime.tryParse() will not parse these correctly.
  DateTime? _parseAppDate(String? raw) {
    if (raw == null || raw.isEmpty || raw == 'soon') return null;
    final parts = raw.split('/');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    try {
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  Future<AnalyticsSummary> loadLast30DaysSummary() async {
    // 1. Stock + skuid->category map, fetched in parallel from the 7 category tables
    final categoryResults = await Future.wait([
      MicrocontrollerService().getAllMicrocontrollers(),
      SensorService().getAllSensors(),
      CommunicationModuleService().getAllCommunicationModules(),
      DisplayIndicatorService().getAllDisplaysAndIndicators(),
      ActuatorMotorService().getAllActuatorsAndMotors(),
      PowercomponentService().getAllPowercomponents(),
      OtherComponentsService().getAllOtherComponents(),
    ]);

    const categoryNames = [
      'Microcontroller',
      'Sensors',
      'Communication Modules',
      'Displays and Indicators',
      'Actuators and Motors',
      'Power Components',
      'Others',
    ];

    final skuidToCategory = <String, String>{};
    final totalStockByCategory = <String, int>{};

    for (int i = 0; i < categoryNames.length; i++) {
      final cat = categoryNames[i];
      int sum = 0;
      for (final comp in categoryResults[i]) {
        if (comp.skuId != null) skuidToCategory[comp.skuId!] = cat;
        sum += comp.stock;
      }
      totalStockByCategory[cat] = sum;
    }

    // 2. Fetch all transactions. issuedate/returndate are plain varchar columns,
    // so date filtering happens client-side after parsing.
    final rawTx = await _supabase.from('Transactions').select();

    final now = DateTime.now();
    final windowStart = now.subtract(const Duration(days: 30));

    int totalIssued = 0;
    int totalReturned = 0;
    int activeNow = 0;
    final membersServed = <String>{};
    final componentCounts = <String, int>{};
    final componentSkus = <String, String>{};
    final issuedByCategory = <String, int>{};
    final dailyCounts = <DateTime, int>{};

    for (final row in rawTx) {
      final issueDate = _parseAppDate(row['issuedate']?.toString());
      final returnDateRaw = row['returndate']?.toString();
      final isActive = returnDateRaw == null || returnDateRaw == 'soon';
      final returnDate = isActive ? null : _parseAppDate(returnDateRaw);

      if (isActive) activeNow++;

      final items = (row['package'] as List<dynamic>?) ?? [];
      for (final item in items) {
        final qty = item['Quantity'] is int
            ? item['Quantity'] as int
            : int.tryParse('${item['Quantity']}') ?? 1;
        final skuid = item['skuid']?.toString();
        final name = item['compname']?.toString() ?? 'Unknown';

        if (isActive && skuid != null) {
          final cat = skuidToCategory[skuid];
          if (cat != null) {
            issuedByCategory[cat] = (issuedByCategory[cat] ?? 0) + qty;
          }
        }

        if (issueDate != null && !issueDate.isBefore(windowStart)) {
          totalIssued += qty;
          componentCounts[name] = (componentCounts[name] ?? 0) + qty;
          if (skuid != null) componentSkus[name] = skuid;
          final dayKey = DateTime(issueDate.year, issueDate.month, issueDate.day);
          dailyCounts[dayKey] = (dailyCounts[dayKey] ?? 0) + qty;
        }
      }

      if (issueDate != null && !issueDate.isBefore(windowStart)) {
        final memberKey = row['id']?.toString() ?? row['name']?.toString() ?? '';
        if (memberKey.isNotEmpty) membersServed.add(memberKey);
      }

      if (returnDate != null && !returnDate.isBefore(windowStart)) {
        totalReturned++;
      }
    }

    final topComponents = componentCounts.entries
        .map((e) => ComponentPopularity(
              name: e.key,
              skuid: componentSkus[e.key] ?? '',
              totalIssued: e.value,
            ))
        .toList()
      ..sort((a, b) => b.totalIssued.compareTo(a.totalIssued));

    final categoryStock = categoryNames
        .map((cat) => CategoryStock(
              category: cat,
              totalStock: totalStockByCategory[cat] ?? 0,
              currentlyIssued: issuedByCategory[cat] ?? 0,
            ))
        .toList();

    return AnalyticsSummary(
      totalIssuedLast30Days: totalIssued,
      totalReturnedLast30Days: totalReturned,
      activeIssuesNow: activeNow,
      uniqueMembersServedLast30Days: membersServed.length,
      topComponents: topComponents.take(6).toList(),
      categoryStock: categoryStock,
      dailyIssueCounts: dailyCounts,
    );
  }
}
