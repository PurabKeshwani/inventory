import 'package:flutter_test/flutter_test.dart';
import 'package:inventory/src/data/cartcomponent.dart';
import 'package:inventory/src/data/model.dart';
import 'package:inventory/src/features/authentication/controllers/emailcontroller.dart';
import 'package:inventory/src/features/authentication/controllers/componentController.dart';
import 'package:inventory/src/features/main_app/fines/models/fine_model.dart';
import 'package:inventory/src/features/bulk_upload/services/bulk_upload_service.dart';
import 'package:inventory/src/utils/barcode_util.dart';

void main() {
  group('BulkUploadService Unit Tests', () {
    test(
        'Category routing resolves exact CSV category strings to expected Supabase tables',
        () {
      final mappings = {
        'ACTUATORS AND MOTORS': 'Actuators and Motors',
        'SENSORS': 'Sensors',
        'MICROCONTROLLER': 'Microcontroller',
        'DISPLAYS AND INDICATORS': 'Displays and Indicators',
        'MECHANICAL & HARDWARE': 'Others',
        'COMMUNICATION & INPUT MODULES': 'Communication Modules',
        'POWER COMPONENTS': 'Power Components',
        'TOOLS AND EQUIPMENT': 'Others',
      };

      for (final entry in mappings.entries) {
        final result = BulkUploadService.resolveCategoryForTest(entry.key);
        expect(result, equals(entry.value),
            reason: 'Category "${entry.key}" should route to "${entry.value}"');
      }
    });
  });

  group('FineModel Unit Tests', () {
    test(
        'FineModel.fromJson creates accurate model with default and enriched fields',
        () {
      final json = {
        'fine_id': 'fine_123',
        'member_id': 'D2024_01',
        'transaction_id': 'tx_999',
        'reason': 'Late return by 3 days',
        'amount': '150.0',
        'status': 'due',
        'name': 'Tanvi Jagade',
        'member_email': '2024.tanvi.jagade@ves.ac.in',
        'phonenumber': '9876543210',
        'component_name': 'Arduino Uno R3',
        'quantity': '2',
        'class': 'D12A',
        'issuedate': '2026-08-10',
        'returndate': '2026-08-15',
      };

      final fine = FineModel.fromJson(json);

      expect(fine.fineId, 'fine_123');
      expect(fine.memberId, 'D2024_01');
      expect(fine.amount, 150.0);
      expect(fine.status, 'due');
      expect(fine.isDue, isTrue);
      expect(fine.isPaid, isFalse);
      expect(fine.memberName, 'Tanvi Jagade');
      expect(fine.memberEmail, '2024.tanvi.jagade@ves.ac.in');
      expect(fine.componentName, 'Arduino Uno R3');
      expect(fine.quantity, 2);
      expect(fine.className, 'D12A');
    });

    test('FineModel status helper properties', () {
      final paidFine = FineModel(
        fineId: 'f1',
        memberId: 'm1',
        reason: 'Damage',
        amount: 250.0,
        status: 'paid',
      );
      expect(paidFine.isPaid, isTrue);
      expect(paidFine.isDue, isFalse);

      final pendingFine = FineModel(
        fineId: 'f2',
        memberId: 'm2',
        reason: 'Overdue',
        amount: 50.0,
        status: 'pending',
      );
      expect(pendingFine.isPaid, isFalse);
      expect(pendingFine.isDue, isTrue);
    });

    test('FineModel copyWith preserves unmodified fields and updates targets',
        () {
      final fine = FineModel(
        fineId: 'f100',
        memberId: 'm100',
        reason: 'Late',
        amount: 100.0,
        status: 'due',
      );

      final updated = fine.copyWith(
        status: 'paid',
        paidBy: 'Admin User',
        paidAt: '2026-08-18T10:00:00Z',
      );

      expect(updated.fineId, 'f100');
      expect(updated.amount, 100.0);
      expect(updated.status, 'paid');
      expect(updated.paidBy, 'Admin User');
      expect(updated.isPaid, isTrue);
    });
  });

  group('Cartcomponent Unit Tests', () {
    test('Cartcomponent serialization and deserialization', () {
      final item = Cartcomponent(
        compname: 'ESP32 NodeMCU',
        skuid: 'CM01',
        Quantity: 3,
      );

      final json = item.toJson();
      expect(json['compname'], 'ESP32 NodeMCU');
      expect(json['skuid'], 'CM01');
      expect(json['Quantity'], 3);

      item.Quantity += 2;
      expect(item.Quantity, 5);
    });
  });

  group('Component Unit Tests', () {
    test('Component model properties and sku verification', () {
      final comp = Component(
        name: 'Servo Motor SG90',
        boxNo: 'AM-01',
        stock: 12,
        availableStock: 10,
        issuedStock: 2,
        skuId: 'AM01-05',
        warning: 1,
      );

      expect(comp.name, 'Servo Motor SG90');
      expect(comp.boxNo, 'AM-01');
      expect(comp.stock, 12);
      expect(comp.availableStock, 10);
      expect(comp.issuedStock, 2);
      expect(comp.skuId, 'AM01-05');
      expect(comp.warning, 1);
    });

    test(
        'scanned SKU normalization trims scanner suffixes and canonicalizes case',
        () {
      expect(
        ComponentController.normalizeScannedIdentifier('  am01-05\r\n'),
        'AM01-05',
      );
    });

    test('Code 128 uses the valid checksum pattern for codeword 95', () {
      final barcode = BarcodeUtil.encodeToBinary('~');
      final stopIndex = barcode.lastIndexOf('1100011101011');

      expect(stopIndex, greaterThan(0));
      expect(
        barcode.substring(stopIndex - 11, stopIndex),
        '10111101000',
      );
    });
  });

  group('Emailcontroller Unit Tests', () {
    test(
        'formatNameFromEmail parses student and faculty email formats correctly',
        () {
      expect(
        Emailcontroller.formatNameFromEmail('2024.tanvi.jagade@ves.ac.in'),
        'Tanvi Jagade',
      );
      expect(
        Emailcontroller.formatNameFromEmail('n.gopalkrishnan@ves.ac.in'),
        'N Gopalkrishnan',
      );
      expect(
        Emailcontroller.formatNameFromEmail('2024.dhruv.sangam@ves.ac.in'),
        'Dhruv Sangam',
      );
    });

    test('Emailcontroller dynamic observables initialize properly', () {
      final ctrl = Emailcontroller();
      expect(ctrl.emails, isA<List<String>>());
      expect(ctrl.emailToName, isA<Map<String, String>>());
      expect(ctrl.isValidating.value, isFalse);
    });
  });
}
