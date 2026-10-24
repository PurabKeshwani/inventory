import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inventory/src/data/cartcomponent.dart';
import 'package:inventory/src/features/authentication/controllers/componentController.dart';
import 'package:inventory/src/features/main_app/cartscreen/cartscreen.dart';
import 'package:inventory/src/features/main_app/transactions_screen/member_transactions_screen.dart';
import 'package:inventory/src/data/model.dart';
import 'package:inventory/src/services/component_lookup_service.dart';
import 'package:inventory/src/utils/theme/theme.dart';
import 'package:inventory/src/utils/inventory_barcode_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

class TransactionScreen extends StatefulWidget {
  const TransactionScreen({super.key});

  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  String _scanBarcode = 'Unknown';
  late String barcode;
  late String compname = '';
  bool returnstate = false;
  bool _isProcessingScan = false; // prevents duplicate onDetect firings
  bool _isProcessing = false; // guards duplicate lookup / submission attempts
  String? _manualError; // inline manual-entry error message
  final ComponentController componentcontroller =
      Get.find<ComponentController>();
  final InventoryBarcodeScanner _scanner =
      InventoryBarcodeScanner('issue component');

  final transactionidcontroller = TextEditingController();
  final returnTransactionIdController = TextEditingController();
  final _manualSkuController = TextEditingController();

  @override
  void dispose() {
    transactionidcontroller.dispose();
    returnTransactionIdController.dispose();
    _manualSkuController.dispose();
    unawaited(_scanner.dispose());
    super.dispose();
  }

