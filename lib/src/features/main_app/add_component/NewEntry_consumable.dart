import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inventory/src/features/authentication/controllers/componentController.dart';
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

      // Show scanner in a dialog
      showDialog(
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
                        onDetect: (capture) async {
                          final List<Barcode> barcodes = capture.barcodes;
                          if (barcodes.isNotEmpty) {
                            final String? code = barcodes.first.rawValue;
                            if (code != null && code.isNotEmpty) {
                              print('DEBUG: Barcode detected: $code');
                              // Add haptic feedback
                              HapticFeedback.mediumImpact();
                              // Close scanner first
                              Navigator.pop(context);
                              // Process barcode after scanner is closed
                              await _processBarcode(code);
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
                    color: Colors.grey[100],
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xff19335A)),
                      const SizedBox(width: 8),
                      Text(
                        'Position the barcode within the frame',
                        style: GoogleFonts.lato(
                          textStyle: const TextStyle(
                            color: Color(0xff19335A),
                            fontSize: 14,
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
    } catch (e) {
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
      setState(() {
        barcodecontroller.text = scanResult;
      });

      // Analyze the SKU ID
      componentcontroller.skuidanalyze(scanResult);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Barcode scanned successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
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
              border: Border.all(color: const Color.fromARGB(255, 4, 13, 56)),
              borderRadius: const BorderRadius.all(Radius.circular(8)),
            ),
            child: TextField(
              controller: componentcontroller.namecontroller,
              maxLines: 6,
              minLines: 1,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                label: Text(
                  "Name",
                  style: GoogleFonts.lato(
                    textStyle:
                        const TextStyle(color: Color.fromARGB(255, 141, 141, 141)),
                  ),
                ),
              ),
            ),
          ),
        ),
        Row(
          children: [
            Padding(
              padding: const EdgeInsets.all(25.0),
              child: Container(
                width: 120,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color.fromARGB(255, 4, 13, 56)),
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                ),
                child: TextFormField(
                  controller: componentcontroller.boxnocontroller,
                  maxLines: 6,
                  minLines: 1,
                  style: const TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    label: Text(
                      "Box No.",
                      style: GoogleFonts.lato(
                        textStyle:
                            const TextStyle(color: Color.fromARGB(255, 6, 6, 6)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(25.0),
              child: Container(
                width: 120,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color.fromARGB(255, 4, 13, 56)),
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                ),
                child: TextFormField(
                  controller: stockcontroller,
                  maxLines: 6,
                  minLines: 1,
                  style: const TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    label: Text(
                      "Stock",
                      style: GoogleFonts.lato(
                        textStyle:
                            const TextStyle(color: Color.fromARGB(255, 6, 6, 6)),
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
              await supabase.from(componentcontroller.ClassName.value).insert({
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
    );
  }
}
