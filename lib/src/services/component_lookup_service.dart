import 'package:inventory/src/data/model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Result of an exact-SKU component lookup across all Supabase component tables.
sealed class ComponentLookupResult {
  const ComponentLookupResult();
}

/// The SKU matched exactly one row in one component table.
class ComponentLookupFound extends ComponentLookupResult {
  final Component component;
  final String tableName;

  const ComponentLookupFound(this.component, this.tableName);
}

/// The input was empty after trimming; no lookup was attempted.
class ComponentLookupEmpty extends ComponentLookupResult {
  const ComponentLookupEmpty();
}

/// No table contained a row whose `skuid` exactly equals the input.
class ComponentLookupNotFound extends ComponentLookupResult {
  const ComponentLookupNotFound();
}

/// More than one row shares the exact SKU within a single component table.
class ComponentLookupAmbiguous extends ComponentLookupResult {
  const ComponentLookupAmbiguous();
}

/// The Supabase request failed (network / server error).
class ComponentLookupError extends ComponentLookupResult {
  final String message;

  const ComponentLookupError(this.message);
}

/// Exact-SKU lookup for inventory components.
///
/// Trims surrounding whitespace, preserves identifier case, and performs an
/// exact (`eq`) match against every component table. No fuzzy, prefix, or
/// component-name matching is used, so the scanned and manually entered
/// code paths resolve identifiers identically.
class ComponentLookupService {
  static const List<String> _componentTables = [
    'Microcontroller',
    'Communication Modules',
    'Sensors',
    'Displays and Indicators',
    'Actuators and Motors',
    'Power Components',
    'Others',
  ];

  /// Trim surrounding whitespace only. Identifier case is preserved.
  static String normalizeManualIdentifier(String value) => value.trim();

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Look up a component by its exact SKU across all component tables.
  Future<ComponentLookupResult> lookupComponentBySku(String rawSku) async {
    final sku = normalizeManualIdentifier(rawSku);
    if (sku.isEmpty) return const ComponentLookupEmpty();

    ComponentLookupAmbiguous? ambiguous;
    for (final table in _componentTables) {
      try {
        final response = await _supabase
            .from(table)
            .select('skuid, name, boxno, stock, warning')
            .eq('skuid', sku)
            .maybeSingle();

        if (response != null) {
          return ComponentLookupFound(Component.fromJson(response), table);
        }
      } on PostgrestException catch (error) {
        final message = error.message.toLowerCase();
        if (message.contains('more than one') ||
            message.contains('multiple rows')) {
          ambiguous ??= const ComponentLookupAmbiguous();
        } else {
          return ComponentLookupError('Database error: ${error.message}');
        }
      } catch (error) {
        return ComponentLookupError('Network error: $error');
      }
    }

    if (ambiguous != null) return ambiguous;
    return const ComponentLookupNotFound();
  }
}
