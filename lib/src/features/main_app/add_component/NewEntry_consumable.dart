import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inventory/src/features/authentication/controllers/componentController.dart';
import 'package:inventory/src/utils/inventory_barcode_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

class NewConsumableentry extends StatefulWidget {
  const NewConsumableentry({super.key});

  @override
  State<NewConsumableentry> createState() => _NewConsumableentryState();
}

class _NewConsumableentryState extends State<NewConsumableentry> {
  final TextEditingController barcodecontroller = TextEditingController();
  final ComponentController componentcontroller =
      Get.find<ComponentController>();
  final supabase = Supabase.instance.client;
  final TextEditingController boxnocontroller = TextEditingController();
  final TextEditingController stockcontroller = TextEditingController();
  final InventoryBarcodeScanner _scanner =
      InventoryBarcodeScanner('add consumable');
  bool _isProcessingScan = false; // prevents duplicate onDetect firings
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
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      print('DEBUG: Camera permission granted, starting scan');

      if (!mounted) return;

      _isProcessingScan = false; // reset guard for this new scan attempt

      final isDarkMode = Theme.of(context).brightness == Brightness.dark;

      _scanner.setScannerVisible(true);
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            height: 400,
            width: 350,
            decoration: BoxDecoration(
              color: isDarkMode ? Theme.of(context).cardColor : Colors.white,
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
                        controller: _scanner.controller,
                        errorBuilder: _scanner.buildError,
                        onDetect: (capture) async {
                          if (_isProcessingScan) return;
                          _scanner.logCapture(capture);
                          final List<Barcode> barcodes = capture.barcodes;
                          if (barcodes.isNotEmpty) {
                            final String? code = barcodes.first.rawValue;
                            if (code != null && code.isNotEmpty) {
                              _isProcessingScan = true;
                              print('DEBUG: Barcode detected: $code');
                              // Add haptic feedback
                              HapticFeedback.mediumImpact();
                              // Close scanner first
                              Navigator.pop(context);
                              // Process barcode after scanner is closed
                              await _processBarcode(code);
                              _isProcessingScan = false;
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
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Theme.of(context).colorScheme.surfaceVariant
                        : Colors.grey[100],
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline,
                                color: Color(0xff19335A)),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Position the barcode within the frame',
                                style: GoogleFonts.lato(
                                  textStyle: TextStyle(
                                    color: isDarkMode
                                        ? Colors.white70
                                        : const Color(0xff19335A),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Toggle flashlight',
                        onPressed: _scanner.controller.toggleTorch,
                        icon: ValueListenableBuilder(
                          valueListenable: _scanner.controller,
                          builder: (context, state, child) => Icon(
                            state.torchState == TorchState.on
                                ? Icons.flash_on
                                : Icons.flash_off,
                            color: isDarkMode
                                ? Colors.white
                                : const Color(0xff19335A),
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
      _scanner.setScannerVisible(false);
    } catch (e) {
      _scanner.setScannerVisible(false);
      print('DEBUG: Error in scanner: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accessing scanner: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _processBarcode(String scanResult) async {
    try {
      print('DEBUG: Processing barcode: $scanResult');
      if (!mounted) return;

      // Update the barcode controller
      final normalizedScan =
          ComponentController.normalizeScannedIdentifier(scanResult);
      setState(() {
        barcodecontroller.text = normalizedScan;
      });

      // Analyze the SKU ID
      _scanner.logLookup(normalizedScan);
      await componentcontroller.skuidanalyze(normalizedScan);

      if (mounted) {
        final recognized = componentcontroller.CompName.value.isNotEmpty &&
            !componentcontroller.CompName.value.startsWith('Unknown ');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              recognized
                  ? 'Barcode scanned successfully'
                  : 'Barcode scanned, but component not recognized',
            ),
            backgroundColor: recognized ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('DEBUG: Error processing barcode: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing barcode: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      _isProcessingScan = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 40),
            TextButton(
              onPressed: _startBarcodeScan,
              child: Container(
                width: 300,
                decoration: const BoxDecoration(
                  color: Color(0xff19335A),
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                child: Text(
                  'Scan the Barcode',
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
            Padding(
              padding: const EdgeInsets.all(25.0),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                      color: isDarkMode
                          ? Colors.white54
                          : const Color.fromARGB(255, 4, 13, 56)),
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                ),
                child: TextField(
                  controller: componentcontroller.namecontroller,
                  maxLines: 6,
                  minLines: 1,
                  style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    label: Text(
                      "Name",
                      style: GoogleFonts.lato(
                        textStyle: TextStyle(
                            color: isDarkMode
                                ? Colors.white70
                                : const Color.fromARGB(255, 6, 6, 6)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(
                        left: 25.0, top: 25.0, bottom: 25.0, right: 12.5),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: isDarkMode
                                ? Colors.white54
                                : const Color.fromARGB(255, 4, 13, 56)),
                        borderRadius:
                            const BorderRadius.all(Radius.circular(8)),
                      ),
                      child: TextFormField(
                        controller: componentcontroller.boxnocontroller,
                        maxLines: 6,
                        minLines: 1,
                        style: TextStyle(
                            color: isDarkMode
                                ? Colors.white
                                : const Color.fromARGB(255, 0, 0, 0)),
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          label: Text(
                            "Box No.",
                            style: GoogleFonts.lato(
                              textStyle: TextStyle(
                                  color: isDarkMode
                                      ? Colors.white70
                                      : const Color.fromARGB(255, 6, 6, 6)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(
                        right: 25.0, top: 25.0, bottom: 25.0, left: 12.5),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: isDarkMode
                                ? Colors.white54
                                : const Color.fromARGB(255, 4, 13, 56)),
                        borderRadius:
                            const BorderRadius.all(Radius.circular(8)),
                      ),
                      child: TextFormField(
                        controller: stockcontroller,
                        maxLines: 6,
                        minLines: 1,
                        style: TextStyle(
                            color: isDarkMode
                                ? Colors.white
                                : const Color.fromARGB(255, 0, 0, 0)),
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          label: Text(
                            "Stock",
                            style: GoogleFonts.lato(
                              textStyle: TextStyle(
                                  color: isDarkMode
                                      ? Colors.white70
                                      : const Color.fromARGB(255, 6, 6, 6)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            TextButton(
              onPressed: () async {
                try {
                  await supabase
                      .from(componentcontroller.ClassName.value)
                      .insert({
                    'skuid': barcodecontroller.text,
                    'stock': stockcontroller.text,
                    'name': componentcontroller.CompName.value,
                    'boxno': componentcontroller.boxnocontroller.text
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Component added successfully'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );

                  Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error adding component: $e'),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: Container(
                width: 300,
                decoration: const BoxDecoration(
                  color: Color(0xff19335A),
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                child: Text(
                  'Add Component',
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
    );
  }
}
