import 'package:flutter_test/flutter_test.dart';
import 'package:inventory/src/data/model.dart';
import 'package:inventory/src/services/component_lookup_service.dart';

void main() {
  group('ComponentLookupService normalization', () {
    test('trims surrounding whitespace but preserves case', () {
      expect(ComponentLookupService.normalizeManualIdentifier('  MC-01  '),
          'MC-01');
      expect(ComponentLookupService.normalizeManualIdentifier('  mc-01  '),
          'mc-01');
    });

    test('empty after trim is treated as empty', () {
      expect(ComponentLookupService.normalizeManualIdentifier('   '), '');
      expect(ComponentLookupService.normalizeManualIdentifier(''), '');
    });
  });

  group('ComponentLookupResult', () {
    test('distinguished by type', () {
      expect(
          ComponentLookupFound(
              Component(name: 'X', boxNo: 'B', stock: 1, skuId: 'SKU'),
              'Microcontroller'),
          isA<ComponentLookupFound>());
      expect(const ComponentLookupEmpty(), isA<ComponentLookupEmpty>());
      expect(const ComponentLookupNotFound(), isA<ComponentLookupNotFound>());
      expect(const ComponentLookupAmbiguous(), isA<ComponentLookupAmbiguous>());
      expect(const ComponentLookupError('boom'), isA<ComponentLookupError>());
    });
  });
}
