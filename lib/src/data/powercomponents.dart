import 'package:inventory/src/data/model.dart';
import 'package:inventory/src/services/powercomponent_service.dart';

class Powercomponents {
  final PowercomponentService _service = PowercomponentService();

  // Fetch components from Supabase
  Future<List<Component>> getComponents() async {
    try {
      final components = await _service.getAllPowercomponents();
      // Remove duplicates based on name (or you could use skuId if preferred)
      return _removeDuplicates(components);
    } catch (error) {
      // Return empty list if there's an error
      // You might want to handle this differently based on your app's needs
      print('Error fetching power components: $error');
      return [];
    }
  }

  // Helper method to remove duplicate components
  List<Component> _removeDuplicates(List<Component> components) {
    final seen = <String>{};
    final uniqueComponents = <Component>[];

    for (final component in components) {
      // Use skuId as primary identifier, fall back to name if skuId is null
      final identifier = component.skuId ?? component.name;
      if (!seen.contains(identifier)) {
        seen.add(identifier);
        uniqueComponents.add(component);
        print(
            'Added unique component: ${component.name} (${component.skuId}) - Stock: ${component.stock}');
      } else {
        print(
            'Removing duplicate component: ${component.name} (${component.skuId}) - Stock: ${component.stock}');
      }
    }

    print(
        'Original count: ${components.length}, After removing duplicates: ${uniqueComponents.length}');
    return uniqueComponents;
  }

  // Add a new component
  Future<Component?> addComponent(Component component) async {
    try {
      return await _service.addPowercomponent(component);
    } catch (error) {
      print('Error adding power component: $error');
      return null;
    }
  }

  // Update an existing component
  Future<Component?> updateComponent(String skuId, Component component) async {
    try {
      return await _service.updatePowercomponent(skuId, component);
    } catch (error) {
      print('Error updating power component: $error');
      return null;
    }
  }

  // Delete a component
  Future<bool> deleteComponent(String skuId) async {
    try {
      await _service.deletePowercomponent(skuId);
      return true;
    } catch (error) {
      print('Error deleting power component: $error');
      return false;
    }
  }

  // Update stock for a component
  Future<Component?> updateStock(String skuId, int newStock) async {
    try {
      return await _service.updateStock(skuId, newStock);
    } catch (error) {
      print('Error updating stock: $error');
      return null;
    }
  }
}
