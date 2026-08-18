import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:inventory/src/controllers/cache_controller.dart';
import 'package:inventory/src/data/cartcomponent.dart';
import 'package:inventory/src/features/authentication/controllers/componentController.dart';
import 'package:inventory/src/features/authentication/controllers/emailcontroller.dart';
import 'package:inventory/src/features/authentication/controllers/thankyoucontroller.dart';
import 'package:inventory/src/features/main_app/thankyou.dart';
import 'package:inventory/src/utils/theme/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

class Cartscreen extends StatefulWidget {
  const Cartscreen({super.key});

  @override
  State<Cartscreen> createState() => _CartscreenState();
}

class _CartscreenState extends State<Cartscreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  final TextEditingController searchMemberController = TextEditingController();
  final TextEditingController memberIdController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController classController = TextEditingController();
  final TextEditingController emailFieldController = TextEditingController();
  final MobileScannerController scannerController = MobileScannerController();

  final ComponentController componentcontroller =
      Get.find<ComponentController>();
  final Emailcontroller emailcontroller = Get.put(Emailcontroller());
  final Thankyoucontroller thankyoucontroller = Get.put(Thankyoucontroller());

  bool _isLoading = false;
  bool _isAutoFilling = false;
  Map<String, String>? _verifiedMember;
  String? _lookupErrorMessage;
  DateTime _expectedReturnDate = DateTime.now().add(const Duration(days: 7));
  final String uuid = const Uuid().v4();

  @override
  void dispose() {
    scannerController.dispose();
    searchMemberController.dispose();
    memberIdController.dispose();
    nameController.dispose();
    phoneController.dispose();
    classController.dispose();
    emailFieldController.dispose();
    super.dispose();
  }

  // Deduce formatted current date
  String dateFormater([DateTime? date]) {
    final d = date ?? DateTime.now();
    return '${d.day}/${d.month}/${d.year}';
  }

  // Pick Custom Expected Return Date
  Future<void> _selectExpectedReturnDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expectedReturnDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xff19335A),
              onPrimary: Colors.white,
              onSurface: Color(0xff19335A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _expectedReturnDate = picked;
      });
    }
  }

  // Update inventory stock on issue (decrements)
  Future<void> updateQuantity(Cartcomponent component) async {
    await componentcontroller.skuidanalyze(component.skuid);
    final tableName = componentcontroller.ClassName.value;
    if (tableName.isEmpty) return;

    final tablestock = await supabase
        .from(tableName)
        .select('stock')
        .eq('skuid', component.skuid)
        .maybeSingle();

    if (tablestock == null) return;
    final stockvalue = int.tryParse(tablestock['stock']?.toString() ?? '0') ?? 0;
    if (stockvalue <= 0) return;

    final finalstock = (stockvalue - component.Quantity).clamp(0, 999999);
    await supabase
        .from(tableName)
        .update({'stock': finalstock})
        .eq('skuid', component.skuid);
  }

  // Return inventory stock (increments)
  Future<void> returnQuantity(Cartcomponent component) async {
    await componentcontroller.skuidanalyze(component.skuid);
    final tableName = componentcontroller.ClassName.value;
    if (tableName.isEmpty) return;

    final tablestock = await supabase
        .from(tableName)
        .select('stock')
        .eq('skuid', component.skuid)
        .maybeSingle();

    if (tablestock == null) return;
    final stockvalue = int.tryParse(tablestock['stock']?.toString() ?? '0') ?? 0;
    final finalstock = stockvalue + component.Quantity;

    await supabase
        .from(tableName)
        .update({'stock': finalstock})
        .eq('skuid', component.skuid);

    final txId = componentcontroller.transactionid.value;
    if (txId.isNotEmpty) {
      await supabase.from('Transactions').update({
        'status': 'Returned',
        'returndate': dateFormater(),
      }).eq('transaction_id', txId);
    }

    thankyoucontroller.ThankyouStatus.value =
        'Successfully returned and re-added to the Inventory';
  }

  // Insert transaction into database with issuer's selected expected return date
  Future<void> insertCartComponents(
    String memberid,
    String name,
    String className,
    String phonenumber,
    List<Cartcomponent> cartcomponents,
  ) async {
    List<Map<String, dynamic>> cartcomponentsJson =
        cartcomponents.map((co) => co.toJson()).toList();

    final formattedReturnDate = componentcontroller.returnorissue.value
        ? dateFormater()
        : dateFormater(_expectedReturnDate);

    final data = {
      'id': memberid,
      'name': name,
      'class': className,
      'phonenumber': phonenumber,
      'package': cartcomponentsJson,
      'issuedby': emailcontroller.Namefrommail.value,
      'status': componentcontroller.returnorissue.value ? 'Returned' : 'Issued',
      'issuedate': dateFormater(),
      'returndate': formattedReturnDate,
      'transaction_id': uuid
    };

    try {
      await supabase.from('Transactions').insert(data);
    } catch (_) {}
  }

  // Schedule notification via OneSignal
  void scheduleNotification(DateTime scheduledDate) async {
    try {
      await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: {
          "Content-Type": "application/json; charset=UTF-8",
          "Authorization":
              "Basic ZjI3ZTcwZjEtNTU5Zi00NTYwLWJlMDEtNTUzYmE0ZWQ0MmIy"
        },
        body: jsonEncode({
          "app_id": "329b0b98-b961-4613-ae74-94e4c17dd44f",
          "included_segments": ["All"],
          "contents": {"en": "Reminder: Please return the item you borrowed."},
          "send_after": scheduledDate.toIso8601String()
        }),
      );
    } catch (_) {}
  }

  // Fetch member info from Members table by Email, Member ID, or Name (Same as Fine feature)
  Future<void> _lookupAndFillMember(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    setState(() {
      _isAutoFilling = true;
      _lookupErrorMessage = null;
    });

    Map<String, String>? foundMember;

    try {
      // 1. Try querying by "Email Id"
      dynamic response = await supabase
          .from('Members')
          .select()
          .ilike('Email Id', '%$trimmed%')
          .limit(1)
          .maybeSingle();

      // 2. If not found by email, try "ISA Login ID"
      response ??= await supabase
          .from('Members')
          .select()
          .ilike('ISA Login ID', '%$trimmed%')
          .limit(1)
          .maybeSingle();

      // 3. If not found by ID, try "Name"
      response ??= await supabase
          .from('Members')
          .select()
          .ilike('Name', '%$trimmed%')
          .limit(1)
          .maybeSingle();

      if (response != null) {
        foundMember = {
          'member_id': response['ISA Login ID']?.toString() ?? '',
          'name': response['Name']?.toString() ?? '',
          'email': response['Email Id']?.toString() ?? '',
          'phone': response['Phone Number']?.toString() ?? '',
          'class': response['Division']?.toString() ?? '',
        };
      }
    } catch (_) {}

    // Fallback: Fetch all members and match in memory
    if (foundMember == null) {
      try {
        final allMembers = await supabase.from('Members').select();
        final lowerQuery = trimmed.toLowerCase();
        for (var m in allMembers as List<dynamic>) {
          final email = (m['Email Id'] ?? '').toString().toLowerCase();
          final id = (m['ISA Login ID'] ?? '').toString().toLowerCase();
          final name = (m['Name'] ?? '').toString().toLowerCase();

          if (email.contains(lowerQuery) ||
              id.contains(lowerQuery) ||
              name.contains(lowerQuery)) {
            foundMember = {
              'member_id': m['ISA Login ID']?.toString() ?? '',
              'name': m['Name']?.toString() ?? '',
              'email': m['Email Id']?.toString() ?? '',
              'phone': m['Phone Number']?.toString() ?? '',
              'class': m['Division']?.toString() ?? '',
            };
            break;
          }
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _isAutoFilling = false;
        if (foundMember != null) {
          _verifiedMember = foundMember;
          _lookupErrorMessage = null;

          memberIdController.text = foundMember['member_id'] ?? '';
          nameController.text = foundMember['name'] ?? '';
          classController.text = foundMember['class'] ?? '';
          phoneController.text = foundMember['phone'] ?? '';
          emailFieldController.text = foundMember['email'] ?? '';
          searchMemberController.text = foundMember['email']?.isNotEmpty == true
              ? foundMember['email']!
              : foundMember['member_id']!;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Member Found: ${foundMember['name']} (${foundMember['member_id']})',
              ),
              backgroundColor: Colors.green[700],
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          _lookupErrorMessage =
              'No member found for "$trimmed". You can fill the fields manually below.';
        }
      });
    }
  }

  // QR Scanner for Member Info
  Future<void> _scanQRCode() async {
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
      builder: (dialogContext) => AlertDialog(
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
              controller: scannerController,
              onDetect: (capture) async {
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  if (barcode.rawValue != null &&
                      barcode.rawValue!.isNotEmpty) {
                    final raw = barcode.rawValue!;
                    scannerController.stop();
                    Navigator.of(dialogContext).pop();

                    String lookupQuery = raw.trim();
                    try {
                      final Map<String, dynamic> parsed = jsonDecode(raw);
                      lookupQuery = (parsed['email'] ??
                              parsed['member_id'] ??
                              parsed['id'] ??
                              raw)
                          .toString();
                    } catch (_) {}

                    searchMemberController.text = lookupQuery;
                    await _lookupAndFillMember(lookupQuery);
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
              scannerController.stop();
              Navigator.of(dialogContext).pop();
            },
            child: Text('Cancel', style: GoogleFonts.lato(color: Colors.grey[700])),
          ),
        ],
      ),
    );
  }

  // Handle Checkout submission
  Future<void> _handleCheckout() async {
    final isReturnMode = componentcontroller.returnorissue.value;

    if (!isReturnMode) {
      if (memberIdController.text.trim().isEmpty || nameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please provide Member ID and Name.'),
            backgroundColor: Colors.red[700],
          ),
        );
        return;
      }
    }

    if (componentcontroller.Cartcomponents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cart is empty. Please add components first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (!isReturnMode) {
        await insertCartComponents(
          memberIdController.text.trim(),
          nameController.text.trim(),
          classController.text.trim(),
          phoneController.text.trim(),
          componentcontroller.Cartcomponents,
        );

        await Future.wait(
          componentcontroller.Cartcomponents.map((item) => updateQuantity(item)),
        );

        scheduleNotification(_expectedReturnDate);
      } else {
        await Future.wait(
          componentcontroller.Cartcomponents.map((item) => returnQuantity(item)),
        );
      }

      // Invalidate cache so real-time counts are 100% accurate
      try {
        final cache = Get.find<CacheController>();
        cache.clearAll();
      } catch (_) {}

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => Thankyou()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during checkout: $e'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isReturnMode = componentcontroller.returnorissue.value;
    final totalQty = componentcontroller.Cartcomponents.fold<int>(
        0, (sum, item) => sum + item.Quantity);
    final isDark = CAppTheme.isDark(context);
    final primaryText = CAppTheme.primaryTextColor(context);
    final secondaryText = CAppTheme.secondaryTextColor(context);
    final accentColor = isDark ? const Color(0xff38BDF8) : const Color(0xff19335A);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xff0F172A) : const Color(0xff19335A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.shopping_bag_outlined, size: 22),
            const SizedBox(width: 10),
            Text(
              isReturnMode ? 'Return Cart' : 'Issue Cart',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.bold,
                fontSize: 19,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          // Clear cart button
          if (componentcontroller.Cartcomponents.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: Colors.white70),
              tooltip: 'Clear Cart',
              onPressed: () {
                setState(() {
                  componentcontroller.Cartcomponents.clear();
                });
              },
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: CAppTheme.bgGradient(context),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Banner (Issue vs Return)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isReturnMode
                        ? (isDark ? const [Color(0xff065F46), Color(0xff059669)] : const [Color(0xff0D7A53), const Color(0xff1DB978)])
                        : (isDark ? const [Color(0xff0F172A), Color(0xff1E293B)] : const [Color(0xff19335A), const Color(0xff2F548A)]),
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xff334155) : Colors.transparent,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isReturnMode
                          ? Icons.assignment_turned_in_rounded
                          : Icons.inventory_2_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isReturnMode
                              ? 'Returning Components to Stock'
                              : 'Issuing Components to Member',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isReturnMode
                              ? 'Transaction #${componentcontroller.transactionid.value}'
                              : 'Issued by: ${emailcontroller.Namefrommail.value.isNotEmpty ? emailcontroller.Namefrommail.value : "Admin"}',
                          style: GoogleFonts.lato(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$totalQty Item${totalQty == 1 ? "" : "s"}',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Borrower Member Information Section (Only for Issue mode)
            if (!isReturnMode) ...[
              _buildSectionCard(
                title: 'Borrower Member Details',
                icon: Icons.person_search_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search / Scan Bar with Auto-fetch
                    Text(
                      'Scan QR or Search Member (Auto-fetch)',
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xff19335A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xffF4F8FC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: TextField(
                              controller: searchMemberController,
                              onSubmitted: (val) => _lookupAndFillMember(val),
                              style: GoogleFonts.lato(fontSize: 13, color: Colors.black87),
                              decoration: InputDecoration(
                                hintText: 'Enter Email, ISA Login ID or Name...',
                                hintStyle: GoogleFonts.lato(fontSize: 12, color: Colors.grey[500]),
                                prefixIcon: const Icon(Icons.search, color: Color(0xff19335A), size: 18),
                                suffixIcon: searchMemberController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 16),
                                        onPressed: () {
                                          searchMemberController.clear();
                                          setState(() {
                                            _verifiedMember = null;
                                            _lookupErrorMessage = null;
                                            memberIdController.clear();
                                            nameController.clear();
                                            classController.clear();
                                            phoneController.clear();
                                            emailFieldController.clear();
                                          });
                                        },
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Fetch Button
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff19335A),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          onPressed: _isAutoFilling
                              ? null
                              : () => _lookupAndFillMember(searchMemberController.text),
                          child: _isAutoFilling
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Fetch', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 6),
                        // Scan QR Button
                        IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xff19335A).withValues(alpha: 0.1),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.all(10),
                          ),
                          icon: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xff19335A), size: 20),
                          tooltip: 'Scan Member QR',
                          onPressed: _scanQRCode,
                        ),
                      ],
                    ),

                    if (_lookupErrorMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _lookupErrorMessage!,
                        style: GoogleFonts.lato(fontSize: 11, color: Colors.red[700], fontWeight: FontWeight.w600),
                      ),
                    ],

                    // Verified Member Card Preview
                    if (_verifiedMember != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xff19335A).withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xff19335A).withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: const Color(0xff19335A),
                              child: Text(
                                _verifiedMember!['name']?.isNotEmpty == true
                                    ? _verifiedMember!['name']![0].toUpperCase()
                                    : 'M',
                                style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        _verifiedMember!['name'] ?? '',
                                        style: GoogleFonts.montserrat(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: const Color(0xff19335A),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'VERIFIED',
                                          style: GoogleFonts.lato(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green[800],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'ID: ${_verifiedMember!['member_id']} • Class: ${_verifiedMember!['class']}',
                                    style: GoogleFonts.lato(fontSize: 11, color: Colors.grey[700]),
                                  ),
                                  if (_verifiedMember!['email']?.isNotEmpty == true)
                                    Text(
                                      _verifiedMember!['email']!,
                                      style: GoogleFonts.lato(fontSize: 11, color: Colors.grey[600]),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 14),

                    // Auto-populated Form Fields (Editable if necessary)
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _buildModernInputField(
                            controller: memberIdController,
                            label: 'Member ID',
                            hint: 'e.g. D7B-19',
                            icon: Icons.badge_outlined,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: _buildModernInputField(
                            controller: classController,
                            label: 'Class / Div',
                            hint: 'e.g. D7B',
                            icon: Icons.school_outlined,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildModernInputField(
                      controller: nameController,
                      label: 'Full Name',
                      hint: 'Student full name',
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 12),
                    _buildModernInputField(
                      controller: phoneController,
                      label: 'Phone Number',
                      hint: '10-digit mobile number',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Expected Return Date Card (Selected by Issuer)
              _buildSectionCard(
                title: 'Expected Return Date',
                icon: Icons.event_available_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Interactive Date Picker Field
                    InkWell(
                      onTap: _selectExpectedReturnDate,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xffF4F8FC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xff19335A).withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xff19335A).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.calendar_month_rounded,
                                    color: Color(0xff19335A),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      DateFormat('EEEE, dd MMMM yyyy').format(_expectedReturnDate),
                                      style: GoogleFonts.montserrat(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xff19335A),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Due in ${_expectedReturnDate.difference(DateTime.now()).inDays + 1} day(s)',
                                      style: GoogleFonts.lato(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.orange[900],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const Icon(
                              Icons.edit_calendar_rounded,
                              color: Color(0xff19335A),
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Quick duration preset chips
                    Text(
                      'Quick Presets:',
                      style: GoogleFonts.lato(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        {'label': '3 Days', 'days': 3},
                        {'label': '7 Days (1 Wk)', 'days': 7},
                        {'label': '14 Days (2 Wks)', 'days': 14},
                        {'label': '30 Days (1 Mo)', 'days': 30},
                      ].map((preset) {
                        final days = preset['days'] as int;
                        final targetDate = DateTime.now().add(Duration(days: days));
                        final isSelected = _expectedReturnDate.year == targetDate.year &&
                            _expectedReturnDate.month == targetDate.month &&
                            _expectedReturnDate.day == targetDate.day;

                        return ChoiceChip(
                          label: Text(preset['label'] as String),
                          labelStyle: GoogleFonts.lato(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.white : const Color(0xff19335A),
                          ),
                          selected: isSelected,
                          selectedColor: const Color(0xff19335A),
                          backgroundColor: Colors.grey[100],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _expectedReturnDate = targetDate;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],

            // Component Items Section
            _buildSectionCard(
              title: 'Items in Cart',
              icon: Icons.format_list_bulleted_rounded,
              headerBadge: Text(
                '${componentcontroller.Cartcomponents.length} components',
                style: GoogleFonts.lato(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
              child: componentcontroller.Cartcomponents.isEmpty
                  ? Container(
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      alignment: Alignment.center,
                      child: Column(
                        children: [
                          Icon(
                            Icons.remove_shopping_cart_outlined,
                            size: 52,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Your cart is currently empty',
                            style: GoogleFonts.montserrat(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Scan barcodes or select components to add items.',
                            style: GoogleFonts.lato(
                              fontSize: 13,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: componentcontroller.Cartcomponents.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = componentcontroller.Cartcomponents[index];
                        return _buildComponentItemCard(item, index);
                      },
                    ),
            ),

            const SizedBox(height: 24),

            // Order Summary & Due Date details
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildSummaryRow(
                    'Transaction Type',
                    isReturnMode ? 'Return / Restock' : 'Issue / Borrow',
                    valueColor: isReturnMode ? Colors.green[800] : const Color(0xff19335A),
                    isBold: true,
                  ),
                  const Divider(height: 20),
                  _buildSummaryRow(
                    'Total Distinct Components',
                    '${componentcontroller.Cartcomponents.length}',
                  ),
                  const SizedBox(height: 8),
                  _buildSummaryRow(
                    'Total Quantity Units',
                    '$totalQty units',
                  ),
                  const SizedBox(height: 8),
                  _buildSummaryRow(
                    isReturnMode ? 'Return Date' : 'Issue Date',
                    dateFormater(),
                  ),
                  if (!isReturnMode) ...[
                    const SizedBox(height: 8),
                    _buildSummaryRow(
                      'Expected Return Due',
                      DateFormat('dd/MM/yyyy').format(_expectedReturnDate),
                      valueColor: Colors.orange[900],
                      isBold: true,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Primary Checkout Action Button
            Container(
              width: double.infinity,
              height: 54,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isReturnMode
                      ? [const Color(0xff0D7A53), const Color(0xff1DB978)]
                      : [const Color(0xff19335A), const Color(0xff2A4E80)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: (isReturnMode
                            ? Colors.green
                            : const Color(0xff19335A))
                        .withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleCheckout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isReturnMode
                                ? Icons.assignment_turned_in_rounded
                                : Icons.check_circle_outline_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            isReturnMode
                                ? 'Confirm & Return Items'
                                : 'Confirm & Issue Components',
                            style: GoogleFonts.montserrat(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
  );
}

  // Component Card Tile
  Widget _buildComponentItemCard(Cartcomponent item, int index) {
    final isDark = CAppTheme.isDark(context);
    final primaryText = CAppTheme.primaryTextColor(context);
    final secondaryText = CAppTheme.secondaryTextColor(context);
    final accentColor = isDark ? const Color(0xff38BDF8) : const Color(0xff19335A);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xff0F172A) : const Color(0xffF9FBFE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xff334155) : const Color(0xffE2EAF4)),
      ),
      child: Row(
        children: [
          // Icon Avatar
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.memory_rounded,
              color: accentColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          // Component Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.compname,
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: primaryText,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xff1E293B) : Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: isDark ? const Color(0xff334155) : Colors.transparent),
                  ),
                  child: Text(
                    item.skuid,
                    style: GoogleFonts.lato(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xffCBD5E1) : Colors.grey[800],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Quantity Badge / Controls
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Qty: ${item.Quantity}',
              style: GoogleFonts.montserrat(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: accentColor,
              ),
            ),
          ),
          const SizedBox(width: 4),

          // Delete action
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18, color: Colors.redAccent),
            tooltip: 'Remove from cart',
            onPressed: () {
              setState(() {
                componentcontroller.Cartcomponents.removeAt(index);
              });
            },
          ),
        ],
      ),
    );
  }

  // Modern Input Field Widget
  Widget _buildModernInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffix,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
  }) {
    final isDark = CAppTheme.isDark(context);
    final primaryText = CAppTheme.primaryTextColor(context);
    final accentColor = isDark ? const Color(0xff38BDF8) : const Color(0xff19335A);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: primaryText,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xff0F172A) : const Color(0xffF9FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? const Color(0xff334155) : Colors.grey[300]!),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            onChanged: onChanged,
            style: GoogleFonts.lato(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.lato(fontSize: 13, color: isDark ? const Color(0xff64748B) : Colors.grey[400]),
              prefixIcon: Icon(icon, color: accentColor, size: 18),
              suffixIcon: suffix,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            ),
          ),
        ),
      ],
    );
  }

  // Section Card Container
  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? headerAction,
    Widget? headerBadge,
  }) {
    final isDark = CAppTheme.isDark(context);
    final primaryText = CAppTheme.primaryTextColor(context);
    final accentColor = isDark ? const Color(0xff38BDF8) : const Color(0xff19335A);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xff1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xff334155) : Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: accentColor),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: primaryText,
                    ),
                  ),
                ],
              ),
              if (headerBadge != null) headerBadge,
              if (headerAction != null) headerAction,
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: isDark ? const Color(0xff334155) : const Color(0xffE2EAF4)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  // Summary Row Widget
  Widget _buildSummaryRow(
    String label,
    String value, {
    Color? valueColor,
    bool isBold = false,
  }) {
    final isDark = CAppTheme.isDark(context);
    final primaryText = CAppTheme.primaryTextColor(context);
    final secondaryText = CAppTheme.secondaryTextColor(context);
    final accentColor = isDark ? const Color(0xff38BDF8) : const Color(0xff19335A);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.lato(
            fontSize: 13,
            color: secondaryText,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.montserrat(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor ?? primaryText,
          ),
        ),
      ],
    );
  }
}
