import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory/src/controllers/cache_controller.dart';
import 'package:inventory/src/features/authentication/controllers/componentController.dart';
import 'package:inventory/src/features/main_app/fines/models/fine_model.dart';
import 'package:inventory/src/features/main_app/fines/services/fine_service.dart';
import 'package:inventory/src/utils/theme/theme.dart';

class MemberTransactionsScreen extends StatefulWidget {
  const MemberTransactionsScreen({super.key});

  @override
  State<MemberTransactionsScreen> createState() => _MemberTransactionsScreenState();
}

class _MemberTransactionsScreenState extends State<MemberTransactionsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final FineService _fineService = FineService();
  final ComponentController _componentController = Get.find<ComponentController>();

  final TextEditingController _searchController = TextEditingController();
  final MobileScannerController _scannerController = MobileScannerController();

  bool _isSearching = false;
  bool _isLoadingTransactions = false;
  bool _showNonActiveTransactions = false;

  Map<String, String>? _selectedMember;
  List<Map<String, dynamic>> _activeTransactions = [];
  List<Map<String, dynamic>> _nonActiveTransactions = [];

  @override
  void dispose() {
    _searchController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  // Look up member from Members table by Email, ISA Login ID, or Name
  Future<Map<String, String>?> _lookupMember(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return null;

    try {
      // 1. Try by "Email Id"
      dynamic response = await _supabase
          .from('Members')
          .select()
          .ilike('Email Id', '%$trimmed%')
          .limit(1)
          .maybeSingle();

      // 2. Try by "ISA Login ID"
      response ??= await _supabase
          .from('Members')
          .select()
          .ilike('ISA Login ID', '%$trimmed%')
          .limit(1)
          .maybeSingle();

      // 3. Try by "Name"
      response ??= await _supabase
          .from('Members')
          .select()
          .ilike('Name', '%$trimmed%')
          .limit(1)
          .maybeSingle();

      if (response != null) {
        return {
          'member_id': response['ISA Login ID']?.toString() ?? '',
          'name': response['Name']?.toString() ?? '',
          'email': response['Email Id']?.toString() ?? '',
          'phone': response['Phone Number']?.toString() ?? '',
          'class': response['Division']?.toString() ?? '',
        };
      }
    } catch (_) {}

    // Fallback: Fetch all members and match in memory
    try {
      final allMembers = await _supabase.from('Members').select();
      final lowerQuery = trimmed.toLowerCase();
      for (var m in allMembers as List<dynamic>) {
        final email = (m['Email Id'] ?? '').toString().toLowerCase();
        final id = (m['ISA Login ID'] ?? '').toString().toLowerCase();
        final name = (m['Name'] ?? '').toString().toLowerCase();

        if (email.contains(lowerQuery) ||
            id.contains(lowerQuery) ||
            name.contains(lowerQuery)) {
          return {
            'member_id': m['ISA Login ID']?.toString() ?? '',
            'name': m['Name']?.toString() ?? '',
            'email': m['Email Id']?.toString() ?? '',
            'phone': m['Phone Number']?.toString() ?? '',
            'class': m['Division']?.toString() ?? '',
          };
        }
      }
    } catch (_) {}

    return null;
  }

  // Handle Search Submission (via textfield)
  Future<void> _handleSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isSearching = true;
    });

    final member = await _lookupMember(query);

    if (mounted) {
      setState(() {
        _isSearching = false;
        _selectedMember = member;
      });

      if (member != null) {
        await _fetchMemberTransactions(member);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No member found for "$query".'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    }
  }

  // Open QR Scanner Dialog
  Future<void> _startQRScan() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera permission is required to scan member QR.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.qr_code_scanner_rounded, color: Color(0xff19335A)),
            const SizedBox(width: 8),
            Text(
              'Scan Member QR',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: const Color(0xff19335A),
              ),
            ),
          ],
        ),
        content: SizedBox(
          height: 280,
          width: 280,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: MobileScanner(
              controller: _scannerController,
              onDetect: (capture) async {
                final barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  final rawValue = barcode.rawValue;
                  if (rawValue != null && rawValue.isNotEmpty) {
                    _scannerController.stop();
                    Navigator.of(dialogCtx).pop();

                    String lookupQuery = rawValue.trim();
                    try {
                      final Map<String, dynamic> parsed = jsonDecode(rawValue);
                      lookupQuery = (parsed['member_id'] ??
                              parsed['email'] ??
                              parsed['id'] ??
                              rawValue)
                          .toString();
                    } catch (_) {}

                    _searchController.text = lookupQuery;
                    await _handleSearch();
                    break;
                  }
                }
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _scannerController.stop();
              Navigator.of(dialogCtx).pop();
            },
            child: Text('Cancel', style: GoogleFonts.lato(color: Colors.grey[700])),
          ),
        ],
      ),
    );
  }

  // Fetch all transactions for member, separated into active and non-active (latest first)
  Future<void> _fetchMemberTransactions(Map<String, String> member) async {
    setState(() {
      _isLoadingTransactions = true;
      _activeTransactions = [];
      _nonActiveTransactions = [];
      _showNonActiveTransactions = false;
    });

    final memberId = member['member_id'] ?? '';
    final memberName = member['name'] ?? '';

    try {
      // 1. Fetch by member ID ('id' column in Transactions table)
      dynamic response = await _supabase
          .from('Transactions')
          .select()
          .eq('id', memberId);

      List<dynamic> list = response as List<dynamic>;

      // 2. If empty, try matching by name
      if (list.isEmpty && memberName.isNotEmpty) {
        response = await _supabase
            .from('Transactions')
            .select()
            .ilike('name', '%$memberName%');
        list = response;
      }

      final mapped = list.map((item) => Map<String, dynamic>.from(item)).toList();

      // Sort with latest at top (using created_at or issuedate)
      mapped.sort((a, b) {
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

      // Split into active and non-active
      final active = <Map<String, dynamic>>[];
      final nonActive = <Map<String, dynamic>>[];

      for (final tx in mapped) {
        final status = (tx['status']?.toString() ?? 'Issued').trim().toLowerCase();
        if (status == 'returned') {
          nonActive.add(tx);
        } else {
          active.add(tx);
        }
      }

      if (mounted) {
        setState(() {
          _activeTransactions = active;
          _nonActiveTransactions = nonActive;
          _isLoadingTransactions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingTransactions = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load transactions: $e')),
        );
      }
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

  // Restore inventory stock and mark transaction as Returned
  Future<void> _markTransactionAsReturned(Map<String, dynamic> tx) async {
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

    // Show loading progress
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 1. Parse package components
      var packageRaw = tx['package'];
      List<dynamic> pkgList = [];
      if (packageRaw is String) {
        packageRaw = jsonDecode(packageRaw);
      }
      if (packageRaw is List) {
        pkgList = packageRaw;
      }

      // 2. Restore stock for each component in its respective category table in parallel
      await Future.wait(pkgList.map((item) async {
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
      }));

      // 3. Update Transaction status to 'Returned'
      final now = DateTime.now();
      final returnDateStr = '${now.day}/${now.month}/${now.year}';
      await _supabase.from('Transactions').update({
        'status': 'Returned',
        'returndate': returnDateStr,
      }).eq('transaction_id', txId);

      // 4. Invalidate Cache Controller caches
      try {
        final cache = Get.find<CacheController>();
        cache.clearAll();
      } catch (_) {}

      // Dismiss loading dialog
      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transaction #$txId marked as Returned & stock updated!'),
            backgroundColor: Colors.green[700],
          ),
        );

        // Refresh transaction list
        if (_selectedMember != null) {
          await _fetchMemberTransactions(_selectedMember!);
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Dismiss loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to complete return: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Open Apply Fine Dialog for this transaction
  void _openApplyFineDialog(Map<String, dynamic> tx) {
    final member = _selectedMember;
    final memberId = member?['member_id'] ?? tx['id']?.toString() ?? '';
    final memberName = member?['name'] ?? tx['name']?.toString() ?? '';
    final memberEmail = member?['email'] ?? '';
    final phoneNumber = member?['phone'] ?? tx['phonenumber']?.toString() ?? '';
    final className = member?['class'] ?? tx['class']?.toString() ?? '';
    final txId = tx['transaction_id']?.toString() ?? '';

    // Summarize components
    var packageRaw = tx['package'];
    List<dynamic> pkgList = [];
    if (packageRaw is String) {
      try {
        pkgList = jsonDecode(packageRaw);
      } catch (_) {}
    } else if (packageRaw is List) {
      pkgList = packageRaw;
    }

    String compSummary = '';
    int totalQty = 0;
    if (pkgList.isNotEmpty) {
      final names = <String>[];
      for (var p in pkgList) {
        final cName =
            p['compname']?.toString() ?? p['name']?.toString() ?? 'Component';
        final qty = int.tryParse(
                p['Quantity']?.toString() ?? p['quantity']?.toString() ?? '1') ??
            1;
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
                  'Apply Fine to Member',
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
                      border: Border.all(
                        color: const Color(0xff19335A).withValues(alpha: 0.15),
                      ),
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
                  // Quick Amount Chips
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
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: [
                      'Late Return',
                      'Damaged Component',
                      'Missing Item',
                    ].map((r) {
                      return ActionChip(
                        label: Text(r, style: const TextStyle(fontSize: 11)),
                        onPressed: () {
                          setDialogState(() {
                            reasonController.text = r;
                          });
                        },
                      );
                    }).toList(),
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
                    memberEmail: memberEmail,
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
    final accentColor = isDark ? const Color(0xff38BDF8) : const Color(0xff19335A);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Member Transactions & Returns',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: isDark ? const Color(0xff0F172A) : const Color(0xff19335A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
            tooltip: 'Scan Member QR',
            onPressed: _startQRScan,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: CAppTheme.bgGradient(context),
        ),
        child: Column(
          children: [
            // Search & Scan Bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
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
                        onSubmitted: (_) => _handleSearch(),
                        style: GoogleFonts.lato(
                          fontSize: 13,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter Email, ISA Login ID, or Name...',
                          hintStyle: GoogleFonts.lato(
                            fontSize: 13,
                            color: isDark ? const Color(0xff64748B) : Colors.grey[500],
                          ),
                          prefixIcon: Icon(Icons.search, color: accentColor, size: 20),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _selectedMember = null;
                                      _activeTransactions = [];
                                      _nonActiveTransactions = [];
                                      _showNonActiveTransactions = false;
                                    });
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Search Submit Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onPressed: _isSearching ? null : _handleSearch,
                    child: _isSearching
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text('Find', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  // QR Scanner Button
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: accentColor.withValues(alpha: isDark ? 0.2 : 0.1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.all(12),
                    ),
                    icon: Icon(Icons.qr_code_scanner_rounded, color: accentColor),
                    tooltip: 'Scan Member QR',
                    onPressed: _startQRScan,
                  ),
                ],
              ),
            ),

            // Member Details Card (if selected)
            if (_selectedMember != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xff19335A),
                        Color(0xff2A4E80),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xff19335A).withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        child: Text(
                          (_selectedMember!['name']?.isNotEmpty ?? false)
                              ? _selectedMember!['name']![0].toUpperCase()
                              : 'M',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedMember!['name'] ?? 'Member',
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'ID: ${_selectedMember!['member_id']} • Class: ${_selectedMember!['class'] ?? 'N/A'}',
                              style: GoogleFonts.lato(fontSize: 12, color: Colors.white70),
                            ),
                            if (_selectedMember!['email']?.isNotEmpty ?? false)
                              Text(
                                _selectedMember!['email']!,
                                style: GoogleFonts.lato(fontSize: 11, color: Colors.white60),
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                        tooltip: 'Refresh Transactions',
                        onPressed: () => _fetchMemberTransactions(_selectedMember!),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 10),

            // Transactions Content Area
            Expanded(
              child: _buildTransactionsContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsContent() {
    final isDark = CAppTheme.isDark(context);
    final primaryText = CAppTheme.primaryTextColor(context);
    final secondaryText = CAppTheme.secondaryTextColor(context);
    if (_selectedMember == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_search_rounded,
              size: 72,
              color: secondaryText,
            ),
            const SizedBox(height: 14),
            Text(
              'Scan Member QR or Enter Email / ID',
              style: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Active transactions will be displayed first with instant return & fine options.',
              style: GoogleFonts.lato(fontSize: 13, color: secondaryText),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_isLoadingTransactions) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_activeTransactions.isEmpty && _nonActiveTransactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 14),
            Text(
              'No Transactions Found',
              style: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'This member currently has no active or past transaction records.',
              style: GoogleFonts.lato(fontSize: 13, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchMemberTransactions(_selectedMember!),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Section Header: Active Transactions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.bolt_rounded, color: Colors.orange, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    'Active / Issued Transactions',
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: primaryText,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _activeTransactions.isNotEmpty
                      ? Colors.orange.withValues(alpha: isDark ? 0.22 : 0.15)
                      : (isDark ? const Color(0xff334155) : Colors.grey[200]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_activeTransactions.length}',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _activeTransactions.isNotEmpty
                        ? (isDark ? const Color(0xffFDBA74) : Colors.orange[900])
                        : (isDark ? const Color(0xffCBD5E1) : Colors.grey[700]),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (_activeTransactions.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No active issued items. All past packages have been returned!',
                      style: GoogleFonts.lato(
                        fontSize: 13,
                        color: Colors.green[900],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            ..._activeTransactions.map((tx) => _buildTransactionCard(tx, isActive: true)),

          const SizedBox(height: 16),

          // Non-Active / Returned Section Load Button or List
          if (_nonActiveTransactions.isNotEmpty) ...[
            Center(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _showNonActiveTransactions
                      ? Colors.grey[300]
                      : const Color(0xff19335A).withValues(alpha: 0.08),
                  foregroundColor: const Color(0xff19335A),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: const Color(0xff19335A).withValues(alpha: 0.2),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                icon: Icon(
                  _showNonActiveTransactions
                      ? Icons.expand_less_rounded
                      : Icons.history_rounded,
                  size: 18,
                ),
                label: Text(
                  _showNonActiveTransactions
                      ? 'Hide Past Returned Transactions'
                      : 'Load Past / Returned Transactions (${_nonActiveTransactions.length})',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                onPressed: () {
                  setState(() {
                    _showNonActiveTransactions = !_showNonActiveTransactions;
                  });
                },
              ),
            ),
            const SizedBox(height: 10),

            if (_showNonActiveTransactions) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  children: [
                    const Icon(Icons.history_toggle_off_rounded, color: Colors.grey, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'Returned Transactions History',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              ..._nonActiveTransactions.map((tx) => _buildTransactionCard(tx, isActive: false)),
            ],
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> tx, {required bool isActive}) {
    final isDark = CAppTheme.isDark(context);
    final primaryText = CAppTheme.primaryTextColor(context);
    final secondaryText = CAppTheme.secondaryTextColor(context);
    final accentColor = isDark ? const Color(0xff38BDF8) : const Color(0xff19335A);

    final txId = tx['transaction_id']?.toString() ?? 'N/A';
    final status = (tx['status']?.toString() ?? (isActive ? 'Issued' : 'Returned')).trim();
    final isReturned = !isActive || status.toLowerCase() == 'returned';
    final issueDate = tx['issuedate']?.toString() ?? 'N/A';
    final returnDate = tx['returndate']?.toString() ?? 'N/A';

    // Parse package items
    var packageRaw = tx['package'];
    List<dynamic> pkgList = [];
    if (packageRaw is String) {
      try {
        pkgList = jsonDecode(packageRaw);
      } catch (_) {}
    } else if (packageRaw is List) {
      pkgList = packageRaw;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xff1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive
              ? Colors.orange.withValues(alpha: isDark ? 0.5 : 0.35)
              : Colors.green.withValues(alpha: isDark ? 0.5 : 0.3),
          width: isActive ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
            // Transaction Header: ID & Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.receipt_rounded,
                      size: 18,
                      color: Color(0xff19335A),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'TX: #$txId',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: primaryText,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isReturned
                        ? Colors.green.withValues(alpha: 0.12)
                        : Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isReturned ? Colors.green : Colors.orange,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    isReturned ? 'RETURNED' : 'ACTIVE / ISSUED',
                    style: GoogleFonts.lato(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isReturned ? Colors.green[800] : Colors.orange[900],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Dates Row
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 14, color: secondaryText),
                const SizedBox(width: 4),
                Text(
                  'Issued: $issueDate',
                      style: GoogleFonts.lato(fontSize: 12, color: secondaryText),
                ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.event_repeat_rounded, size: 14, color: secondaryText),
                const SizedBox(width: 4),
                Text(
                  isReturned ? 'Returned: $returnDate' : 'Due: $returnDate',
                      style: GoogleFonts.lato(fontSize: 12, color: secondaryText),
                ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Package Items List
            Text(
              'Package Components:',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: accentColor,
              ),
            ),
            const SizedBox(height: 6),

            if (pkgList.isEmpty)
              Text(
                'No components listed',
                style: GoogleFonts.lato(fontSize: 12, color: Colors.grey[500]),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: pkgList.map((item) {
                  final cName = item['compname']?.toString() ??
                      item['name']?.toString() ??
                      'Component';
                  final qty = item['Quantity']?.toString() ??
                      item['quantity']?.toString() ??
                      '1';
                  final sku = item['skuid']?.toString() ?? '';

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xff19335A).withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xff19335A).withValues(alpha: 0.12),
                      ),
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

            const SizedBox(height: 12),

            // Action Buttons Row
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                // Apply Fine Button
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange[900],
                    side: BorderSide(color: Colors.orange.withValues(alpha: 0.6)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  icon: const Icon(Icons.gavel_rounded, size: 16),
                  label: Text(
                    'Apply Fine',
                    style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  onPressed: () => _openApplyFineDialog(tx),
                ),
                const SizedBox(width: 8),

                // Mark as Returned Button (Only for active)
                if (isActive && !isReturned)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    icon: const Icon(Icons.assignment_turned_in_rounded, size: 16),
                    label: Text(
                      'Mark Returned',
                      style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    onPressed: () => _markTransactionAsReturned(tx),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_outline, color: Colors.green, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Returned',
                          style: GoogleFonts.lato(
                            color: Colors.green[800],
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
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
