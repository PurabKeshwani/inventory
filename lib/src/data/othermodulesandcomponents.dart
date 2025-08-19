import 'package:inventory/src/data/model.dart';
import 'package:inventory/src/services/other_components_service.dart';

class Othermodulesandcomponents {
  final OtherComponentsService _service = OtherComponentsService();

  // Fetch components from Supabase
  Future<List<Component>> getComponents() async {
    try {
      final components = await _service.getAllOtherComponents();
      // Remove duplicates based on name (or you could use skuId if preferred)
      return _removeDuplicates(components);
    } catch (error) {
      // Return empty list if there's an error
      // You might want to handle this differently based on your app's needs
      print('Error fetching other components: $error');
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
      return await _service.addOtherComponent(component);
    } catch (error) {
      print('Error adding other component: $error');
      return null;
    }
  }

  // Update an existing component
  Future<Component?> updateComponent(String skuId, Component component) async {
    try {
      return await _service.updateOtherComponent(skuId, component);
    } catch (error) {
      print('Error updating other component: $error');
      return null;
    }
  }

  // Delete a component
  Future<bool> deleteComponent(String skuId) async {
    try {
      await _service.deleteOtherComponent(skuId);
      return true;
    } catch (error) {
      print('Error deleting other component: $error');
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