import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory/src/data/model.dart';

class SensorService {
  final SupabaseClient _supabase = Supabase.instance.client;
  static const String tableName = 'Sensors';

  // Fetch all sensors from Supabase
  Future<List<Component>> getAllSensors() async {
    try {
      final response = await _supabase
          .from(tableName)
          .select('skuid, name, boxno, stock, warning');

      final List<dynamic> data = response as List<dynamic>;

      // Debug: Print raw data from database
      print('Raw data from database:');
      for (int i = 0; i < data.length && i < 5; i++) {
        print('Row $i: ${data[i]}');
      }

      final components = data.map((json) => Component.fromJson(json)).toList();

      // Debug: Print parsed components
      print('Parsed components:');
      for (int i = 0; i < components.length && i < 5; i++) {
        final comp = components[i];
        print(
            'Component $i: name="${comp.name}", stock=${comp.stock}, skuId="${comp.skuId}"');
      }

      // Debug: Print component count and check for duplicates
      print('Fetched ${components.length} components from database');
      final uniqueNames = components.map((c) => c.name).toSet();
      print('Unique component names: ${uniqueNames.length}');

      if (components.length != uniqueNames.length) {
        print('WARNING: Found duplicate components in database!');
        // Print duplicates for debugging
        final nameCount = <String, int>{};
        for (final component in components) {
          nameCount[component.name] = (nameCount[component.name] ?? 0) + 1;
        }
        nameCount.forEach((name, count) {
          if (count > 1) {
            print('Duplicate: $name appears $count times');
          }
        });
      }

      return components;
    } catch (error) {
      throw Exception('Failed to fetch sensors: $error');
    }
  }

  // Add a new sensor
  Future<Component> addSensor(Component component) async {
    try {
      final response = await _supabase
          .from(tableName)
          .insert(component.toJson())
          .select()
          .single();

      return Component.fromJson(response);
    } catch (error) {
      throw Exception('Failed to add sensor: $error');
    }
  }

  // Update an existing sensor
  Future<Component> updateSensor(String skuId, Component component) async {
    try {
      final response = await _supabase
          .from(tableName)
          .update(component.toJson())
          .eq('skuid', skuId)
          .select()
          .single();

      return Component.fromJson(response);
    } catch (error) {
      throw Exception('Failed to update sensor: $error');
    }
  }

  // Delete a sensor
  Future<void> deleteSensor(String skuId) async {
    try {
      await _supabase.from(tableName).delete().eq('skuid', skuId);
    } catch (error) {
      throw Exception('Failed to delete sensor: $error');
    }
  }

  // Update stock for a specific sensor
  Future<Component> updateStock(String skuId, int newStock) async {
    try {
      final response = await _supabase
          .from(tableName)
          .update({'stock': newStock})
          .eq('skuid', skuId)
          .select()
          .single();

      return Component.fromJson(response);
    } catch (error) {
      throw Exception('Failed to update stock: $error');
    }
  }
}
