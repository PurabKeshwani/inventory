import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inventory/src/features/logistics/logistics_management_service.dart';
import 'package:inventory/src/utils/theme/theme.dart';

class ComponentIssueBookingsScreen extends StatefulWidget {
  const ComponentIssueBookingsScreen({super.key});

  @override
  State<ComponentIssueBookingsScreen> createState() =>
      _ComponentIssueBookingsScreenState();
}

class _ComponentIssueBookingsScreenState
    extends State<ComponentIssueBookingsScreen> {
  final _service = LogisticsManagementService();
  final _search = TextEditingController();
  DateTime _date = _todayInIst();
  String _slot = 'All Slots';
  List<Map<String, dynamic>> _bookings = [];
  final Set<String> _busyIds = {};
  bool _loading = true;
  bool _authorized = false;
  String? _error;

  static DateTime _todayInIst() {
    final now =
        DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    return DateTime(now.year, now.month, now.day);
  }

  String get _dateKey =>
      '${_date.year.toString().padLeft(4, '0')}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final authorized = await _service.isAuthorizedAdmin();
      if (!mounted) return;
      if (!authorized) {
        setState(() {
          _authorized = false;
          _bookings = [];
          _loading = false;
        });
        return;
      }
      final bookings = await _service.fetchBookings(_dateKey);
      if (!mounted) return;
      setState(() {
        _authorized = true;
        _bookings = bookings;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load bookings. Check your connection and access.';
        _loading = false;
      });
      debugPrint('Component booking load failed: $error');
    }
  }

  List<Map<String, dynamic>> get _visibleBookings {
    return _bookings.where((booking) {
      return LogisticsManagementService.bookingMatchesFilters(
        booking,
        slot: _slot,
        search: _search.text,
      );
    }).toList();
  }

  Future<void> _chooseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Select booking date',
    );
    if (picked == null || !mounted) return;
    setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    await _load();
  }

  Future<void> _changeStatus(
      Map<String, dynamic> booking, String status) async {
    final id = booking['id']?.toString() ?? '';
    if (id.isEmpty || _busyIds.contains(id)) return;
    final action = status == 'completed'
        ? 'mark this booking issued'
        : 'mark this booking as a no-show';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title:
            Text(status == 'completed' ? 'Complete booking?' : 'Mark no-show?'),
        content: Text(
            'Are you sure you want to $action? This action is available only while the booking is booked.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Confirm')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busyIds.add(id));
    try {
      final updated = await _service.updateBookingStatus(id, status);
      if (!mounted) return;
      if (!updated) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Booking changed elsewhere. Refresh and try again.')),
        );
      } else {
        setState(() {
          final index =
              _bookings.indexWhere((row) => row['id']?.toString() == id);
          if (index >= 0) {
            _bookings[index] = {
              ..._bookings[index],
              'status': status,
              if (status == 'completed')
                'completed_at': DateTime.now().toUtc().toIso8601String(),
            };
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(status == 'completed'
                  ? 'Booking marked completed.'
                  : 'Booking marked no-show.')),
        );
      }
    } catch (error) {
      debugPrint('Component booking update failed: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Could not update booking. Check your access and connection.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  String _dateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  @override
  Widget build(BuildContext context) {
    final primary = CAppTheme.primaryTextColor(context);
    final secondary = CAppTheme.secondaryTextColor(context);
    final accent = Theme.of(context).colorScheme.primary;
    final visible = _visibleBookings;
    final counts = <String, int>{
      'booked': visible.where((row) => row['status'] == 'booked').length,
      'completed': visible.where((row) => row['status'] == 'completed').length,
      'no_show': visible.where((row) => row['status'] == 'no_show').length,
    };

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Component Issue Bookings'), actions: [
        IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh))
      ]),
      body: Container(
        decoration: BoxDecoration(gradient: CAppTheme.bgGradient(context)),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : !_authorized
                  ? _message(
                      context,
                      Icons.lock_outline,
                      'Admin access required',
                      'Sign in with an authorized logistics/admin account.')
                  : _error != null
                      ? _message(context, Icons.cloud_off_outlined,
                          'Bookings unavailable', _error!,
                          action: _load)
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              Wrap(spacing: 10, runSpacing: 10, children: [
                                OutlinedButton.icon(
                                    onPressed: _chooseDate,
                                    icon: const Icon(Icons.calendar_month),
                                    label: Text(_dateLabel(_date))),
                                DropdownButton<String>(
                                  value: _slot,
                                  items: const [
                                    'All Slots',
                                    '13:00-13:30',
                                    '15:30-16:00'
                                  ]
                                      .map((slot) => DropdownMenuItem(
                                          value: slot, child: Text(slot)))
                                      .toList(),
                                  onChanged: (value) => setState(
                                      () => _slot = value ?? 'All Slots'),
                                ),
                              ]),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _search,
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(
                                    prefixIcon: Icon(Icons.search),
                                    labelText: 'Search member ID or email',
                                    border: OutlineInputBorder()),
                              ),
                              const SizedBox(height: 12),
                              Wrap(spacing: 8, runSpacing: 8, children: [
                                _countChip(
                                    'Booked', counts['booked']!, Colors.blue),
                                _countChip('Completed', counts['completed']!,
                                    Colors.green),
                                _countChip('No-show', counts['no_show']!,
                                    Colors.orange),
                              ]),
                              const SizedBox(height: 12),
                              if (visible.isEmpty)
                                _empty(primary, secondary)
                              else
                                ...visible.map((booking) => _bookingCard(
                                    booking, primary, secondary, accent)),
                            ],
                          ),
                        ),
        ),
      ),
    );
  }

  Widget _countChip(String label, int count, Color color) => Chip(
        avatar: CircleAvatar(backgroundColor: color, radius: 5),
        label: Text('$label: $count'),
      );

  Widget _bookingCard(Map<String, dynamic> booking, Color primary,
      Color secondary, Color accent) {
    final id = booking['id']?.toString() ?? '';
    final status = (booking['status'] ?? 'unknown').toString();
    final busy = _busyIds.contains(id);
    return Card(
      color: Theme.of(context).cardTheme.color,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text((booking['member_name'] ?? 'Member').toString(),
                    style: GoogleFonts.montserrat(
                        color: primary, fontWeight: FontWeight.bold))),
            _statusBadge(status)
          ]),
          const SizedBox(height: 8),
          _detail(Icons.badge_outlined, 'ID: ${booking['member_id'] ?? '—'}',
              secondary),
          _detail(Icons.email_outlined, '${booking['member_email'] ?? '—'}',
              secondary),
          _detail(
              Icons.calendar_today_outlined,
              '${booking['booking_date'] ?? _dateKey}  ·  ${booking['slot'] ?? '—'}',
              secondary),
          if (status == 'booked') ...[
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              FilledButton.icon(
                  onPressed:
                      busy ? null : () => _changeStatus(booking, 'completed'),
                  icon: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check, size: 18),
                  label: const Text('Issued / Completed')),
              OutlinedButton.icon(
                  onPressed:
                      busy ? null : () => _changeStatus(booking, 'no_show'),
                  icon: const Icon(Icons.person_off_outlined, size: 18),
                  label: const Text('No-show')),
            ]),
          ],
        ]),
      ),
    );
  }

  Widget _detail(IconData icon, String text, Color color) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 7),
          Expanded(
              child: Text(text,
                  style: TextStyle(color: color),
                  overflow: TextOverflow.ellipsis))
        ]),
      );

  Widget _statusBadge(String status) {
    final color = switch (status) {
      'completed' => Colors.green,
      'no_show' => Colors.orange,
      'booked' => Theme.of(context).colorScheme.primary,
      _ => Theme.of(context).colorScheme.error,
    };
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(20)),
        child: Text(status.replaceAll('_', ' ').toUpperCase(),
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.bold)));
  }

  Widget _empty(Color primary, Color secondary) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 54),
        child: Column(children: [
          Icon(Icons.event_busy_outlined, size: 44, color: secondary),
          const SizedBox(height: 12),
          Text('No bookings for this date and filter.',
              style: TextStyle(color: primary)),
          const SizedBox(height: 5),
          Text('Pull down to refresh or choose another date.',
              style: TextStyle(color: secondary))
        ]),
      );

  Widget _message(
          BuildContext context, IconData icon, String title, String detail,
          {VoidCallback? action}) =>
      Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 44, color: CAppTheme.secondaryTextColor(context)),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(detail, textAlign: TextAlign.center),
            if (action != null) ...[
              const SizedBox(height: 12),
              FilledButton(onPressed: action, child: const Text('Retry'))
            ]
          ]),
        ),
      );
}
