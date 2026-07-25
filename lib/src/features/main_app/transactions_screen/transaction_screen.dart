import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inventory/src/data/cartcomponent.dart';
import 'package:inventory/src/features/authentication/controllers/componentController.dart';
import 'package:inventory/src/features/main_app/cartscreen/cartscreen.dart';
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
      Get.put(ComponentController());

  final transactionidcontroller = TextEditingController();
  final returnTransactionIdController = TextEditingController();

  Future<bool> checkStockAvailability(String skuid) async {
    try {
      print('Checking stock in table: ${componentcontroller.ClassName.value}');
      print('Checking for SKUID: $skuid');

      if (componentcontroller.ClassName.value.isEmpty) {
        print('Table name is not set!');
        return false;
      }

      final response = await Supabase.instance.client
          .from(componentcontroller.ClassName.value)
          .select()
          .eq('skuid', skuid)
          .maybeSingle();

      print('Full response from Supabase: $response');

      if (response != null) {
        var stockValue = response['stock'];
        print('Raw stock value: $stockValue');

        int currentStock = 0;

        if (stockValue != null) {
          if (stockValue is String) {
            currentStock = int.parse(stockValue);
          } else if (stockValue is num) {
            currentStock = stockValue.toInt();
          }
        }

        print('Parsed stock value: $currentStock');
        return currentStock > 0;
      } else {
        print('No stock found for SKUID: $skuid');
        return false;
      }
    } catch (e) {
      print('Error checking stock: $e');
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

      // Parse the package JSON array
      List<dynamic> components = response['package'];

      // Add each component to the cart
      for (var comp in components) {
        componentcontroller.Cartcomponents.add(Cartcomponent(
          compname: comp['compname'],
          skuid: comp['skuid'],
          Quantity: comp['Quantity'],
        ));
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
    print('DEBUG: Processing barcode: $sanitized');

    if (!mounted) return;

    setState(() {
      _scanBarcode = sanitized;
      barcode = sanitized;
      print('DEBUG: Updated barcode state: $barcode');
    });

    try {
      await componentcontroller.skuidanalyze(barcode);
      print(
          'DEBUG: SKUID analyzed - ClassName: ${componentcontroller.ClassName.value}');

      final hasStock = await checkStockAvailability(barcode);
      print('DEBUG: Stock check result: $hasStock');

      if (!hasStock) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
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
            SnackBar(
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
          print(
              'DEBUG: Added to cart - ${newComponent.compname} (${newComponent.skuid})');
          print(
              'DEBUG: Current cart size: ${componentcontroller.Cartcomponents.length}');
        });
      }
    } catch (e) {
      print('DEBUG: Error processing barcode: $e');
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
      print('DEBUG: Starting barcode scan');

      // Request camera permission first
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        print('DEBUG: Camera permission denied');
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

      print('DEBUG: Camera permission granted, starting scan');

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
    return Scaffold(
      body: Container(
        height: MediaQuery.of(context).size.height * 1,
        width: MediaQuery.of(context).size.width * 1,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromARGB(255, 154, 210, 255),
              Color.fromARGB(255, 213, 245, 252),
              Color.fromARGB(255, 242, 254, 255)
            ],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
        ),
        child: Column(
          children: [
            // Fixed header section
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Column(
                children: [
                  TextButton(
                    onPressed: () => _startBarcodeScan(),
                    child: Container(
                      width: 300,
                      decoration: const BoxDecoration(
                        color: Color(0xff19335A),
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      alignment: Alignment.center,
                      child: Text(
                        'Scan to issue component',
                        style: GoogleFonts.lato(
                          textStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  TextButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text('Enter Transaction ID'),
                            content: TextField(
                              controller: returnTransactionIdController,
                              decoration: const InputDecoration(
                                hintText: 'Transaction ID',
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () async {
                                  print(
                                      'Transaction ID from dialog: ${returnTransactionIdController.text}');
                                  componentcontroller.transactionid.value =
                                      returnTransactionIdController.text;
                                  print(
                                      'Transaction ID from controller: ${componentcontroller.transactionid.value}');
                                  await fetchTransactionComponents(
                                      returnTransactionIdController.text);
                                  Navigator.pop(context);
                                  returnTransactionIdController.clear();
                                },
                                child: const Text('Submit'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    child: Container(
                      width: 300,
                      decoration: const BoxDecoration(
                        color: Color(0xff19335A),
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      alignment: Alignment.center,
                      child: Text(
                        'Enter Return Transaction ID',
                        style: GoogleFonts.lato(
                          textStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Scrollable list section
            Expanded(
              child: componentcontroller.Cartcomponents.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 80,
                            color: const Color(0xff19335A).withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No components added yet',
                            style: GoogleFonts.lato(
                              textStyle: TextStyle(
                                color: const Color(0xff19335A).withValues(alpha: 0.6),
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Scan a barcode to add components to your cart',
                            style: GoogleFonts.lato(
                              textStyle: TextStyle(
                                color: const Color(0xff19335A).withValues(alpha: 0.4),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      itemCount: componentcontroller.Cartcomponents.length,
                      itemBuilder: (ctx, index) {
                        final component =
                            componentcontroller.Cartcomponents[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  // Component details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // SKU ID
                                        Text(
                                          component.skuid,
                                          style: GoogleFonts.lato(
                                            textStyle: const TextStyle(
                                              color: Color(0xff19335A),
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        // Component name
                                        Text(
                                          component.compname,
                                          style: GoogleFonts.lato(
                                            textStyle: const TextStyle(
                                              color: Colors.black87,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 8),
                                        // Quantity badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xff19335A)
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            'Qty: ${component.Quantity}',
                                            style: GoogleFonts.lato(
                                              textStyle: const TextStyle(
                                                color: Color(0xff19335A),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Delete button
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: IconButton(
                                      onPressed: () {
                                        setState(() {
                                          componentcontroller.Cartcomponents
                                              .remove(component);
                                        });
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Component removed from cart'),
                                            backgroundColor: Colors.red,
                                            duration: Duration(seconds: 2),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                      padding: const EdgeInsets.all(8),
                                      constraints: const BoxConstraints(
                                        minWidth: 36,
                                        minHeight: 36,
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
            ),
            // Fixed footer section
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Cart info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Cart Summary',
                          style: GoogleFonts.lato(
                            textStyle: const TextStyle(
                              color: Color(0xff19335A),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${componentcontroller.Cartcomponents.length} component${componentcontroller.Cartcomponents.length == 1 ? '' : 's'}',
                          style: GoogleFonts.lato(
                            textStyle: TextStyle(
                              color: const Color(0xff19335A).withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // View Cart button
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xff19335A),
                          const Color(0xff19335A).withValues(alpha: 0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xff19335A).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          print(
                              'Navigating with Transaction ID: ${componentcontroller.transactionid.value}');
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const Cartscreen()));
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.shopping_cart_outlined,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'View Cart',
                                style: GoogleFonts.lato(
                                  textStyle: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
