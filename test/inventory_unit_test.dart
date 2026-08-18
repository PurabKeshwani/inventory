import 'package:flutter_test/flutter_test.dart';
import 'package:inventory/src/data/Cartcomponent.dart';
import 'package:inventory/src/data/model.dart';
import 'package:inventory/src/features/authentication/controllers/emailcontroller.dart';
import 'package:inventory/src/features/main_app/fines/models/fine_model.dart';

void main() {
  group('FineModel Unit Tests', () {
    test('FineModel.fromJson creates accurate model with default and enriched fields', () {
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

    test('FineModel copyWith preserves unmodified fields and updates targets', () {
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
        isIssued: false,
        skuid: 'AM01-05',
        warning: 'Handle gear with care',
      );

      expect(comp.name, 'Servo Motor SG90');
      expect(comp.boxNo, 'AM-01');
      expect(comp.stock, 12);
      expect(comp.isIssued, isFalse);
      expect(comp.skuid, 'AM01-05');
      expect(comp.warning, 'Handle gear with care');
    });
  });

  group('Emailcontroller Unit Tests', () {
    test('Emailcontroller emails list contains expected lab admins', () {
      final ctrl = Emailcontroller();
      expect(ctrl.emails.contains('2024.tanvi.jagade@ves.ac.in'), isTrue);
      expect(ctrl.emails.contains('n.gopalkrishnan@ves.ac.in'), isTrue);
      expect(ctrl.emailToName['2024.tanvi.jagade@ves.ac.in'], 'Tanvi Jagade');
    });
  });
}
