import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Database operations used by the logistics management screens.
/// Supabase RLS remains the authority for all reads and writes.
class LogisticsManagementService {
  LogisticsManagementService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static bool bookingMatchesFilters(
    Map<String, dynamic> booking, {
    required String slot,
    required String search,
  }) {
    final slotMatches = slot == 'All Slots' || booking['slot'] == slot;
    final query = search.trim().toLowerCase();
    final memberId = (booking['member_id'] ?? '').toString().toLowerCase();
    final email = (booking['member_email'] ?? '').toString().toLowerCase();
    return slotMatches &&
        (query.isEmpty || memberId.contains(query) || email.contains(query));
  }

  static bool canTransitionBooking(String current, String next) =>
      current == 'booked' && (next == 'completed' || next == 'no_show');

  static int? parseQueuePosition(String value) {
    if (value.trim().isEmpty) return null;
    final parsed = int.tryParse(value.trim());
    return parsed != null && parsed > 0 ? parsed : null;
  }

  static String? validateProjectName(String name) =>
      name.trim().isEmpty ? 'Project name is required.' : null;

  Future<bool> isAuthorizedAdmin() async {
    final email = _client.auth.currentUser?.email?.trim();
    if (email == null || email.isEmpty) return false;
    try {
      final rows = await _client
          .from('admins')
          .select('emailid')
          .ilike('emailid', email)
          .limit(1);
      return rows.isNotEmpty;
    } catch (error, stackTrace) {
      debugPrint('Logistics authorization check failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchBookings(String date) async {
    final rows = await _client
        .from('component_issue_bookings')
        .select('*')
        .eq('booking_date', date)
        .order('slot')
        .order('created_at')
        .order('id');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<bool> updateBookingStatus(String id, String status) async {
    if (!canTransitionBooking('booked', status)) return false;
    final now = DateTime.now().toUtc().toIso8601String();
    final update = <String, dynamic>{'status': status, 'updated_at': now};
    if (status == 'completed') {
      update['completed_at'] = now;
    }
    final rows = await _client
        .from('component_issue_bookings')
        .update(update)
        .eq('id', id)
        .eq('status', 'booked')
        .select('id');
    return rows.isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> fetchPrintQueue() async {
    final rows = await _client.from('print_queue').select('*');
    final records = List<Map<String, dynamic>>.from(rows);
    records.sort(compareQueueRecords);
    return records;
  }

  static int compareQueueRecords(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    final aPosition = _positivePosition(a['queue_position']);
    final bPosition = _positivePosition(b['queue_position']);
    if (aPosition != null && bPosition != null) {
      final position = aPosition.compareTo(bPosition);
      if (position != 0) return position;
    } else if (aPosition != null) {
      return -1;
    } else if (bPosition != null) {
      return 1;
    }
    final submitted =
        _date(a['submitted_at']).compareTo(_date(b['submitted_at']));
    if (submitted != 0) return submitted;
    final created = _date(a['created_at']).compareTo(_date(b['created_at']));
    if (created != 0) return created;
    return (a['id'] ?? '').toString().compareTo((b['id'] ?? '').toString());
  }

  static int? _positivePosition(dynamic value) {
    final parsed = value is num ? value.toInt() : int.tryParse('$value');
    return parsed != null && parsed > 0 ? parsed : null;
  }

  static DateTime _date(dynamic value) =>
      DateTime.tryParse(value?.toString() ?? '') ?? DateTime(9999);

  Future<void> addPrintProject({
    required String projectName,
    required DateTime submittedAt,
    int? queuePosition,
  }) async {
    await _client.from('print_queue').insert({
      'project_name': projectName.trim(),
      'submitted_at': submittedAt.toUtc().toIso8601String(),
      'status': 'queued',
      if (queuePosition != null) 'queue_position': queuePosition,
    });
  }

  /// Returns false if another print is active or this record is no longer queued.
  /// This client-side guard is best effort; a database RPC/constraint is required
  /// to serialize simultaneous starts across clients.
  Future<bool> startPrint(String id) async {
    final active =
        await _client.from('print_queue').select('id').eq('status', 'printing');
    if (active.isNotEmpty) return false;
    final updated = await _client
        .from('print_queue')
        .update({
          'status': 'printing',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id)
        .eq('status', 'queued')
        .select('id');
    return updated.isNotEmpty;
  }

  Future<bool> completePrint(String id) async {
    final updated = await _client
        .from('print_queue')
        .update({
          'status': 'completed',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id)
        .eq('status', 'printing')
        .select('id');
    return updated.isNotEmpty;
  }

  Future<bool> deleteQueuedProject(String id) async {
    final deleted = await _client
        .from('print_queue')
        .delete()
        .eq('id', id)
        .eq('status', 'queued')
        .select('id');
    return deleted.isNotEmpty;
  }

  Future<void> reorderWaiting(List<Map<String, dynamic>> waiting) async {
    // Sequential updates avoid batching unsupported by PostgREST. This is not
    // transactional; the server remains authoritative if another user edits.
    for (var index = 0; index < waiting.length; index++) {
      final id = waiting[index]['id']?.toString();
      if (id == null || id.isEmpty) continue;
      await _client
          .from('print_queue')
          .update({
            'queue_position': index + 1,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', id)
          .eq('status', 'queued');
    }
  }
}
