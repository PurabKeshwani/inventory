import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inventory/src/data/cartcomponent.dart';
import 'package:inventory/src/features/authentication/controllers/componentController.dart';
import 'package:inventory/src/features/main_app/cartscreen/cartscreen.dart';
import 'package:inventory/src/features/main_app/transactions_screen/member_transactions_screen.dart';
import 'package:inventory/src/utils/theme/theme.dart';
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
  final ComponentController componentcontroller =
      Get.find<ComponentController>();

  final transactionidcontroller = TextEditingController();
  final returnTransactionIdController = TextEditingController();

  Future<bool> checkStockAvailability(String skuid) async {
    try {
      if (componentcontroller.ClassName.value.isEmpty) {
        return false;
      }

      final response = await Supabase.instance.client
          .from(componentcontroller.ClassName.value)
          .select()
          .eq('skuid', skuid)
          .maybeSingle();

      if (response != null) {
        var stockValue = response['stock'];

        int currentStock = 0;

        if (stockValue != null) {
          if (stockValue is String) {
            currentStock = int.parse(stockValue);
          } else if (stockValue is num) {
            currentStock = stockValue.toInt();
          }
        }

        return currentStock > 0;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
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
      if (response['status'] == 'Returned') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('This transaction has already been returned')),
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
            compname: (comp['compname'] ?? comp['name'] ?? 'Component').toString(),
            skuid: (comp['skuid'] ?? '').toString(),
            Quantity: int.tryParse(comp['Quantity']?.toString() ?? comp['quantity']?.toString() ?? '1') ?? 1,
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
        const SnackBar(content: Text('Transaction not found or error occurred')),
      );
    }
  }

  Future<void> _processBarcode(String scanResult) async {
    final String sanitized = scanResult.trim();

    if (!mounted) return;

    setState(() {
      _scanBarcode = sanitized;
      barcode = sanitized;
    });

    try {
      await componentcontroller.skuidanalyze(barcode);

      final hasStock = await checkStockAvailability(barcode);

      if (!hasStock) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No stock available for this component'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (mounted) {
        // Check if component with same SKUID already exists
        bool componentExists = componentcontroller.Cartcomponents.any(
            (component) => component.skuid == barcode);

        if (componentExists) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Component already added to cart'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }

        setState(() {
          final newComponent = Cartcomponent(
            compname: componentcontroller.CompName.value,
            skuid: barcode,
            Quantity: 1,
          );
          componentcontroller.Cartcomponents.add(newComponent);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing barcode: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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


      // Show scanner in a dialog
      showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            height: 400,
            width: 350,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xff19335A),
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
                        onDetect: (capture) {
                          if (_isProcessingScan) return;
                          final List<Barcode> barcodes = capture.barcodes;
                          if (barcodes.isNotEmpty) {
                            final String? code = barcodes.first.rawValue;
                            if (code != null) {
                              final String normalized = code.trim();
                              if (normalized.isEmpty) return;
                              _isProcessingScan = true;
                              print('DEBUG: Barcode detected: $normalized');
                              Navigator.pop(context); // Close scanner
                              _processBarcode(normalized);
                            }
                          }
                        },
                      ),
                      // Scanner overlay
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.white,
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
                              top: BorderSide(color: Colors.white, width: 3),
                              left: BorderSide(color: Colors.white, width: 3),
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
                              top: BorderSide(color: Colors.white, width: 3),
                              right: BorderSide(color: Colors.white, width: 3),
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
                              bottom: BorderSide(color: Colors.white, width: 3),
                              left: BorderSide(color: Colors.white, width: 3),
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
                              bottom: BorderSide(color: Colors.white, width: 3),
                              right: BorderSide(color: Colors.white, width: 3),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Footer
              ],
            ),
          ),
        ),
      );
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
    final accentColor = isDark ? const Color(0xff38BDF8) : const Color(0xff19335A);

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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Column(
                  children: [
                    // Instructions Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: CAppTheme.cardDecoration(context, radius: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline_rounded, size: 16, color: accentColor),
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
                                margin: const EdgeInsets.only(top: 2, right: 8),
                                decoration: BoxDecoration(
                                  color: accentColor,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '1',
                                    style: TextStyle(
                                      color: isDark ? const Color(0xff080E1A) : Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'Scan components barcode to stage items in your cart and issue them by setting a return date.',
                                  style: GoogleFonts.lato(fontSize: 12, color: secondaryText, height: 1.35),
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
                                margin: const EdgeInsets.only(top: 2, right: 8),
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
                                  style: GoogleFonts.lato(fontSize: 12, color: secondaryText, height: 1.35),
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
                              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isDark
                                      ? const [Color(0xff0284C7), Color(0xff0369A1)]
                                      : const [Color(0xff19335A), Color(0xff274A7C)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: (isDark ? const Color(0xff0284C7) : const Color(0xff19335A))
                                        .withValues(alpha: 0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 18),
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
                                  builder: (context) => const MemberTransactionsScreen(),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xff1E293B) : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark ? const Color(0xff38BDF8).withValues(alpha: 0.4) : const Color(0xff19335A),
                                  width: 1.3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
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
                  ],
                ),
              ),

              // Staging Cart List Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 6.0),
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
                            color: isDark ? const Color(0xffF87171) : Colors.red[700],
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
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.inventory_2_outlined,
                                  size: 48,
                                  color: accentColor,
                                ),
                              ),
                              const SizedBox(height: 14),
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
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        itemCount: componentcontroller.Cartcomponents.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, index) {
                          final component = componentcontroller.Cartcomponents[index];
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: CAppTheme.cardDecoration(context, radius: 12),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: accentColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.memory_rounded, size: 20, color: accentColor),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
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
                                          Text(
                                            'SKU: ${component.skuid}',
                                            style: GoogleFonts.robotoMono(
                                              fontSize: 11,
                                              color: secondaryText,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: accentColor.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
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
                                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                                  onPressed: () {
                                    setState(() {
                                      componentcontroller.Cartcomponents.remove(component);
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Component removed from cart'),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xff0F172A) : Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: isDark ? const Color(0xff334155) : const Color(0xffE2EAF4),
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.06),
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
                          MaterialPageRoute(builder: (context) => const Cartscreen()),
                        );
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
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
                              color: (isDark ? const Color(0xff0284C7) : const Color(0xff19335A))
                                  .withValues(alpha: 0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.shopping_cart_checkout_rounded, color: Colors.white, size: 17),
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
}
