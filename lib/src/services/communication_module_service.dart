import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory/src/data/model.dart';
import 'package:inventory/src/controllers/cache_controller.dart';

/// Service for Communication Modules component category.
///
/// Architecture: In-Memory Cache with Realtime Invalidation
/// - Reads transparently check the permanent [CacheController] first.
/// - Cache misses or [forceRefresh] fetches fresh data from Supabase and populates the cache.
/// - Any database insert/update/delete triggers Supabase Realtime Postgres events
///   in [CacheController], which automatically invalidates this table's cache entry.
class CommunicationModuleService {
  final SupabaseClient _supabase = Supabase.instance.client;
  static const String tableName = 'Communication Modules';

  CacheController? get _cache {
    try {
      return Get.find<CacheController>();
    } catch (_) {
      return null;
    }
  }

  // Fetch all communication modules from Supabase (with transparent in-memory caching)
  Future<List<Component>> getAllCommunicationModules({bool forceRefresh = false}) async {
    // 1. Check in-memory cache first
    if (!forceRefresh && _cache != null && _cache!.hasData(tableName)) {
      return _cache!.get<Component>(tableName)!;
    }

    // 2. Cache miss or forceRefresh -> fetch from Supabase
    try {
      final response = await _supabase
          .from(tableName)
          .select();

      final List<dynamic> data = response as List<dynamic>;
      final components = data.map((json) => Component.fromJson(json)).toList();

      // 3. Store in cache
      _cache?.set<Component>(tableName, components);

      return components;
    } catch (error) {
      throw Exception('Failed to fetch communication modules: $error');
    }
  }

  // Add a new communication module
  Future<Component> addCommunicationModule(Component component) async {
    try {
      final response = await _supabase
          .from(tableName)
          .insert(component.toJson())
          .select()
          .single();

      _cache?.invalidate(tableName);
      return Component.fromJson(response);
    } catch (error) {
      throw Exception('Failed to add communication module: $error');
    }
  }

  // Update an existing communication module
  Future<Component> updateCommunicationModule(
      String skuId, Component component) async {
    try {
      final response = await _supabase
          .from(tableName)
          .update(component.toJson())
          .eq('skuid', skuId)
          .select()
          .single();

      _cache?.invalidate(tableName);
      return Component.fromJson(response);
    } catch (error) {
      throw Exception('Failed to update communication module: $error');
    }
  }

  // Delete a communication module
  Future<void> deleteCommunicationModule(String skuId) async {
    try {
      await _supabase.from(tableName).delete().eq('skuid', skuId);
      _cache?.invalidate(tableName);
    } catch (error) {
      throw Exception('Failed to delete communication module: $error');
    }
  }

  // Check stock for a specific communication module
  Future<int> getStock(String skuId) async {
    try {
      final response = await _supabase
          .from(tableName)
          .select('stock')
          .eq('skuid', skuId)
          .single();

      return response['stock'] as int;
    } catch (error) {
      throw Exception('Failed to get stock for communication module: $error');
    }
  }

  // Update stock for a communication module
  Future<Component?> updateStock(String skuId, int newStock) async {
    try {
      final response = await _supabase
          .from(tableName)
          .update({'stock': newStock})
          .eq('skuid', skuId)
          .select()
          .single();

      _cache?.invalidate(tableName);
      return Component.fromJson(response);
    } catch (error) {
      throw Exception('Failed to update stock for communication module: $error');
    }
  }
}
