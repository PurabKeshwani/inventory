import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:inventory/src/features/authentication/controllers/emailcontroller.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'models/fine_model.dart';
import 'services/fine_service.dart';
import 'fine_receipt_dialog.dart';
import 'package:inventory/src/utils/theme/theme.dart';

class FinesScreen extends StatefulWidget {
  const FinesScreen({super.key});

  @override
  State<FinesScreen> createState() => _FinesScreenState();
}

class _FinesScreenState extends State<FinesScreen> {
  final FineService _fineService = FineService();
  final Emailcontroller _emailController = Get.find<Emailcontroller>();

  List<FineModel> _allFines = [];
  List<FineModel> _filteredFines = [];
  bool _isLoading = true;
  String _selectedFilter = 'all'; // 'all', 'due', 'paid'
  bool _isTableView = false; // Card view is default for mobile responsiveness
  final TextEditingController _searchController = TextEditingController();
  final MobileScannerController _scannerController = MobileScannerController();
  String? _scannedMemberId;
  String? _scannedMemberName;

  @override
  void initState() {
    super.initState();
    _loadFines();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _scanMemberQR() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Scan Member QR',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        content: SizedBox(
          height: 300,
          width: 300,
          child: MobileScanner(
            controller: _scannerController,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  try {
                    Map<String, dynamic> scannedData =
                        jsonDecode(barcode.rawValue!);
                    final memberId = scannedData['member_id'] ?? '';
                    final memberName = scannedData['name'] ?? '';
                    _scannerController.stop();
                    Navigator.of(context).pop();
                    setState(() {
                      _scannedMemberId = memberId;
                      _scannedMemberName = memberName.toString().isNotEmpty
                          ? memberName.toString()
                          : null;
                      _searchController.clear();
                      _applyFilters();
                    });
                  } catch (e) {
                    _scannerController.stop();
                    Navigator.of(context).pop();
                    setState(() {
                      _scannedMemberId = barcode.rawValue;
                      _scannedMemberName = null;
                      _searchController.clear();
                      _applyFilters();
                    });
                  }
                }
              }
            },
          ),
        ),
      ),
    );
  }

  void _clearScannedMember() {
    setState(() {
      _scannedMemberId = null;
      _scannedMemberName = null;
      _applyFilters();
    });
  }

  Future<void> _loadFines({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final fines = await _fineService.getAllFines(forceRefresh: forceRefresh);
      if (mounted) {
        setState(() {
          _allFines = fines;
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load fines: $e')),
        );
      }
    }
  }

  void _applyFilters() {
    String query = _searchController.text.trim().toLowerCase();

    setState(() {
      _filteredFines = _allFines.where((fine) {
        // Scanned member filter
        if (_scannedMemberId != null && _scannedMemberId!.isNotEmpty) {
          if (fine.memberId.toLowerCase() != _scannedMemberId!.toLowerCase()) {
            return false;
          }
        }

        // Status filter: default is 'due'
        if (_selectedFilter == 'due' && !fine.isDue) return false;
        if (_selectedFilter == 'paid' && !fine.isPaid) return false;

        // Search filter
        if (query.isNotEmpty) {
          final memberId = fine.memberId.toLowerCase();
          final memberName = (fine.memberName ?? '').toLowerCase();
          final memberEmail = (fine.memberEmail ?? '').toLowerCase();
          final phone = (fine.phoneNumber ?? '').toLowerCase();
          final component = (fine.componentName ?? '').toLowerCase();
          final className = (fine.className ?? '').toLowerCase();
          final reason = fine.reason.toLowerCase();
          final txId = (fine.transactionId ?? '').toLowerCase();

          return memberId.contains(query) ||
              memberName.contains(query) ||
              memberEmail.contains(query) ||
              phone.contains(query) ||
              component.contains(query) ||
              className.contains(query) ||
              reason.contains(query) ||
              txId.contains(query);
        }

        return true;
      }).toList();
    });
  }

  double get _totalDueAmount =>
      _allFines.where((f) => f.isDue).fold(0.0, (sum, f) => sum + f.amount);

  double get _totalPaidAmount =>
      _allFines.where((f) => f.isPaid).fold(0.0, (sum, f) => sum + f.amount);

  int get _dueCount => _allFines.where((f) => f.isDue).length;
  int get _paidCount => _allFines.where((f) => f.isPaid).length;

  Future<void> _toggleFineStatus(FineModel fine) async {
    final willMarkPaid = fine.isDue;
    final councilName = _emailController.Namefrommail.value.isNotEmpty
        ? _emailController.Namefrommail.value
        : 'Council Member';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          willMarkPaid ? 'Mark Fine as Paid?' : 'Mark Fine as Due?',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
        ),
        content: Text(
          willMarkPaid
              ? 'Confirm ₹${fine.amount.toStringAsFixed(0)} payment for ${fine.memberName ?? fine.memberId}?\nCollected by: $councilName'
              : 'Revert fine of ₹${fine.amount.toStringAsFixed(0)} back to DUE / PENDING status?',
          style: GoogleFonts.lato(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  willMarkPaid ? Colors.green[700] : const Color(0xff19335A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(willMarkPaid ? 'Mark as Paid' : 'Set to Due'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      bool success = false;
      if (willMarkPaid) {
        success = await _fineService.markFineAsPaid(
          fineId: fine.fineId,
          paidBy: councilName,
        );
      } else {
        success = await _fineService.markFineAsDue(fineId: fine.fineId);
      }

      if (success) {
        final updatedFine = fine.copyWith(
          status: willMarkPaid ? 'paid' : 'due',
          paidBy: willMarkPaid ? councilName : null,
          paidAt: willMarkPaid ? DateTime.now().toIso8601String() : null,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(willMarkPaid
                  ? 'Fine marked as Paid!'
                  : 'Fine set to Due (Default)!'),
              backgroundColor: willMarkPaid ? Colors.green : Colors.orange[800],
              action: willMarkPaid
                  ? SnackBarAction(
                      label: 'VIEW RECEIPT',
                      textColor: Colors.white,
                      onPressed: () => FineReceiptDialog.show(context, updatedFine),
                    )
                  : null,
            ),
          );

          if (willMarkPaid) {
            _showReceiptPromptDialog(updatedFine);
          }
        }
        _loadFines();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update fine status.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showReceiptPromptDialog(FineModel fine) async {
    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 26),
            const SizedBox(width: 8),
            Text(
              'Payment Received!',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment of ₹${fine.amount.toStringAsFixed(0)} recorded for ${fine.memberName ?? fine.memberId}.',
              style: GoogleFonts.lato(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Text(
              'Would you like to generate and print the payment receipt now?',
              style: GoogleFonts.lato(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xff19335A),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Later', style: GoogleFonts.lato(color: Colors.grey[700])),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff19335A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.receipt_long_rounded, size: 18),
            label: Text(
              'Generate Receipt',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
            ),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (shouldOpen == true && mounted) {
      FineReceiptDialog.show(context, fine);
    }
  }

  Future<void> _confirmDeleteFine(FineModel fine) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 24),
            const SizedBox(width: 8),
            Text(
              'Delete Fine Record',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: const Color(0xff19335A),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete this fine record of ₹${fine.amount.toStringAsFixed(0)} for ${fine.memberName ?? fine.memberId}?\n\nThis action cannot be undone.',
          style: GoogleFonts.lato(fontSize: 14, color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.lato(color: Colors.grey[700])),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _fineService.deleteFine(fine.fineId);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Fine record deleted successfully.'),
              backgroundColor: Color(0xff19335A),
            ),
          );
          _loadFines();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete fine record.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showAddFineDialog() {
    final emailInputController = TextEditingController();
    final memberIdController = TextEditingController();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final classController = TextEditingController();
    final componentController = TextEditingController();
    final qtyController = TextEditingController(text: '1');
    final amountController = TextEditingController();
    final reasonController = TextEditingController();
    final notesController = TextEditingController();
    String selectedStatus = 'due'; // Default is Due
    bool isLookingUp = false;
    String? lookupSuccessMessage;
    String? lookupErrorMessage;
    bool isSearchingComponent = false;
    List<Map<String, dynamic>> liveComponentResults = [];
    String? selectedComponentLabel;
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => StatefulBuilder(
        builder: (modalContext, setModalState) {
          Future<void> performLookup(String query) async {
            if (query.trim().isEmpty) return;
            setModalState(() {
              isLookingUp = true;
              lookupSuccessMessage = null;
              lookupErrorMessage = null;
            });

            final memberInfo =
                await _fineService.getMemberByEmailOrId(query.trim());

            setModalState(() {
              isLookingUp = false;
              if (memberInfo != null) {
                memberIdController.text = memberInfo['member_id'] ?? '';
                nameController.text = memberInfo['name'] ?? '';
                classController.text = memberInfo['class'] ?? '';
                phoneController.text = memberInfo['phone'] ?? '';
                lookupSuccessMessage =
                    'Verified: ${memberInfo['name']} (ID: ${memberInfo['member_id']}, Class: ${memberInfo['class']})';
                lookupErrorMessage = null;
              } else {
                lookupSuccessMessage = null;
                lookupErrorMessage =
                    'No member found for "$query". You can fill the fields manually.';
              }
            });
          }

          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              top: 20,
              left: 20,
              right: 20,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Record / Assess Fine',
                          style: GoogleFonts.montserrat(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xff19335A),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 10),

                    // Member Email Input + Lookup Button
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: emailInputController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'Member Email / ISA Login ID *',
                              hintText: 'e.g. 2024.tanvi.jagade@ves.ac.in',
                              prefixIcon: const Icon(Icons.email_outlined),
                              border: const OutlineInputBorder(),
                              suffixIcon: isLookingUp
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      ),
                                    )
                                  : IconButton(
                                      icon: const Icon(Icons.search,
                                          color: Color(0xff19335A)),
                                      tooltip: 'Fetch Member details',
                                      onPressed: () => performLookup(
                                          emailInputController.text),
                                    ),
                            ),
                            onFieldSubmitted: (val) => performLookup(val),
                            validator: (val) =>
                                val == null || val.trim().isEmpty
                                    ? 'Email or Member ID is required'
                                    : null,
                          ),
                        ),
                      ],
                    ),

                    if (lookupSuccessMessage != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green[300]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle,
                                size: 16, color: Colors.green[800]),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                lookupSuccessMessage!,
                                style: GoogleFonts.lato(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[800],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (lookupErrorMessage != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange[300]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                size: 16, color: Colors.orange[800]),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                lookupErrorMessage!,
                                style: GoogleFonts.lato(
                                  fontSize: 12,
                                  color: Colors.orange[900],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),

                    // Resolved Member ID & Name
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: memberIdController,
                            decoration: const InputDecoration(
                              labelText: 'Member ID (ISA Login ID) *',
                              hintText: 'e.g. 2024.tanvi.jagade',
                              prefixIcon: Icon(Icons.badge_outlined),
                              border: OutlineInputBorder(),
                            ),
                            validator: (val) =>
                                val == null || val.trim().isEmpty
                                    ? 'Required'
                                    : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: nameController,
                            decoration: const InputDecoration(
                              labelText: 'Member Name',
                              hintText: 'e.g. Tanvi Jagade',
                              prefixIcon: Icon(Icons.person_outline),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Class & Phone Number
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: classController,
                            decoration: const InputDecoration(
                              labelText: 'Class / Division',
                              hintText: 'e.g. D12A',
                              prefixIcon: Icon(Icons.school_outlined),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Mobile Number',
                              hintText: 'e.g. 9876543210',
                              prefixIcon: Icon(Icons.phone_outlined),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Component Name (Live DB Query) & Qty
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: componentController,
                            decoration: InputDecoration(
                              labelText: 'Component (Item Name) *',
                              hintText: 'Type to query DB live (e.g. Arduino, OLED...)',
                              prefixIcon: const Icon(Icons.memory_rounded),
                              border: const OutlineInputBorder(),
                              suffixIcon: isSearchingComponent
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      ),
                                    )
                                  : (componentController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear, size: 18),
                                          onPressed: () {
                                            setModalState(() {
                                              componentController.clear();
                                              liveComponentResults = [];
                                              selectedComponentLabel = null;
                                            });
                                          },
                                        )
                                      : null),
                            ),
                            onChanged: (val) async {
                              final query = val.trim();
                              if (query.isEmpty) {
                                setModalState(() {
                                  liveComponentResults = [];
                                  isSearchingComponent = false;
                                });
                                return;
                              }

                              setModalState(() {
                                isSearchingComponent = true;
                              });

                              final results =
                                  await _fineService.searchLiveComponents(query);

                              setModalState(() {
                                isSearchingComponent = false;
                                liveComponentResults = results;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            controller: qtyController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Qty',
                              hintText: '1',
                              prefixIcon: Icon(Icons.numbers_outlined),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Live DB Query Results Container
                    if (isSearchingComponent) ...[
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          children: [
                            const SizedBox(
                              height: 12,
                              width: 12,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Querying inventory database across 7 categories...',
                              style: GoogleFonts.lato(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (liveComponentResults.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 220),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xff19335A).withValues(alpha: 0.2),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: ListView.separated(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: liveComponentResults.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (ctx, index) {
                              final item = liveComponentResults[index];
                              final name = item['name'] ?? '';
                              final skuid = item['skuid'] ?? '';
                              final cat = item['category'] ?? '';
                              final stock = item['stock'] ?? 0;
                              final boxno = item['boxno'] ?? '';
                              final isAvailable = stock > 0;

                              return InkWell(
                                onTap: () {
                                  setModalState(() {
                                    final exactName = item['name']?.toString() ?? '';
                                    final skuidStr = item['skuid']?.toString() ?? '';
                                    final boxStr = item['boxno']?.toString() ?? '';
                                    componentController.text = exactName;
                                    selectedComponentLabel = skuidStr.isNotEmpty
                                        ? '$exactName (SKU: $skuidStr${boxStr.isNotEmpty ? ', Box: $boxStr' : ''}, Stock: $stock)'
                                        : exactName;
                                    liveComponentResults = [];
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: const Color(0xff19335A)
                                            .withValues(alpha: 0.08),
                                        child: const Icon(
                                          Icons.memory_rounded,
                                          size: 16,
                                          color: Color(0xff19335A),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: GoogleFonts.montserrat(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: const Color(0xff19335A),
                                              ),
                                            ),
                                            Wrap(
                                              spacing: 6,
                                              crossAxisAlignment:
                                                  WrapCrossAlignment.center,
                                              children: [
                                                if (skuid.isNotEmpty)
                                                  Text(
                                                    skuid,
                                                    style: GoogleFonts.sourceCodePro(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.black87,
                                                    ),
                                                  ),
                                                if (cat.isNotEmpty)
                                                  Text(
                                                    '• $cat',
                                                    style: GoogleFonts.lato(
                                                      fontSize: 11,
                                                      color: Colors.grey[700],
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isAvailable
                                                  ? Colors.green[50]
                                                  : Colors.red[50],
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: isAvailable
                                                    ? Colors.green[300]!
                                                    : Colors.red[300]!,
                                              ),
                                            ),
                                            child: Text(
                                              isAvailable
                                                  ? 'Stock: $stock'
                                                  : 'Out of stock',
                                              style: GoogleFonts.lato(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: isAvailable
                                                    ? Colors.green[800]
                                                    : Colors.red[800],
                                              ),
                                            ),
                                          ),
                                          if (boxno.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 2),
                                              child: Text(
                                                'Box: $boxno',
                                                style: GoogleFonts.lato(
                                                  fontSize: 10,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],

                    if (selectedComponentLabel != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xff19335A).withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xff19335A).withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                size: 16, color: Color(0xff19335A)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Selected from DB: $selectedComponentLabel',
                                style: GoogleFonts.lato(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xff19335A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),

                    // Fine Amount & Status (Default: Due)
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: amountController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Fine Amount (₹) *',
                              hintText: 'e.g. 50',
                              prefixIcon: Icon(Icons.currency_rupee),
                              border: OutlineInputBorder(),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Required';
                              }
                              if (double.tryParse(val) == null) {
                                return 'Enter valid number';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedStatus,
                            decoration: const InputDecoration(
                              labelText: 'Status',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.flag_outlined),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'due',
                                child: Text('Due (Default)'),
                              ),
                              DropdownMenuItem(
                                value: 'paid',
                                child: Text('Paid'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setModalState(() {
                                  selectedStatus = val;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Reason & Notes
                    TextFormField(
                      controller: reasonController,
                      decoration: const InputDecoration(
                        labelText: 'Reason *',
                        hintText:
                            'e.g. Late Return, Damaged Cable, Missing item',
                        prefixIcon: Icon(Icons.warning_amber_rounded),
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) =>
                          val == null || val.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: notesController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Additional Notes',
                        hintText: 'Circumstances or details',
                        prefixIcon: Icon(Icons.notes),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff19335A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          if (formKey.currentState!.validate()) {
                            final councilName =
                                _emailController.Namefrommail.value.isNotEmpty
                                    ? _emailController.Namefrommail.value
                                    : 'Council Member';

                            String finalMemberId =
                                memberIdController.text.trim();
                            final enteredEmail =
                                emailInputController.text.trim();

                            // Ensure memberId is resolved if only email was entered
                            if (finalMemberId.isEmpty ||
                                finalMemberId.contains('@')) {
                              final memberInfo = await _fineService
                                  .getMemberByEmailOrId(enteredEmail);
                              if (memberInfo != null &&
                                  memberInfo['member_id']!.isNotEmpty) {
                                finalMemberId = memberInfo['member_id']!;
                              } else {
                                finalMemberId = enteredEmail;
                              }
                            }

                              final now = DateTime.now();
                              final formattedSystemDate =
                                  '${now.day}/${now.month}/${now.year}';

                              final newFine = FineModel(
                                fineId: '',
                                memberId: finalMemberId,
                                memberEmail: enteredEmail.contains('@')
                                    ? enteredEmail
                                    : null,
                                memberName: nameController.text.trim().isEmpty
                                    ? null
                                    : nameController.text.trim(),
                                phoneNumber: phoneController.text.trim().isEmpty
                                    ? null
                                    : phoneController.text.trim(),
                                className: classController.text.trim().isEmpty
                                    ? null
                                    : classController.text.trim(),
                                componentName:
                                    componentController.text.trim().isEmpty
                                        ? null
                                        : componentController.text.trim(),
                                quantity:
                                    int.tryParse(qtyController.text.trim()) ?? 1,
                                reason: reasonController.text.trim(),
                                amount:
                                    double.parse(amountController.text.trim()),
                                status: selectedStatus,
                                createdBy: councilName,
                                createdAt: DateTime.now().toIso8601String(),
                                issueDate: formattedSystemDate,
                                returnDate: formattedSystemDate,
                                paidBy:
                                    selectedStatus == 'paid' ? councilName : null,
                                paidAt: selectedStatus == 'paid'
                                    ? DateTime.now().toIso8601String()
                                    : null,
                                notes: notesController.text.trim().isEmpty
                                    ? null
                                    : notesController.text.trim(),
                              );

                            final currentMessenger = ScaffoldMessenger.of(context);
                            Navigator.of(modalContext).pop();

                            final errorMsg =
                                await _fineService.createFine(newFine);
                            if (errorMsg == null) {
                              currentMessenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Fine recorded successfully!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              _loadFines();
                            } else {
                              currentMessenger.showSnackBar(
                                SnackBar(
                                  content: Text('Failed to record fine: $errorMsg'),
                                  backgroundColor: Colors.red,
                                  duration: const Duration(seconds: 5),
                                ),
                              );
                            }
                          }
                        },
                        child: Text(
                          'Save Fine Record',
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showFineDetails(FineModel fine) {
    final isDark = CAppTheme.isDark(context);
    final primaryText = CAppTheme.primaryTextColor(context);
    final secondaryText = CAppTheme.secondaryTextColor(context);
    final accentColor = isDark ? const Color(0xff38BDF8) : const Color(0xff19335A);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xff0F172A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: isDark ? const Color(0xff334155) : Colors.transparent,
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xff334155) : Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Fine Details',
                    style: GoogleFonts.montserrat(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: primaryText,
                    ),
                  ),
                  _buildStatusBadge(fine.status),
                ],
              ),
              const SizedBox(height: 14),

              // Hero Amount Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: fine.isDue
                      ? (isDark ? Colors.red.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.08))
                      : (isDark ? Colors.green.withValues(alpha: 0.15) : Colors.green.withValues(alpha: 0.08)),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: fine.isDue
                        ? (isDark ? Colors.red.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.3))
                        : (isDark ? Colors.green.withValues(alpha: 0.3) : Colors.green.withValues(alpha: 0.3)),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fine Amount',
                          style: GoogleFonts.lato(
                            fontSize: 12,
                            color: secondaryText,
                          ),
                        ),
                        Text(
                          '₹${fine.amount.toStringAsFixed(0)}',
                          style: GoogleFonts.montserrat(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: fine.isDue
                                ? (isDark ? const Color(0xffF87171) : Colors.red[800])
                                : (isDark ? const Color(0xff4ADE80) : Colors.green[800]),
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      fine.isDue
                          ? Icons.pending_actions_rounded
                          : Icons.check_circle_outline_rounded,
                      size: 38,
                      color: fine.isDue
                          ? (isDark ? const Color(0xffF87171) : Colors.red)
                          : (isDark ? const Color(0xff4ADE80) : Colors.green),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              _buildDetailRow(context, 'Name', fine.memberName ?? fine.memberId),
              if (fine.phoneNumber != null && fine.phoneNumber!.isNotEmpty)
                _buildDetailRow(context, 'Mobile Number', fine.phoneNumber!),
              if (fine.memberEmail != null && fine.memberEmail!.isNotEmpty)
                _buildDetailRow(context, 'Email', fine.memberEmail!),
              _buildDetailRow(
                  context, 'Component', fine.componentName ?? fine.reason),
              _buildDetailRow(context, 'Qty', (fine.quantity ?? 1).toString()),
              if (fine.className != null && fine.className!.isNotEmpty)
                _buildDetailRow(context, 'Class', fine.className!),
              if (fine.issueDate != null && fine.issueDate!.isNotEmpty)
                _buildDetailRow(context, 'Issue Date', fine.issueDate!),
              if (fine.returnDate != null && fine.returnDate!.isNotEmpty)
                _buildDetailRow(context, 'Return Date', fine.returnDate!),
              _buildDetailRow(context, 'Reason', fine.reason),
              if (fine.transactionId != null && fine.transactionId!.isNotEmpty)
                _buildDetailRow(context, 'Transaction ID', fine.transactionId!,
                    isCopyable: true),
              if (fine.createdAt != null)
                _buildDetailRow(context, 'Assessed On', _formatDate(fine.createdAt!)),
              if (fine.createdBy != null)
                _buildDetailRow(context, 'Assessed By', fine.createdBy!),
              if (fine.isPaid) ...[
                if (fine.paidAt != null)
                  _buildDetailRow(context, 'Paid On', _formatDate(fine.paidAt!)),
                if (fine.paidBy != null)
                  _buildDetailRow(context, 'Collected By', fine.paidBy!),
              ],

              if (fine.isPaid) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.receipt_long_rounded, size: 20),
                    label: Text(
                      'Generate / Print Receipt',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: isDark ? const Color(0xff080E1A) : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      FineReceiptDialog.show(context, fine);
                    },
                  ),
                ),
              ],
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      height: 46,
                      child: ElevatedButton.icon(
                        icon: Icon(fine.isDue
                            ? Icons.check_circle
                            : Icons.refresh_rounded),
                        label: Text(
                          fine.isDue ? 'Mark as Paid' : 'Revert to Due',
                          style: GoogleFonts.montserrat(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              fine.isDue ? (isDark ? const Color(0xff15803D) : Colors.green[700]) : (isDark ? const Color(0xffC2410C) : Colors.orange[800]),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _toggleFineStatus(fine);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 46,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: Colors.redAccent, size: 18),
                        label: Text(
                          'Delete',
                          style: GoogleFonts.montserrat(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.redAccent,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.redAccent),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _confirmDeleteFine(fine);
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value,
      {bool isCopyable = false}) {
    final isDark = CAppTheme.isDark(context);
    final primaryText = CAppTheme.primaryTextColor(context);
    final secondaryText = CAppTheme.secondaryTextColor(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: GoogleFonts.lato(
                fontSize: 13,
                color: secondaryText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: GoogleFonts.lato(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: primaryText,
                    ),
                  ),
                ),
                if (isCopyable)
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: value));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied to clipboard')),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(Icons.copy, size: 14, color: isDark ? const Color(0xff38BDF8) : Colors.blue),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      return DateFormat('dd/MM/yy, hh:mm a').format(dt);
    } catch (_) {
      return isoString;
    }
  }

  Widget _buildStatusBadge(String status) {
    final isPaid = status.toLowerCase() == 'paid';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: isPaid ? Colors.green[50] : Colors.red[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPaid ? Colors.green : Colors.red,
          width: 1,
        ),
      ),
      child: Text(
        isPaid ? 'PAID' : 'DUE',
        style: GoogleFonts.lato(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isPaid ? Colors.green[800] : Colors.red[800],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CAppTheme.isDark(context);
    final primaryText = CAppTheme.primaryTextColor(context);
    final secondaryText = CAppTheme.secondaryTextColor(context);
    final accentColor = isDark ? const Color(0xff38BDF8) : const Color(0xff19335A);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: accentColor,
        foregroundColor: isDark ? const Color(0xff080E1A) : Colors.white,
        icon: const Icon(Icons.add),
        label: Text('Record Fine',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        onPressed: _showAddFineDialog,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: CAppTheme.bgGradient(context),
        ),
        child: RefreshIndicator(
          onRefresh: () => _loadFines(forceRefresh: true),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Header Summary Cards & Controls
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Fines & Penalty Logs',
                              style: GoogleFonts.montserrat(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: primaryText,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // View Switcher (Spreadsheet Table vs Cards)
                          Container(
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xff1E293B) : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark ? const Color(0xff334155) : Colors.transparent,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: Icon(
                                    Icons.table_chart_rounded,
                                    color: _isTableView
                                        ? accentColor
                                        : secondaryText,
                                  ),
                                  tooltip: 'Spreadsheet Table View',
                                  onPressed: () =>
                                      setState(() => _isTableView = true),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.view_agenda_rounded,
                                    color: !_isTableView
                                        ? accentColor
                                        : secondaryText,
                                  ),
                                  tooltip: 'Card List View',
                                  onPressed: () =>
                                      setState(() => _isTableView = false),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard(
                              title: 'Due Fines (Default)',
                              amount: '₹${_totalDueAmount.toStringAsFixed(0)}',
                              subtitle: '$_dueCount cases',
                              color: isDark ? const Color(0xffF87171) : Colors.red[700]!,
                              icon: Icons.pending_actions_rounded,
                              bgColor: Colors.red.withOpacity(isDark ? 0.2 : 0.1),
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricCard(
                              title: 'Collected Fines',
                              amount: '₹${_totalPaidAmount.toStringAsFixed(0)}',
                              subtitle: '$_paidCount paid',
                              color: isDark ? const Color(0xff4ADE80) : Colors.green[700]!,
                              icon: Icons.check_circle_outline,
                              bgColor: Colors.green.withOpacity(isDark ? 0.2 : 0.1),
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Scanned Member Banner
                      if (_scannedMemberId != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xff0284C7).withValues(alpha: 0.15)
                                : const Color(0xff19335A).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xff38BDF8).withValues(alpha: 0.4)
                                  : const Color(0xff19335A).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.qr_code_scanner_rounded,
                                  size: 20, color: accentColor),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Showing fines for member:',
                                      style: GoogleFonts.lato(
                                        fontSize: 11,
                                        color: secondaryText,
                                      ),
                                    ),
                                    Text(
                                      _scannedMemberName != null
                                          ? '$_scannedMemberName ($_scannedMemberId)'
                                          : _scannedMemberId!,
                                      style: GoogleFonts.montserrat(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: primaryText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.close, size: 20, color: secondaryText),
                                onPressed: _clearScannedMember,
                                tooltip: 'Clear filter',
                              ),
                            ],
                          ),
                        ),

                      // Search Bar + QR Button
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: CAppTheme.cardDecoration(context, radius: 12),
                              child: TextField(
                                controller: _searchController,
                                onChanged: (_) => _applyFilters(),
                                style: GoogleFonts.lato(
                                  fontSize: 13,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                                decoration: InputDecoration(
                                  hintText:
                                      'Search Name, Mobile, Component, Class...',
                                  hintStyle: GoogleFonts.lato(
                                      fontSize: 13, color: isDark ? const Color(0xff64748B) : Colors.grey),
                                  prefixIcon: Icon(Icons.search,
                                      color: accentColor),
                                  suffixIcon:
                                      _searchController.text.isNotEmpty
                                          ? IconButton(
                                              icon: Icon(Icons.clear, color: secondaryText),
                                              onPressed: () {
                                                _searchController.clear();
                                                _applyFilters();
                                              },
                                            )
                                          : null,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xff0284C7) : const Color(0xff19335A),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: isDark
                                      ? const Color(0xff38BDF8).withOpacity(0.3)
                                      : const Color(0xff19335A).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.qr_code_scanner_rounded,
                                  color: Colors.white),
                              onPressed: _scanMemberQR,
                              tooltip: 'Scan Member QR',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Filter Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip(
                                'all', 'All Logs (${_allFines.length})', isDark: isDark),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                              'due',
                              'Due / Default ($_dueCount)',
                              color: isDark ? const Color(0xffEF4444) : Colors.red,
                              isDark: isDark,
                            ),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                              'paid',
                              'Paid ($_paidCount)',
                              color: isDark ? const Color(0xff22C55E) : Colors.green,
                              isDark: isDark,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Content: Spreadsheet Table View vs Card View
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xff19335A)),
                  ),
                )
              else if (_filteredFines.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _allFines.isEmpty
                                ? 'No Fines on Record'
                                : 'No Matching Records Found',
                            style: GoogleFonts.montserrat(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _allFines.isEmpty
                                ? 'All members are in good standing.'
                                : 'Try searching with a different keyword.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.lato(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (_isTableView)
                // ── SPREADSHEET TABLE VIEW (Matches User's Table Design) ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      decoration: CAppTheme.cardDecoration(context, radius: 12),
                      clipBehavior: Clip.antiAlias,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: MaterialStateProperty.all(
                            isDark ? const Color(0xff0F172A) : const Color(0xff19335A),
                          ),
                          headingTextStyle: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          dataRowHeight: 56,
                          columns: const [
                            DataColumn(label: Text('Name')),
                            DataColumn(label: Text('Mobile Number')),
                            DataColumn(label: Text('Component')),
                            DataColumn(label: Text('Qty')),
                            DataColumn(label: Text('Class')),
                            DataColumn(label: Text('Issue Date')),
                            DataColumn(label: Text('Return Date')),
                            DataColumn(label: Text('Fine')),
                            DataColumn(label: Text('Action')),
                          ],
                          rows: _filteredFines.map((fine) {
                            final isPaid = fine.isPaid;
                            return DataRow(
                              color: MaterialStateProperty.resolveWith<Color?>(
                                (states) {
                                  if (isPaid) {
                                    return isDark
                                        ? const Color(0xff22C55E).withOpacity(0.08)
                                        : Colors.green.withOpacity(0.04);
                                  }
                                  return null;
                                },
                              ),
                              onSelectChanged: (_) => _showFineDetails(fine),
                              cells: [
                                // Name
                                DataCell(
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        fine.memberName ?? fine.memberId,
                                        style: GoogleFonts.montserrat(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: primaryText,
                                        ),
                                      ),
                                      if (fine.memberName != null)
                                        Text(
                                          fine.memberId,
                                          style: GoogleFonts.lato(
                                            fontSize: 11,
                                            color: secondaryText,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                // Mobile Number
                                DataCell(
                                  Text(
                                    fine.phoneNumber != null &&
                                            fine.phoneNumber!.isNotEmpty
                                        ? fine.phoneNumber!
                                        : '—',
                                    style: GoogleFonts.lato(
                                      fontSize: 13,
                                      color: isDark ? const Color(0xffCBD5E1) : Colors.black87,
                                    ),
                                  ),
                                ),
                                // Component
                                DataCell(
                                  ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 180),
                                    child: Text(
                                      fine.componentName ?? fine.reason,
                                      style: GoogleFonts.lato(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: isDark ? const Color(0xffF1F5F9) : Colors.black87,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 2,
                                    ),
                                  ),
                                ),
                                // Qty
                                DataCell(
                                  Center(
                                    child: Text(
                                      (fine.quantity ?? 1).toString(),
                                      style: GoogleFonts.lato(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: isDark ? const Color(0xffF1F5F9) : Colors.black87,
                                      ),
                                    ),
                                  ),
                                ),
                                // Class
                                DataCell(
                                  Text(
                                    fine.className ?? '—',
                                    style: GoogleFonts.lato(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: isDark ? const Color(0xffCBD5E1) : Colors.black87,
                                    ),
                                  ),
                                ),
                                // Issue Date
                                DataCell(
                                  Text(
                                    fine.issueDate ??
                                        (fine.createdAt != null
                                            ? _formatDate(fine.createdAt!)
                                            : '—'),
                                    style: GoogleFonts.lato(
                                      fontSize: 12,
                                      color: secondaryText,
                                    ),
                                  ),
                                ),
                                // Return Date
                                DataCell(
                                  Text(
                                    fine.returnDate ?? (isPaid ? 'Returned' : 'Pending'),
                                    style: GoogleFonts.lato(
                                      fontSize: 12,
                                      color: fine.returnDate != null
                                          ? (isDark ? const Color(0xffCBD5E1) : Colors.black87)
                                          : (isDark ? const Color(0xffF87171) : Colors.red[700]),
                                      fontWeight: fine.returnDate != null
                                          ? FontWeight.normal
                                          : FontWeight.w600,
                                    ),
                                  ),
                                ),
                                // Fine
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '₹${fine.amount.toStringAsFixed(0)}',
                                        style: GoogleFonts.montserrat(
                                          fontWeight: FontWeight.bold,
                                          color: isPaid
                                              ? (isDark ? const Color(0xff4ADE80) : Colors.green[800])
                                              : (isDark ? const Color(0xffF87171) : Colors.red[800]),
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      _buildStatusBadge(fine.status),
                                    ],
                                  ),
                                ),
                                // Action / Toggle Status & Delete
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isPaid) ...[
                                        IconButton(
                                          icon: Icon(
                                            Icons.receipt_long_rounded,
                                            size: 20,
                                            color: accentColor,
                                          ),
                                          tooltip: 'Generate / Print Receipt',
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 4),
                                          onPressed: () =>
                                              FineReceiptDialog.show(
                                                  context, fine),
                                        ),
                                        const SizedBox(width: 4),
                                      ],
                                      InkWell(
                                        onTap: () => _toggleFineStatus(fine),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: isPaid
                                                ? (isDark ? const Color(0xff334155) : Colors.grey[200])
                                                : (isDark ? const Color(0xff15803D) : Colors.green[700]),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                isPaid
                                                    ? Icons.undo_rounded
                                                    : Icons.check_circle_rounded,
                                                size: 14,
                                                color: isPaid
                                                    ? (isDark ? const Color(0xffCBD5E1) : Colors.black87)
                                                    : Colors.white,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                isPaid ? 'Revert' : 'Mark Paid',
                                                style: GoogleFonts.lato(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: isPaid
                                                      ? (isDark ? const Color(0xffCBD5E1) : Colors.black87)
                                                      : Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      IconButton(
                                        icon: const Icon(
                                            Icons.delete_outline_rounded,
                                            size: 18,
                                            color: Colors.red),
                                        tooltip: 'Delete Fine',
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(4),
                                        onPressed: () =>
                                            _confirmDeleteFine(fine),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                )
              else
                // ── CARD VIEW ──
                SliverPadding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final fine = _filteredFines[index];
                        return _buildFineCard(fine);
                      },
                      childCount: _filteredFines.length,
                    ),
                  ),
                ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 80),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String amount,
    required String subtitle,
    required Color color,
    required IconData icon,
    required Color bgColor,
    bool isDark = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xff1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xff334155) : const Color(0xffE2EAF4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.lato(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xff94A3B8) : Colors.grey[700],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            amount,
            style: GoogleFonts.montserrat(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            subtitle,
            style: GoogleFonts.lato(
              fontSize: 12,
              color: isDark ? const Color(0xff64748B) : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label, {Color? color, bool isDark = false}) {
    final isSelected = _selectedFilter == filterKey;
    final activeColor = color ?? (isDark ? const Color(0xff0284C7) : const Color(0xff19335A));

    return ChoiceChip(
      label: Text(
        label,
        style: GoogleFonts.lato(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected
              ? Colors.white
              : (isDark ? const Color(0xff94A3B8) : (color ?? const Color(0xff19335A))),
        ),
      ),
      selected: isSelected,
      selectedColor: activeColor,
      backgroundColor: isDark ? const Color(0xff1E293B) : Colors.white,
      side: BorderSide(
        color: isDark ? const Color(0xff334155) : const Color(0xffE2EAF4),
      ),
      onSelected: (_) {
        setState(() {
          _selectedFilter = filterKey;
          _applyFilters();
        });
      },
    );
  }

  Widget _buildFineCard(FineModel fine) {
    final isPaid = fine.isPaid;
    final isDark = CAppTheme.isDark(context);
    final primaryText = CAppTheme.primaryTextColor(context);
    final secondaryText = CAppTheme.secondaryTextColor(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: CAppTheme.cardDecoration(context, radius: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showFineDetails(fine),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fine.memberName ?? fine.memberId,
                            style: GoogleFonts.montserrat(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: primaryText,
                            ),
                          ),
                          if (fine.phoneNumber != null &&
                              fine.phoneNumber!.isNotEmpty)
                            Text(
                              'Phone: ${fine.phoneNumber}',
                              style: GoogleFonts.lato(
                                fontSize: 12,
                                color: secondaryText,
                              ),
                            ),
                          if (fine.className != null && fine.className!.isNotEmpty)
                            Text(
                              'Class: ${fine.className}',
                              style: GoogleFonts.lato(
                                fontSize: 11,
                                color: secondaryText,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${fine.amount.toStringAsFixed(0)}',
                          style: GoogleFonts.montserrat(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isPaid ? (isDark ? const Color(0xff4ADE80) : Colors.green[800]) : (isDark ? const Color(0xffF87171) : Colors.red[800]),
                          ),
                        ),
                        const SizedBox(height: 4),
                        _buildStatusBadge(fine.status),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xff0F172A) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? const Color(0xff334155) : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.memory_rounded,
                          size: 16, color: isDark ? const Color(0xff38BDF8) : const Color(0xff19335A)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${fine.componentName ?? fine.reason} (Qty: ${fine.quantity ?? 1})',
                          style: GoogleFonts.lato(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xffF1F5F9) : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Issue: ${fine.issueDate ?? "—"}  •  Return: ${fine.returnDate ?? (isPaid ? "Returned" : "Pending")}',
                        style: GoogleFonts.lato(
                          fontSize: 11,
                          color: secondaryText,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isPaid) ...[
                          IconButton(
                            icon: Icon(
                              Icons.receipt_long_rounded,
                              size: 20,
                              color: isDark ? const Color(0xff38BDF8) : const Color(0xff19335A),
                            ),
                            tooltip: 'Generate / Print Receipt',
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            onPressed: () =>
                                FineReceiptDialog.show(context, fine),
                          ),
                          const SizedBox(width: 2),
                        ],
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(50, 20),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: Icon(
                              isPaid
                                  ? Icons.undo_rounded
                                  : Icons.check_circle_rounded,
                              size: 14,
                              color: isPaid ? (isDark ? const Color(0xff94A3B8) : Colors.grey[700]) : (isDark ? const Color(0xff4ADE80) : Colors.green[800])),
                          label: Text(
                            isPaid ? 'Revert to Due' : 'Mark Paid',
                            style: GoogleFonts.lato(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isPaid ? (isDark ? const Color(0xffCBD5E1) : Colors.grey[800]) : (isDark ? const Color(0xff4ADE80) : Colors.green[800]),
                            ),
                          ),
                          onPressed: () => _toggleFineStatus(fine),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 18, color: Colors.red),
                          tooltip: 'Delete Fine',
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          onPressed: () => _confirmDeleteFine(fine),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
