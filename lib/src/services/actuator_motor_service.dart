import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory/src/data/model.dart';

class ActuatorMotorService {
  final SupabaseClient _supabase = Supabase.instance.client;
  static const String tableName = 'Actuators and Motors';

  // Fetch all actuators and motors from Supabase
  Future<List<Component>> getAllActuatorsAndMotors() async {
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
      throw Exception('Failed to fetch actuators and motors: $error');
    }
  }

  // Add a new actuator or motor
  Future<Component> addActuatorMotor(Component component) async {
    try {
      final response = await _supabase
          .from(tableName)
          .insert(component.toJson())
          .select()
          .single();

      return Component.fromJson(response);
    } catch (error) {
      throw Exception('Failed to add actuator or motor: $error');
    }
  }

  // Update an existing actuator or motor
  Future<Component> updateActuatorMotor(
      String skuId, Component component) async {
    try {
      final response = await _supabase
          .from(tableName)
          .update(component.toJson())
          .eq('skuid', skuId)
          .select()
          .single();

      return Component.fromJson(response);
    } catch (error) {
      throw Exception('Failed to update actuator or motor: $error');
    }
  }

  // Delete an actuator or motor
  Future<void> deleteActuatorMotor(String skuId) async {
    try {
      await _supabase.from(tableName).delete().eq('skuid', skuId);
    } catch (error) {
      throw Exception('Failed to delete actuator or motor: $error');
    }
  }

  // Update stock for a specific actuator or motor
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
