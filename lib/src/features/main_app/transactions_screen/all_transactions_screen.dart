import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory/src/controllers/cache_controller.dart';
import 'package:inventory/src/features/authentication/controllers/componentController.dart';
import 'package:inventory/src/features/main_app/fines/models/fine_model.dart';
import 'package:inventory/src/features/main_app/fines/services/fine_service.dart';
import 'package:inventory/src/services/email_reminder_service.dart';
import 'package:inventory/src/utils/theme/theme.dart';

class AllTransactionsScreen extends StatefulWidget {
  final int initialTabIndex; // 0: Current Due, 1: All Past

  const AllTransactionsScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<AllTransactionsScreen> createState() => _AllTransactionsScreenState();
}

class _AllTransactionsScreenState extends State<AllTransactionsScreen>
    with SingleTickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;
  final FineService _fineService = FineService();
  final ComponentController _componentController = Get.find<ComponentController>();

  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String _searchQuery = '';
  List<Map<String, dynamic>> _allTransactions = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
    _loadTransactions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _supabase
          .from('Transactions')
          .select()
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> list = [];
      for (var row in response as List<dynamic>) {
        if (row is Map<String, dynamic>) {
          list.add(Map<String, dynamic>.from(row));
        }
      }

      // Sort latest first
      list.sort((a, b) {
        final aTime = DateTime.tryParse(a['created_at']?.toString() ?? '') ??
            _parseDate(a['issuedate']?.toString());
        final bTime = DateTime.tryParse(b['created_at']?.toString() ?? '') ??
            _parseDate(b['issuedate']?.toString());

        if (aTime != null && bTime != null) {
          return bTime.compareTo(aTime);
        }
        return (b['transaction_id']?.toString() ?? '')
            .compareTo(a['transaction_id']?.toString() ?? '');
      });

      if (mounted) {
        setState(() {
          _allTransactions = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load transactions: $e'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    }
  }

  bool _isSendingBulkEmail = false;

  Future<void> _sendSingleDueReminder(Map<String, dynamic> tx) async {
    final memberId = tx['id']?.toString() ?? '';
    final borrowerName = tx['name']?.toString() ?? 'Student';
    final txId = tx['transaction_id']?.toString() ?? '';
    final issueDate = tx['issuedate']?.toString() ?? '';
    final returnDate = tx['returndate']?.toString() ?? 'Immediate';
    final pkgList = _parsePackage(tx['package']);

    final email = await EmailReminderService.resolveMemberEmail(
      memberIdOrEmail: memberId,
    );

    if (email == null || !email.contains('@')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No verified email found for $borrowerName ($memberId)'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
      return;
    }

    try {
      final compNames = pkgList
          .map((i) => '${i['compname'] ?? i['name'] ?? 'Component'} (Qty: ${i['Quantity'] ?? i['quantity'] ?? 1})')
          .toList();

      await EmailReminderService.sendDueReminderEmail(
        toEmail: email,
        memberName: borrowerName,
        transactionId: txId,
        issueDate: issueDate,
        expectedReturnDate: returnDate,
        componentNames: compNames.isNotEmpty ? compNames : ['Borrowed Hardware Component'],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reminder email sent to $email successfully!'),
            backgroundColor: const Color(0xff15803D),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send email: $e'),
            backgroundColor: Colors.red[700],
            action: SnackBarAction(
              label: 'SETTINGS',
              textColor: Colors.white,
              onPressed: () => EmailReminderService.showEmailConfigDialog(context),
            ),
          ),
        );
      }
    }
  }

  Future<void> _sendBulkDueReminders(List<Map<String, dynamic>> dueList) async {
    if (dueList.isEmpty || _isSendingBulkEmail) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Send Due Reminders to All?',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'This will send automated overdue return emails from "isa.vesit@ves.ac.in" to all ${dueList.length} members with currently borrowed components.',
          style: GoogleFonts.lato(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff19335A),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Send to ${dueList.length} Members'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSendingBulkEmail = true);

    int sentCount = 0;
    int failedCount = 0;

    for (final tx in dueList) {
      try {
        final memberId = tx['id']?.toString() ?? '';
        final borrowerName = tx['name']?.toString() ?? 'Student';
        final txId = tx['transaction_id']?.toString() ?? '';
        final issueDate = tx['issuedate']?.toString() ?? '';
        final returnDate = tx['returndate']?.toString() ?? 'Immediate';
        final pkgList = _parsePackage(tx['package']);

        final email = await EmailReminderService.resolveMemberEmail(
          memberIdOrEmail: memberId,
        );

        if (email != null && email.contains('@')) {
          final compNames = pkgList
              .map((i) => '${i['compname'] ?? i['name'] ?? 'Component'} (Qty: ${i['Quantity'] ?? i['quantity'] ?? 1})')
              .toList();

          await EmailReminderService.sendDueReminderEmail(
            toEmail: email,
            memberName: borrowerName,
            transactionId: txId,
            issueDate: issueDate,
            expectedReturnDate: returnDate,
            componentNames: compNames.isNotEmpty ? compNames : ['Borrowed Hardware Component'],
          );
          sentCount++;
        } else {
          failedCount++;
        }
      } catch (_) {
        failedCount++;
      }
    }

    if (mounted) {
      setState(() => _isSendingBulkEmail = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dispatched $sentCount due reminder emails ($failedCount skipped/failed).'),
          backgroundColor: sentCount > 0 ? const Color(0xff15803D) : Colors.orange[800],
        ),
      );
    }
  }

  DateTime? _parseDate(String? d) {
    if (d == null || d.isEmpty) return null;
    try {
      final parts = d.split('/');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        return DateTime(year, month, day);
      }
    } catch (_) {}
    return null;
  }

  // Filter transactions based on active status and search query
  List<Map<String, dynamic>> _filterTransactions({required bool isDueOnly}) {
    return _allTransactions.where((tx) {
      final status = (tx['status']?.toString() ?? 'Issued').trim().toLowerCase();
      final isReturned = status == 'returned' ||
          status == 'return' ||
          status == 'returned to inventory' ||
          status == 'closed';

      if (isDueOnly && isReturned) return false;
      if (!isDueOnly && !isReturned) return false;

      if (_searchQuery.isEmpty) return true;

      final query = _searchQuery.toLowerCase();
      final name = (tx['name']?.toString() ?? '').toLowerCase();
      final memberId = (tx['id']?.toString() ?? '').toLowerCase();
      final txId = (tx['transaction_id']?.toString() ?? '').toLowerCase();
      final division = (tx['class']?.toString() ?? '').toLowerCase();
      final phone = (tx['phonenumber']?.toString() ?? '').toLowerCase();

      // Check package component names
      final pkg = _parsePackage(tx['package']);
      final hasMatchingComp = pkg.any((item) {
        final cName = (item['compname'] ?? item['name'] ?? '').toString().toLowerCase();
        final sku = (item['skuid'] ?? '').toString().toLowerCase();
        return cName.contains(query) || sku.contains(query);
      });

      return name.contains(query) ||
          memberId.contains(query) ||
          txId.contains(query) ||
          division.contains(query) ||
          phone.contains(query) ||
          hasMatchingComp;
    }).toList();
  }

  List<Map<String, dynamic>> _parsePackage(dynamic packageRaw) {
    if (packageRaw == null) return [];
    if (packageRaw is List) {
      return packageRaw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (packageRaw is String) {
      try {
        final decoded = jsonDecode(packageRaw);
        if (decoded is List) {
          return decoded
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      } catch (_) {}
    }
    return [];
  }

  // Mark transaction as returned & restore component stock
  Future<void> _markAsReturned(Map<String, dynamic> tx) async {
    final txId = tx['transaction_id']?.toString() ?? '';
    if (txId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.assignment_turned_in_rounded, color: Colors.green, size: 24),
            const SizedBox(width: 8),
            Text(
              'Confirm Return',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: const Color(0xff19335A),
              ),
            ),
          ],
        ),
        content: Text(
          'Mark Transaction #$txId as Returned?\nThis will automatically restore stock for all included components into the database.',
          style: GoogleFonts.lato(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.lato(color: Colors.grey[700])),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Mark Returned', style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final pkgList = _parsePackage(tx['package']);

      for (final item in pkgList) {
        final skuid = (item['skuid'] ?? '').toString().trim();
        final qty = int.tryParse(
                item['Quantity']?.toString() ?? item['quantity']?.toString() ?? '1') ??
            1;

        if (skuid.isNotEmpty) {
          await _componentController.skuidanalyze(skuid);
          final tableName = _componentController.ClassName.value;

          if (tableName.isNotEmpty) {
            final currentRes = await _supabase
                .from(tableName)
                .select('stock')
                .eq('skuid', skuid)
                .maybeSingle();

            if (currentRes != null) {
              final currentStock =
                  int.tryParse(currentRes['stock']?.toString() ?? '0') ?? 0;
              final restoredStock = currentStock + qty;

              await _supabase
                  .from(tableName)
                  .update({'stock': restoredStock})
                  .eq('skuid', skuid);
            }
          }
        }
      }

      final now = DateTime.now();
      final returnDateStr = '${now.day}/${now.month}/${now.year}';
      await _supabase.from('Transactions').update({
        'status': 'Returned',
        'returndate': returnDateStr,
      }).eq('transaction_id', txId);

      try {
        final cache = Get.find<CacheController>();
        cache.clearAll();
      } catch (_) {}

      if (mounted) Navigator.pop(context); // dismiss loading

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transaction #$txId marked as Returned & stock updated!'),
            backgroundColor: Colors.green[700],
          ),
        );
        await _loadTransactions();
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to complete return: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Open Apply Fine Dialog
  void _openApplyFineDialog(Map<String, dynamic> tx) {
    final memberId = tx['id']?.toString() ?? '';
    final memberName = tx['name']?.toString() ?? '';
    final phoneNumber = tx['phonenumber']?.toString() ?? '';
    final className = tx['class']?.toString() ?? '';
    final txId = tx['transaction_id']?.toString() ?? '';

    final pkgList = _parsePackage(tx['package']);
    String compSummary = '';
    int totalQty = 0;
    if (pkgList.isNotEmpty) {
      final names = <String>[];
      for (var p in pkgList) {
        final cName = p['compname']?.toString() ?? p['name']?.toString() ?? 'Component';
        final qty = int.tryParse(p['Quantity']?.toString() ?? p['quantity']?.toString() ?? '1') ?? 1;
        totalQty += qty;
        names.add('$cName (Qty: $qty)');
      }
      compSummary = names.join(', ');
    }

    final amountController = TextEditingController(text: '50');
    final reasonController = TextEditingController(text: 'Late Return');
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.gavel_rounded, color: Colors.orange, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Apply Fine',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: const Color(0xff19335A),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xff19335A).withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xff19335A).withValues(alpha: 0.15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$memberName ($memberId)',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: const Color(0xff19335A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Transaction: #$txId',
                          style: GoogleFonts.lato(fontSize: 12, color: Colors.grey[700]),
                        ),
                        if (compSummary.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Items: $compSummary',
                            style: GoogleFonts.lato(fontSize: 12, color: Colors.grey[800]),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Fine Amount (₹)',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: const Color(0xff19335A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      prefixText: '₹ ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [30, 50, 100, 200].map((val) {
                      return ChoiceChip(
                        label: Text('₹$val'),
                        selected: amountController.text == val.toString(),
                        onSelected: (selected) {
                          if (selected) {
                            setDialogState(() {
                              amountController.text = val.toString();
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Reason for Fine',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: const Color(0xff19335A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: reasonController,
                    decoration: InputDecoration(
                      hintText: 'e.g. Late Return, Component Damage',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Notes (Optional)',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: const Color(0xff19335A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Additional context...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.all(10),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text('Cancel', style: GoogleFonts.lato(color: Colors.grey[700])),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff19335A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  final amt = double.tryParse(amountController.text.trim()) ?? 0.0;
                  final reason = reasonController.text.trim();
                  if (amt <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a valid fine amount.')),
                    );
                    return;
                  }

                  final newFine = FineModel(
                    fineId: '',
                    memberId: memberId,
                    memberName: memberName,
                    phoneNumber: phoneNumber,
                    className: className,
                    transactionId: txId,
                    componentName: compSummary.isNotEmpty ? compSummary : null,
                    quantity: totalQty > 0 ? totalQty : 1,
                    amount: amt,
                    reason: reason.isNotEmpty ? reason : 'Fine for Transaction #$txId',
                    notes: notesController.text.trim().isNotEmpty
                        ? notesController.text.trim()
                        : null,
                    status: 'due',
                    issueDate: tx['issuedate']?.toString(),
                    returnDate: tx['returndate']?.toString(),
                  );

                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(dialogCtx);

                  final error = await _fineService.createFine(newFine);
                  if (error == null) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Fine of ₹${amt.toStringAsFixed(0)} created for $memberName!'),
                        backgroundColor: Colors.green[700],
                      ),
                    );
                  } else {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Failed to record fine: $error'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: Text('Apply Fine', style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CAppTheme.isDark(context);
    final secondaryText = CAppTheme.secondaryTextColor(context);
    final accentColor = isDark ? const Color(0xff38BDF8) : const Color(0xff19335A);

    final dueList = _filterTransactions(isDueOnly: true);
    final pastList = _filterTransactions(isDueOnly: false);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xff0F172A) : const Color(0xff19335A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Transactions Management',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bolt_rounded, size: 18),
                  const SizedBox(width: 6),
                  Text('Current Due (${_filterTransactions(isDueOnly: true).length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.history_rounded, size: 18),
                  const SizedBox(width: 6),
                  Text('All Past (${_filterTransactions(isDueOnly: false).length})'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: CAppTheme.bgGradient(context),
        ),
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(14.0),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xff1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xff334155) : Colors.grey[300]!),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  style: GoogleFonts.lato(
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search by Student Name, ID, Class, or Component...',
                    hintStyle: GoogleFonts.lato(
                      fontSize: 13,
                      color: isDark ? const Color(0xff64748B) : Colors.grey[500],
                    ),
                    prefixIcon: Icon(Icons.search, color: accentColor, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, size: 18, color: secondaryText),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),

            // Tab Views
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: accentColor))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildTransactionList(dueList, isDueTab: true),
                        _buildTransactionList(pastList, isDueTab: false),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionList(List<Map<String, dynamic>> list, {required bool isDueTab}) {
    final isDark = CAppTheme.isDark(context);
    final primaryText = CAppTheme.primaryTextColor(context);
    final secondaryText = CAppTheme.secondaryTextColor(context);

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isDueTab ? Icons.check_circle_outline_rounded : Icons.receipt_long_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              isDueTab ? 'No Active / Due Transactions' : 'No Past Transactions Found',
              style: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isDueTab
                  ? 'All borrowed components have been safely returned.'
                  : 'No completed return records match your query.',
              style: GoogleFonts.lato(fontSize: 13, color: secondaryText),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (isDueTab && list.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: isDark ? const Color(0xff0F172A) : Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${list.length} Items Due / Active',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: primaryText,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.settings_outlined, size: 18, color: Colors.grey),
                      tooltip: 'Email SMTP Settings',
                      onPressed: () => EmailReminderService.showEmailConfigDialog(context),
                    ),
                    ElevatedButton.icon(
                      onPressed: _isSendingBulkEmail ? null : () => _sendBulkDueReminders(list),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff19335A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      icon: _isSendingBulkEmail
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded, size: 13),
                      label: Text(
                        _isSendingBulkEmail ? 'Sending...' : 'Email All Due',
                        style: GoogleFonts.montserrat(fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadTransactions,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final tx = list[index];
                return _buildTransactionCard(tx, isDueTab: isDueTab);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> tx, {required bool isDueTab}) {
    final isDark = CAppTheme.isDark(context);
    final primaryText = CAppTheme.primaryTextColor(context);
    final secondaryText = CAppTheme.secondaryTextColor(context);
    final accentColor = isDark ? const Color(0xff38BDF8) : const Color(0xff19335A);

    final txId = tx['transaction_id']?.toString() ?? 'N/A';
    final borrowerName = tx['name']?.toString() ?? 'Unknown Student';
    final memberId = tx['id']?.toString() ?? '';
    final division = tx['class']?.toString() ?? '';
    final phone = tx['phonenumber']?.toString() ?? '';
    final issueDate = tx['issuedate']?.toString() ?? 'N/A';
    final returnDate = tx['returndate']?.toString() ?? 'N/A';
    final status = (tx['status']?.toString() ?? (isDueTab ? 'Issued' : 'Returned')).trim();
    final normalizedStatus = status.toLowerCase();
    final isReturned = !isDueTab ||
      normalizedStatus == 'returned' ||
      normalizedStatus == 'return' ||
      normalizedStatus == 'returned to inventory' ||
      normalizedStatus == 'closed';

    final pkgList = _parsePackage(tx['package']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xff1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDueTab
              ? Colors.orange.withValues(alpha: isDark ? 0.5 : 0.35)
              : Colors.green.withValues(alpha: isDark ? 0.45 : 0.25),
          width: isDueTab ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Borrower Info & Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: accentColor.withValues(alpha: 0.12),
                        child: Text(
                          borrowerName.isNotEmpty ? borrowerName[0].toUpperCase() : 'S',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.bold,
                            color: accentColor,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              borrowerName,
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: primaryText,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'ID: $memberId • Class: $division',
                              style: GoogleFonts.lato(fontSize: 11, color: secondaryText),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isReturned
                        ? Colors.green.withValues(alpha: 0.12)
                        : Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isReturned ? Colors.green : Colors.orange,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    isReturned ? 'RETURNED' : 'DUE / ACTIVE',
                    style: GoogleFonts.lato(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isReturned ? Colors.green[800] : Colors.orange[900],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Metadata: TX ID & Dates
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TX: #$txId',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: primaryText,
                  ),
                ),
                if (phone.isNotEmpty)
                  Text(
                    'Phone: $phone',
                    style: GoogleFonts.lato(fontSize: 12, color: secondaryText),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 12, color: secondaryText),
                    const SizedBox(width: 4),
                    Text(
                      'Issued: $issueDate',
                      style: GoogleFonts.lato(fontSize: 11, color: secondaryText),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.event_repeat_rounded, size: 12, color: secondaryText),
                    const SizedBox(width: 4),
                    Text(
                      isReturned ? 'Returned: $returnDate' : 'Due: $returnDate',
                      style: GoogleFonts.lato(
                        fontSize: 11,
                        fontWeight: isDueTab ? FontWeight.bold : FontWeight.normal,
                        color: isDueTab
                            ? (isDark ? const Color(0xffFDBA74) : Colors.orange[900])
                            : secondaryText,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Package Items List
            if (pkgList.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: pkgList.map((item) {
                  final cName = item['compname']?.toString() ?? item['name']?.toString() ?? 'Component';
                  final qty = item['Quantity']?.toString() ?? item['quantity']?.toString() ?? '1';
                  final sku = item['skuid']?.toString() ?? '';

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: isDark ? 0.14 : 0.05),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: accentColor.withValues(alpha: isDark ? 0.25 : 0.1)),
                    ),
                    child: Text(
                      '$cName × $qty ${sku.isNotEmpty ? "($sku)" : ""}',
                      style: GoogleFonts.lato(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: primaryText,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
            ],

            // Actions Row
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (isDueTab && !isReturned) ...[
                  IconButton(
                    icon: Icon(Icons.mail_outline_rounded, size: 18, color: Colors.orange[800]),
                    tooltip: 'Send Due Reminder Email',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    onPressed: () => _sendSingleDueReminder(tx),
                  ),
                  const SizedBox(width: 4),
                ],

                // Apply Fine Button
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange[900],
                    side: BorderSide(color: Colors.orange.withValues(alpha: 0.6)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                  icon: const Icon(Icons.gavel_rounded, size: 14),
                  label: Text(
                    'Apply Fine',
                    style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                  onPressed: () => _openApplyFineDialog(tx),
                ),
                const SizedBox(width: 8),

                // Mark Return Action (for due items)
                if (isDueTab && !isReturned)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    ),
                    icon: const Icon(Icons.assignment_turned_in_rounded, size: 14),
                    label: Text(
                      'Mark Returned',
                      style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                    onPressed: () => _markAsReturned(tx),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_outline, color: Colors.green, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'Returned',
                          style: GoogleFonts.lato(
                            color: Colors.green[800],
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