  Future<void> fetchTransactionComponents(String transactionId) async {
    if (transactionId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid transaction ID')),
      );
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('Transactions')
          .select()
          .eq('transaction_id', transactionId)
          .single();

      // Check if the transaction is already returned
      final status =
          (response['status']?.toString() ?? '').trim().toLowerCase();
      final alreadyReturned = status == 'returned' ||
          status == 'return' ||
          status == 'returned to inventory' ||
          status == 'closed';

      if (alreadyReturned) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This transaction has already been returned'),
          ),
        );
        return;
      }

      // Set the transaction ID in the controller
      componentcontroller.transactionid.value =
          returnTransactionIdController.text;

      // Clear existing cart components
      componentcontroller.Cartcomponents.clear();

      // Safely parse the package JSON
      var rawPkg = response['package'];
      List<dynamic> components = [];
      if (rawPkg is String) {
        try {
          components = jsonDecode(rawPkg);
        } catch (_) {}
      } else if (rawPkg is List) {
        components = rawPkg;
      }

      // Add each component to the cart
      for (var comp in components) {
        if (comp is Map) {
          componentcontroller.Cartcomponents.add(Cartcomponent(
            compname:
                (comp['compname'] ?? comp['name'] ?? 'Component').toString(),
            skuid: (comp['skuid'] ?? '').toString(),
            Quantity: int.tryParse(comp['Quantity']?.toString() ??
                    comp['quantity']?.toString() ??
                    '1') ??
                1,
          ));
        }
      }
      setState(() {
        returnstate = true;
        componentcontroller.Status.value = 'Returned';
        componentcontroller.returnorissue.value = true;
      });
    } catch (e) {
      print('Error fetching transaction: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Transaction not found or error occurred')),
      );
    }
  }

  Future<void> _processBarcode(String scanResult) async {
    _scanBarcode = ComponentLookupService.normalizeManualIdentifier(scanResult);
    barcode = _scanBarcode;
    if (!mounted) return;
    await _processIdentifier(scanResult, requireConfirmation: false);
  }

  /// Shared lookup -> validation -> cart workflow used by both barcode scan
  /// and manual entry. Reuses the exact-SKU lookup for both entry methods.
  Future<void> _processIdentifier(
    String raw, {
    required bool requireConfirmation,
  }) async {
    if (!mounted || _isProcessing) return;

    final sku = ComponentLookupService.normalizeManualIdentifier(raw);
    if (sku.isEmpty) {
      _setManualError('Please enter a barcode or SKU.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _manualError = null;
    });

    ComponentLookupResult result;
    try {
      result = await ComponentLookupService().lookupComponentBySku(sku);
    } catch (error) {
      result = ComponentLookupError('Unexpected error: $error');
    }

    if (!mounted) return;
    setState(() => _isProcessing = false);

    String? message;
    Component? matched;
    String? tableName;

    if (result is ComponentLookupEmpty) {
      message = 'Please enter a barcode or SKU.';
    } else if (result is ComponentLookupNotFound) {
      message = 'Component not found: "$sku".';
    } else if (result is ComponentLookupAmbiguous) {
      message = 'Multiple records match SKU "$sku". Contact an administrator.';
    } else if (result is ComponentLookupError) {
      message = result.message;
    } else if (result is ComponentLookupFound) {
      matched = result.component;
      tableName = result.tableName;
    }

    if (message != null) {
      _showSnackBar(message, color: Colors.red);
      return;
    }

    if (matched == null || tableName == null) {
      _showSnackBar('Component not found: "$sku".', color: Colors.red);
      return;
    }

    // Out-of-stock check using the exact stock fetched during lookup.
    if (matched.stock <= 0) {
      _showSnackBar('No stock available for "${matched.name}" (SKU: $sku).',
          color: Colors.red);
      return;
    }

    // Manual entry requires explicit confirmation before staging.
    bool add = true;
    if (requireConfirmation) {
      add = await _showConfirmComponentDialog(matched, tableName, sku) == true;
      if (!mounted) return;
    }
    if (!add) return;

    // Prevent duplicate cart entries.
    final alreadyStaged = componentcontroller.Cartcomponents.any(
      (component) => component.skuid == sku,
    );
    if (alreadyStaged) {
      _showSnackBar(
        'Component already added to cart',
        color: Colors.orange,
      );
      return;
    }

    final comp = matched;
    final tname = tableName;

    // Mirror the controller state the checkout flow reads downstream.
    componentcontroller.ClassName.value = tname;
    componentcontroller.CompName.value = comp.name;
    componentcontroller.Boxname.value = comp.boxNo;
    componentcontroller.Quantity.value = comp.stock;

    setState(() {
      componentcontroller.Cartcomponents.add(Cartcomponent(
        compname: comp.name,
        skuid: sku,
        Quantity: 1,
      ));
    });

    _showSnackBar(
      'Added "${comp.name}" (SKU: $sku) to cart',
      color: Colors.green,
    );
  }

  void _setManualError(String message) {
    if (!mounted) return;
    setState(() {
      _manualError = message;
      _isProcessing = false;
    });
  }

  void _showSnackBar(String content, {Color color = Colors.red}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(content), backgroundColor: color),
    );
  }

  Future<void> _findManual() async {
    if (_isProcessing) return;
    await _processIdentifier(_manualSkuController.text,
        requireConfirmation: true);
  }

  Future<bool?> _showConfirmComponentDialog(
    Component component,
    String tableName,
    String sku,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final isDark = CAppTheme.isDark(dialogContext);
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xff1E293B) : Colors.white,
          title: Text(
            'Confirm Component',
            style: GoogleFonts.montserrat(
              color: CAppTheme.primaryTextColor(dialogContext),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                component.name,
                style: GoogleFonts.montserrat(
                  color: CAppTheme.primaryTextColor(dialogContext),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text('SKU: $sku',
                  style: GoogleFonts.robotoMono(
                    color: CAppTheme.secondaryTextColor(dialogContext),
                  )),
              Text('Box: ${component.boxNo}',
                  style: GoogleFonts.lato(
                    color: CAppTheme.secondaryTextColor(dialogContext),
                  )),
              Text('Class: $tableName',
                  style: GoogleFonts.lato(
                    color: CAppTheme.secondaryTextColor(dialogContext),
                  )),
              Text('Stock: ${component.stock}',
                  style: GoogleFonts.lato(
                    color: CAppTheme.secondaryTextColor(dialogContext),
                  )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Add to Cart'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _startBarcodeScan() async {
    try {
      // Request camera permission first
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Camera permission is required for scanning'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (!mounted) return;

      _isProcessingScan = false; // reset guard for this new scan attempt
      _scanner.setScannerVisible(true);

      final isDark = CAppTheme.isDark(context);
      final dialogWidth = MediaQuery.of(context).size.width * 0.92;

      // Show scanner in a dialog
      showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            height: 420,
            width: dialogWidth,
            constraints: const BoxConstraints(maxWidth: 420),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xff1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? const Color(0xff334155) : Colors.transparent,
              ),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xff0F172A)
                        : const Color(0xff19335A),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Scan Barcode',
                        style: GoogleFonts.lato(
                          textStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                // Scanner
                Expanded(
                  child: Stack(
                    children: [
                      MobileScanner(
                        controller: _scanner.controller,
                        errorBuilder: _scanner.buildError,
                        onDetect: (capture) {
                          _scanner.logCapture(capture);
                          if (_isProcessingScan) return;
                          final List<Barcode> barcodes = capture.barcodes;
                          for (final barcode in barcodes) {
                            final code = barcode.rawValue;
                            if (code == null || code.trim().isEmpty) continue;
                            _isProcessingScan = true;
                            Navigator.pop(context);
                            unawaited(_processBarcode(code));
                            break;
                          }
                        },
                      ),
                      // Scanner overlay
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color:
                                isDark ? const Color(0xff38BDF8) : Colors.white,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        margin: const EdgeInsets.all(40),
                      ),
                      // Corner markers
                      Positioned(
                        top: 40,
                        left: 40,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                  color: Color(0xff38BDF8), width: 3),
                              left: BorderSide(
                                  color: Color(0xff38BDF8), width: 3),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 40,
                        right: 40,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                  color: Color(0xff38BDF8), width: 3),
                              right: BorderSide(
                                  color: Color(0xff38BDF8), width: 3),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 40,
                        left: 40,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                  color: Color(0xff38BDF8), width: 3),
                              left: BorderSide(
                                  color: Color(0xff38BDF8), width: 3),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 40,
                        right: 40,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                  color: Color(0xff38BDF8), width: 3),
                              right: BorderSide(
                                  color: Color(0xff38BDF8), width: 3),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Footer
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: IconButton(
                    tooltip: 'Toggle flashlight',
                    onPressed: _scanner.controller.toggleTorch,
                    icon: ValueListenableBuilder(
                      valueListenable: _scanner.controller,
                      builder: (context, state, child) => Icon(
                        state.torchState == TorchState.on
                            ? Icons.flash_on
                            : Icons.flash_off,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ).whenComplete(() => _scanner.setScannerVisible(false));
    } catch (e) {
      print('DEBUG: Error in scanner: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accessing scanner: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CAppTheme.isDark(context);
    final primaryText = CAppTheme.primaryTextColor(context);
    final secondaryText = CAppTheme.secondaryTextColor(context);
    final accentColor =
        isDark ? const Color(0xff38BDF8) : const Color(0xff19335A);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: CAppTheme.bgGradient(context),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Action & Instructions Section
              Flexible(
                fit: FlexFit.loose,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Column(
                      children: [
                        // Instructions Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration:
                              CAppTheme.cardDecoration(context, radius: 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info_outline_rounded,
                                      size: 16, color: accentColor),
                                  const SizedBox(width: 6),
                                  Text(
                                    'How to Use',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: primaryText,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 18,
                                    height: 18,
                                    margin:
                                        const EdgeInsets.only(top: 2, right: 8),
                                    decoration: BoxDecoration(
                                      color: accentColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '1',
                                        style: TextStyle(
                                          color: isDark
                                              ? const Color(0xff080E1A)
                                              : Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      'Scan components barcode to stage items in your cart and issue them by setting a return date.',
                                      style: GoogleFonts.lato(
                                          fontSize: 12,
                                          color: secondaryText,
                                          height: 1.35),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 18,
                                    height: 18,
                                    margin:
                                        const EdgeInsets.only(top: 2, right: 8),
                                    decoration: BoxDecoration(
                                      color: accentColor.withValues(alpha: 0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '2',
                                        style: TextStyle(
                                          color: accentColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      'To view transaction to apply penalty, change due status scan member code or look up member ID or enter transaction id.',
                                      style: GoogleFonts.lato(
                                          fontSize: 12,
                                          color: secondaryText,
                                          height: 1.35),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Action Buttons
                        Row(
                          children: [
                            // Scan Component Barcode
                            Expanded(
                              child: InkWell(
                                onTap: () => _startBarcodeScan(),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 13, horizontal: 8),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: isDark
                                          ? const [
                                              Color(0xff0284C7),
                                              Color(0xff0369A1)
                                            ]
                                          : const [
                                              Color(0xff19335A),
                                              Color(0xff274A7C)
                                            ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (isDark
                                                ? const Color(0xff0284C7)
                                                : const Color(0xff19335A))
                                            .withValues(alpha: 0.25),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.qr_code_scanner_rounded,
                                          color: Colors.white, size: 18),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          'Scan to Issue',
                                          style: GoogleFonts.montserrat(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Scan Member to View Transactions
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const MemberTransactionsScreen(),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 13, horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xff1E293B)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isDark
                                          ? const Color(0xff38BDF8)
                                              .withValues(alpha: 0.4)
                                          : const Color(0xff19335A),
                                      width: 1.3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.03),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.person_search_rounded,
                                        color: accentColor,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          'Member Loans',
                                          style: GoogleFonts.montserrat(
                                            color: accentColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        _buildManualEntryCard(),
                      ],
                    ),
                  ),
                ),
              ),

              // Staging Cart List Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18.0, vertical: 6.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Staged Components (${componentcontroller.Cartcomponents.length})',
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: primaryText,
                      ),
                    ),
                    if (componentcontroller.Cartcomponents.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            componentcontroller.Cartcomponents.clear();
                          });
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(50, 24),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Clear All',
                          style: GoogleFonts.lato(
                            color: isDark
                                ? const Color(0xffF87171)
                                : Colors.red[700],
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Staging Cart List Section
              Expanded(
                child: componentcontroller.Cartcomponents.isEmpty
                    ? LayoutBuilder(
                        builder: (context, constraints) =>
                            SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color:
                                            accentColor.withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.inventory_2_outlined,
                                        size: 42,
                                        color: accentColor,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'No Components Staged',
                                      style: GoogleFonts.montserrat(
                                        color: primaryText,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Tap "Scan to Issue" above to scan barcode and add items.',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.lato(
                                        color: secondaryText,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        itemCount: componentcontroller.Cartcomponents.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, index) {
                          final component =
                              componentcontroller.Cartcomponents[index];
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration:
                                CAppTheme.cardDecoration(context, radius: 12),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: accentColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.memory_rounded,
                                      size: 20, color: accentColor),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        component.compname,
                                        style: GoogleFonts.montserrat(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: primaryText,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'SKU: ${component.skuid}',
                                              style: GoogleFonts.robotoMono(
                                                fontSize: 11,
                                                color: secondaryText,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: accentColor.withValues(
                                                  alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'Qty: ${component.Quantity}',
                                              style: GoogleFonts.montserrat(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: accentColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded,
                                      color: Colors.red, size: 20),
                                  onPressed: () {
                                    setState(() {
                                      componentcontroller.Cartcomponents.remove(
                                          component);
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content:
                                            Text('Component removed from cart'),
                                        backgroundColor: Colors.red,
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),

              // Fixed Bottom Proceed to Cart Bar
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xff0F172A) : Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? const Color(0xff334155)
                          : const Color(0xffE2EAF4),
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          Colors.black.withValues(alpha: isDark ? 0.4 : 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Staged Package',
                            style: GoogleFonts.montserrat(
                              color: primaryText,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${componentcontroller.Cartcomponents.length} item${componentcontroller.Cartcomponents.length == 1 ? '' : 's'} in cart',
                            style: GoogleFonts.lato(
                              color: secondaryText,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const Cartscreen()),
                        );
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 11),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark
                                ? const [Color(0xff0284C7), Color(0xff0369A1)]
                                : const [Color(0xff19335A), Color(0xff274A7C)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: (isDark
                                      ? const Color(0xff0284C7)
                                      : const Color(0xff19335A))
                                  .withValues(alpha: 0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.shopping_cart_checkout_rounded,
                                color: Colors.white, size: 17),
                            const SizedBox(width: 8),
                            Text(
                              'Proceed to Cart',
                              style: GoogleFonts.montserrat(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManualEntryCard() {
    final isDark = CAppTheme.isDark(context);
    final primaryText = CAppTheme.primaryTextColor(context);
    final accentColor =
        isDark ? const Color(0xff38BDF8) : const Color(0xff19335A);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: CAppTheme.cardDecoration(context, radius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.input_rounded, size: 16, color: accentColor),
              const SizedBox(width: 6),
              Text(
                'Enter Barcode/SKU Manually',
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _manualSkuController,
                  onSubmitted: (_) => _findManual(),
                  style: GoogleFonts.lato(
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Type or paste barcode / SKU',
                    hintStyle: GoogleFonts.lato(
                      fontSize: 12,
                      color:
                          isDark ? const Color(0xff64748B) : Colors.grey[500],
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color: isDark
                              ? const Color(0xff334155)
                              : Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color: isDark
                              ? const Color(0xff334155)
                              : Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xff19335A)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onPressed: _isProcessing ? null : () => _findManual(),
                child: _isProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Find Component',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
          if (_manualError != null) ...[
            const SizedBox(height: 8),
            Text(
              _manualError!,
              style: GoogleFonts.lato(
                  fontSize: 11,
                  color: Colors.red[700],
                  fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }
}
