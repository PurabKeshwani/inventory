import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inventory/src/features/logistics/logistics_management_service.dart';
import 'package:inventory/src/utils/theme/theme.dart';

class PrintQueueManagementScreen extends StatefulWidget {
  const PrintQueueManagementScreen({super.key});

  @override
  State<PrintQueueManagementScreen> createState() =>
      _PrintQueueManagementScreenState();
}

class _PrintQueueManagementScreenState
    extends State<PrintQueueManagementScreen> {
  final _service = LogisticsManagementService();
  final _name = TextEditingController();
  final _position = TextEditingController();
  DateTime _submittedAt = DateTime.now();
  List<Map<String, dynamic>> _records = [];
  bool _loading = true;
  bool _authorized = false;
  bool _saving = false;
  bool _showHistory = false;
  String? _error;

  List<Map<String, dynamic>> get _active =>
      _records.where((row) => row['status'] == 'printing').toList();
  List<Map<String, dynamic>> get _waiting =>
      _records.where((row) => row['status'] == 'queued').toList();
  List<Map<String, dynamic>> get _completed =>
      _records.where((row) => row['status'] == 'completed').toList()
        ..sort((a, b) => LogisticsManagementService.compareQueueRecords(b, a));

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _position.dispose();
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
          _records = [];
          _loading = false;
        });
        return;
      }
      final records = await _service.fetchPrintQueue();
      if (!mounted) return;
      setState(() {
        _authorized = true;
        _records = records;
        _loading = false;
      });
    } catch (error) {
      debugPrint('Print queue load failed: $error');
      if (!mounted) return;
      setState(() {
        _error =
            'Could not load the print queue. Check your connection and access.';
        _loading = false;
      });
    }
  }

  Future<void> _addProject() async {
    final name = _name.text.trim();
    final positionText = _position.text.trim();
    final position =
        LogisticsManagementService.parseQueuePosition(positionText);
    final nameError = LogisticsManagementService.validateProjectName(name);
    if (nameError != null || (positionText.isNotEmpty && position == null)) {
      _feedback(nameError ??
          'Enter a positive whole-number queue position, if supplied.');
      return;
    }
    setState(() => _saving = true);
    try {
      await _service.addPrintProject(
          projectName: name,
          submittedAt: _submittedAt,
          queuePosition: position);
      _name.clear();
      _position.clear();
      _feedback('Project added to the waiting queue.');
      await _load();
    } catch (error) {
      debugPrint('Add print project failed: $error');
      _feedback('Could not add project. Check your access and connection.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _chooseSubmittedAt() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _submittedAt,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(_submittedAt));
    if (time == null || !mounted) return;
    setState(() => _submittedAt =
        DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<bool> _confirm(String title, String message, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(action)),
          ],
        ),
      ) ??
      false;

  Future<void> _start(Map<String, dynamic> project) async {
    final id = project['id']?.toString() ?? '';
    if (id.isEmpty || _active.isNotEmpty) return;
    setState(() => _saving = true);
    try {
      final started = await _service.startPrint(id);
      if (!started) {
        _feedback(
            'A print may already be active, or this project changed. Refresh the queue.');
      } else {
        _feedback('Printing started.');
      }
      await _load();
    } catch (error) {
      debugPrint('Start print failed: $error');
      _feedback('Could not start printing. Check your access and connection.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _complete(Map<String, dynamic> project) async {
    final confirmed = await _confirm(
      'Complete print?',
      'Mark “${project['project_name']}” as completed?',
      'Complete',
    );
    if (!mounted || !confirmed) {
      return;
    }
    setState(() => _saving = true);
    try {
      final changed = await _service.completePrint(project['id'].toString());
      _feedback(changed
          ? 'Print marked completed.'
          : 'Project changed elsewhere. Refresh the queue.');
      await _load();
    } catch (error) {
      debugPrint('Complete print failed: $error');
      _feedback('Could not complete print. Check your access and connection.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _cancel(Map<String, dynamic> project) async {
    final confirmed = await _confirm(
      'Remove queued project?',
      'Delete “${project['project_name']}” from the waiting queue?',
      'Delete',
    );
    if (!mounted || !confirmed) {
      return;
    }
    setState(() => _saving = true);
    try {
      final deleted =
          await _service.deleteQueuedProject(project['id'].toString());
      _feedback(deleted
          ? 'Queued project removed.'
          : 'Project changed elsewhere. Refresh the queue.');
      await _load();
    } catch (error) {
      debugPrint('Delete queued project failed: $error');
      _feedback('Could not remove project. Check your access and connection.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _move(int index, int delta) async {
    final target = index + delta;
    if (target < 0 || target >= _waiting.length || _saving) return;
    final reordered = [..._waiting];
    final item = reordered.removeAt(index);
    reordered.insert(target, item);
    setState(() => _saving = true);
    try {
      await _service.reorderWaiting(reordered);
      await _load();
    } catch (error) {
      debugPrint('Reorder print queue failed: $error');
      _feedback('Could not reorder the queue. Refresh and try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _feedback(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  String _time(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (parsed == null) return 'Time unavailable';
    final hour = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
    return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}  ${hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')} ${parsed.hour >= 12 ? 'PM' : 'AM'}';
  }

  @override
  Widget build(BuildContext context) {
    final primary = CAppTheme.primaryTextColor(context);
    final secondary = CAppTheme.secondaryTextColor(context);
    final active = _active;
    final waiting = _waiting;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('3D Printing Queue'), actions: [
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
                  ? _message(Icons.lock_outline, 'Admin access required',
                      'Sign in with an authorized logistics/admin account.')
                  : _error != null
                      ? _message(Icons.cloud_off_outlined, 'Queue unavailable',
                          _error!,
                          retry: _load)
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              if (active.length > 1)
                                _warning(
                                    '${active.length} projects are marked as printing. Resolve this data-integrity conflict in the queue before starting another project.'),
                              _infoBanner(
                                'Start Printing checks the current queue before updating. Simultaneous starts from separate devices require a database constraint or RPC to serialize safely.',
                              ),
                              _sectionTitle(
                                  'Currently Printing', Icons.print_outlined),
                              if (active.isEmpty)
                                _empty('No project is currently being printed.',
                                    secondary)
                              else
                                ...active.map((project) => _projectCard(project,
                                    status: 'printing',
                                    primary: primary,
                                    secondary: secondary)),
                              const SizedBox(height: 10),
                              _sectionTitle(
                                  'Waiting Queue  ·  ${waiting.length}',
                                  Icons.format_list_numbered),
                              if (waiting.isEmpty)
                                _empty('No projects waiting in the queue.',
                                    secondary)
                              else
                                ...waiting.asMap().entries.map((entry) =>
                                    _waitingCard(entry.key, entry.value,
                                        primary, secondary, active.isEmpty)),
                              const SizedBox(height: 18),
                              _sectionTitle(
                                  'Add Project', Icons.add_circle_outline),
                              _addForm(primary, secondary),
                              const SizedBox(height: 14),
                              OutlinedButton.icon(
                                onPressed: () => setState(
                                    () => _showHistory = !_showHistory),
                                icon: Icon(_showHistory
                                    ? Icons.expand_less
                                    : Icons.history),
                                label: Text(_showHistory
                                    ? 'Hide completed history'
                                    : 'Completed history (${_completed.length})'),
                              ),
                              if (_showHistory)
                                ..._completed.map((project) => _projectCard(
                                    project,
                                    status: 'completed',
                                    primary: primary,
                                    secondary: secondary)),
                            ],
                          ),
                        ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(title,
              style: GoogleFonts.montserrat(
                  color: CAppTheme.primaryTextColor(context),
                  fontWeight: FontWeight.bold,
                  fontSize: 16))
        ]),
      );

  Widget _addForm(Color primary, Color secondary) => Card(
        color: Theme.of(context).cardTheme.color,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            TextField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                    labelText: 'Project name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.view_in_ar_outlined))),
            const SizedBox(height: 10),
            Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                      onPressed: _chooseSubmittedAt,
                      icon: const Icon(Icons.schedule),
                      label: Text(_time(_submittedAt.toIso8601String()))),
                  SizedBox(
                      width: 160,
                      child: TextField(
                          controller: _position,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Queue position (optional)',
                              border: OutlineInputBorder()))),
                ]),
            const SizedBox(height: 10),
            SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                    onPressed: _saving ? null : _addProject,
                    icon: const Icon(Icons.add),
                    label: Text(_saving ? 'Please wait…' : 'Add to Queue'))),
          ]),
        ),
      );

  Widget _projectCard(Map<String, dynamic> project,
          {required String status,
          required Color primary,
          required Color secondary}) =>
      Card(
        color: Theme.of(context).cardTheme.color,
        child: ListTile(
          leading: CircleAvatar(
              backgroundColor:
                  Theme.of(context).colorScheme.primary.withValues(alpha: .13),
              child: Icon(status == 'printing' ? Icons.print : Icons.check,
                  color: Theme.of(context).colorScheme.primary)),
          title: Text((project['project_name'] ?? 'Unnamed project').toString(),
              style: TextStyle(color: primary, fontWeight: FontWeight.w600)),
          subtitle: Text('Submitted ${_time(project['submitted_at'])}',
              style: TextStyle(color: secondary)),
          trailing: status == 'printing'
              ? IconButton(
                  tooltip: 'Complete print',
                  onPressed: _saving ? null : () => _complete(project),
                  icon: const Icon(Icons.task_alt, color: Colors.green))
              : _badge(status),
        ),
      );

  Widget _waitingCard(int index, Map<String, dynamic> project, Color primary,
          Color secondary, bool canStart) =>
      Card(
        color: Theme.of(context).cardTheme.color,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(radius: 15, child: Text('${index + 1}')),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(
                      (project['project_name'] ?? 'Unnamed project').toString(),
                      style: TextStyle(
                          color: primary, fontWeight: FontWeight.w600))),
              _badge('queued')
            ]),
            Padding(
                padding: const EdgeInsets.only(left: 40, top: 3),
                child: Text('Submitted ${_time(project['submitted_at'])}',
                    style: TextStyle(color: secondary, fontSize: 12))),
            const SizedBox(height: 5),
            Wrap(alignment: WrapAlignment.end, children: [
              IconButton(
                  tooltip: 'Move up',
                  onPressed:
                      _saving || index == 0 ? null : () => _move(index, -1),
                  icon: const Icon(Icons.arrow_upward)),
              IconButton(
                  tooltip: 'Move down',
                  onPressed: _saving || index == _waiting.length - 1
                      ? null
                      : () => _move(index, 1),
                  icon: const Icon(Icons.arrow_downward)),
              TextButton(
                  onPressed: _saving ? null : () => _cancel(project),
                  child: const Text('Cancel')),
              FilledButton.icon(
                  onPressed:
                      _saving || !canStart ? null : () => _start(project),
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('Start')),
            ]),
          ]),
        ),
      );

  Widget _badge(String status) {
    final color = status == 'completed'
        ? Colors.green
        : status == 'printing'
            ? Colors.orange
            : Theme.of(context).colorScheme.primary;
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(16)),
        child: Text(status.toUpperCase(),
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.bold)));
  }

  Widget _warning(String text) => Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Icon(Icons.warning_amber_rounded,
                color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 8),
            Expanded(
                child: Text(text,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer)))
          ])));

  Widget _infoBanner(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(text,
          style: TextStyle(
              color: CAppTheme.secondaryTextColor(context), fontSize: 12)));

  Widget _empty(String text, Color secondary) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
          child: Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(color: secondary))));

  Widget _message(IconData icon, String title, String detail,
          {VoidCallback? retry}) =>
      Center(
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon,
                    size: 44, color: CAppTheme.secondaryTextColor(context)),
                const SizedBox(height: 12),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(detail, textAlign: TextAlign.center),
                if (retry != null) ...[
                  const SizedBox(height: 12),
                  FilledButton(onPressed: retry, child: const Text('Retry'))
                ]
              ])));
}
