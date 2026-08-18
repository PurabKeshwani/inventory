import 'package:inventory/src/data/model.dart';
import 'package:inventory/src/services/display_indicator_service.dart';

class Displaysandindicators {
  final DisplayIndicatorService _service = DisplayIndicatorService();

  // Fetch components from Supabase (with caching & realtime invalidation)
  Future<List<Component>> getComponents({bool forceRefresh = false}) async {
    try {
      final components = await _service.getAllDisplaysAndIndicators(forceRefresh: forceRefresh);
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
      return await _service.addDisplayIndicator(component);
    } catch (error) {
      print('Error adding display or indicator: $error');
      return null;
    }
  }

  // Update an existing component
  Future<Component?> updateComponent(String skuId, Component component) async {
    try {
      return await _service.updateDisplayIndicator(skuId, component);
    } catch (error) {
      print('Error updating display or indicator: $error');
      return null;
    }
  }

  // Delete a component
  Future<bool> deleteComponent(String skuId) async {
    try {
      await _service.deleteDisplayIndicator(skuId);
      return true;
    } catch (error) {
      print('Error deleting display or indicator: $error');
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
