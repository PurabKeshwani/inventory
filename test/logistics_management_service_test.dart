import 'package:flutter_test/flutter_test.dart';
import 'package:inventory/src/features/logistics/logistics_management_service.dart';

void main() {
  group('booking filters and transitions', () {
    final booking = <String, dynamic>{
      'member_id': 'VES123',
      'member_email': 'person@example.edu',
      'slot': '13:00-13:30',
      'status': 'booked',
    };

    test('search matches member ID or email while retaining slot filter', () {
      expect(
        LogisticsManagementService.bookingMatchesFilters(
          booking,
          slot: '13:00-13:30',
          search: 'ves1',
        ),
        isTrue,
      );
      expect(
        LogisticsManagementService.bookingMatchesFilters(
          booking,
          slot: 'All Slots',
          search: 'EXAMPLE.EDU',
        ),
        isTrue,
      );
      expect(
        LogisticsManagementService.bookingMatchesFilters(
          booking,
          slot: '15:30-16:00',
          search: 'ves123',
        ),
        isFalse,
      );
    });

    test('only booked bookings can transition to terminal statuses', () {
      expect(
        LogisticsManagementService.canTransitionBooking('booked', 'completed'),
        isTrue,
      );
      expect(
        LogisticsManagementService.canTransitionBooking('booked', 'no_show'),
        isTrue,
      );
      expect(
        LogisticsManagementService.canTransitionBooking('completed', 'no_show'),
        isFalse,
      );
    });
  });

  group('print queue ordering and validation', () {
    test(
        'queue positions sort first and null positions fall back to submission',
        () {
      final records = <Map<String, dynamic>>[
        {
          'id': 'late-null',
          'queue_position': null,
          'submitted_at': '2026-01-03'
        },
        {'id': 'position-2', 'queue_position': 2, 'submitted_at': '2026-01-02'},
        {
          'id': 'early-null',
          'queue_position': null,
          'submitted_at': '2026-01-01'
        },
        {'id': 'position-1', 'queue_position': 1, 'submitted_at': '2026-01-04'},
      ]..sort(LogisticsManagementService.compareQueueRecords);

      expect(records.map((row) => row['id']), [
        'position-1',
        'position-2',
        'early-null',
        'late-null',
      ]);
    });

    test('project names and optional positive positions are validated', () {
      expect(LogisticsManagementService.validateProjectName('  '), isNotNull);
      expect(LogisticsManagementService.validateProjectName('Bracket'), isNull);
      expect(LogisticsManagementService.parseQueuePosition(''), isNull);
      expect(LogisticsManagementService.parseQueuePosition('3'), 3);
      expect(LogisticsManagementService.parseQueuePosition('0'), isNull);
      expect(LogisticsManagementService.parseQueuePosition('-2'), isNull);
      expect(LogisticsManagementService.parseQueuePosition('one'), isNull);
    });
  });
}
