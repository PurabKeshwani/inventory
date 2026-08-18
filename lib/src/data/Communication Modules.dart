import 'package:inventory/src/data/model.dart';
import 'package:inventory/src/services/communication_module_service.dart';

class CommunicationModules {
  final CommunicationModuleService _service = CommunicationModuleService();

  // Fetch components from Supabase (with caching & realtime invalidation)
  Future<List<Component>> getComponents({bool forceRefresh = false}) async {
    try {
      final components = await _service.getAllCommunicationModules(forceRefresh: forceRefresh);
      // Remove duplicates based on name (or you could use skuId if preferred)
      return _removeDuplicates(components);
    } catch (error) {
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
      }
    }

    return uniqueComponents;
  }

  // Add a new component
  Future<Component?> addComponent(Component component) async {
    try {
      return await _service.addCommunicationModule(component);
    } catch (error) {
      print('Error adding communication module: $error');
      return null;
    }
  }

  // Update an existing component
  Future<Component?> updateComponent(String skuId, Component component) async {
    try {
      return await _service.updateCommunicationModule(skuId, component);
    } catch (error) {
      print('Error updating communication module: $error');
      return null;
    }
  }

  // Delete a component
  Future<bool> deleteComponent(String skuId) async {
    try {
      await _service.deleteCommunicationModule(skuId);
      return true;
    } catch (error) {
      print('Error deleting communication module: $error');
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
