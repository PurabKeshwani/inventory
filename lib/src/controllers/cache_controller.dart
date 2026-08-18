import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/model.dart';
import '../services/realtime_inventory_service.dart';

/// Centralized In-Memory Cache Controller for Component Category Tables and Fines.
///
/// Holds in-memory lists for the read-heavy tables:
/// - Actuators and Motors
/// - Communication Modules
/// - Displays and Indicators
/// - Microcontroller
/// - Others
/// - Power Components
/// - Sensors
/// - Fines
///
/// Staleness & invalidation are driven exclusively by Supabase Realtime Postgres events
/// via [RealtimeInventoryService], not by arbitrary timers/polling.
class CacheController extends GetxController {
  final Map<String, List<dynamic>> _tableCache = <String, List<dynamic>>{};
  final Map<String, DateTime> _lastFetched = <String, DateTime>{};

  final List<RealtimeChannel> _subscriptions = [];
  final RealtimeInventoryService _realtimeService = RealtimeInventoryService();

  static const List<String> cachedTables = [
    'Actuators and Motors',
    'Communication Modules',
    'Displays and Indicators',
    'Microcontroller',
    'Others',
    'Power Components',
    'Sensors',
    'Fines',
  ];

  @override
  void onInit() {
    super.onInit();
    _subscribeToRealtimeChanges();
  }

  @override
  void onClose() {
    for (final sub in _subscriptions) {
      try {
        sub.unsubscribe();
      } catch (_) {}
    }
    _subscriptions.clear();
    super.onClose();
  }

  /// Subscribes once to Realtime Postgres changes for each of the 7 component tables
  void _subscribeToRealtimeChanges() {
    for (final table in cachedTables) {
      try {
        final channel = _realtimeService.subscribe(table, () {
          // Invalidate ONLY the affected table upon any insert/update/delete event
          invalidate(table);
        });
        _subscriptions.add(channel);
      } catch (_) {}
    }
  }

  /// Check if cache holds data for a table
  bool hasData(String table) =>
      _tableCache.containsKey(table) && _tableCache[table] != null;

  /// Retrieve cached items for a table (returns null on cache miss)
  List<T>? get<T>(String table) {
    if (!hasData(table)) return null;
    try {
      final list = _tableCache[table];
      if (list == null) return null;
      if (list is List<T>) return list;
      final converted = list.map((item) {
        if (item is T) return item;
        if (T == Component && item is Map) {
          return Component.fromJson(Map<String, dynamic>.from(item)) as T;
        }
        return item as T;
      }).toList();
      return converted;
    } catch (_) {
      return null;
    }
  }

  /// Store fetched items in cache and record fetch timestamp
  void set<T>(String table, List<T> data) {
    _tableCache[table] = data;
    _lastFetched[table] = DateTime.now();
  }

  /// Invalidate (clear) cache for a specific table
  void invalidate(String table) {
    _tableCache.remove(table);
    _lastFetched.remove(table);
  }

  /// Clear entire cache
  void clearAll() {
    _tableCache.clear();
    _lastFetched.clear();
  }

  /// Get last fetched timestamp for telemetry / debugging
  DateTime? getLastFetchedTime(String table) => _lastFetched[table];

  /// Concurrently pre-warms inventory tables in the background with zero UI blocking
  Future<void> prewarmCategories() async {
    final supabase = Supabase.instance.client;
    final inventoryTables = [
      'Actuators and Motors',
      'Communication Modules',
      'Displays and Indicators',
      'Microcontroller',
      'Others',
      'Power Components',
      'Sensors',
    ];

    await Future.wait(inventoryTables.map((table) async {
      if (!hasData(table)) {
        try {
          final res = await supabase.from(table).select();
          final comps = res.map((r) => Component.fromJson(Map<String, dynamic>.from(r))).toList();
          set<Component>(table, comps);
        } catch (_) {}
      }
    }));
  }
}
