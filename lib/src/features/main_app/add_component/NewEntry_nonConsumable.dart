import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inventory/src/features/authentication/controllers/componentController.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

class Newentry extends StatefulWidget {
  const Newentry({super.key});

  @override
  State<Newentry> createState() => _NewentryState();
}

class _NewentryState extends State<Newentry> {
  final TextEditingController barcodecontroller = TextEditingController();
  final ComponentController componentcontroller =
      Get.put(ComponentController());
  final supabase = Supabase.instance.client;
  final TextEditingController boxnocontroller = TextEditingController();
  final TextEditingController stockcontroller = TextEditingController();

  Future<void> _startBarcodeScan() async {
    try {
      print('DEBUG: Starting barcode scan');

      // Request camera permission first
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        print('DEBUG: Camera permission denied');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
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
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
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
                          textStyle: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.white),
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
                        margin: EdgeInsets.all(40),
                      ),
                      // Corner markers
                      Positioned(
                        top: 40,
                        left: 40,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
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
                          decoration: BoxDecoration(
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
                          decoration: BoxDecoration(
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
                          decoration: BoxDecoration(
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
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline, color: Color(0xff19335A)),
                      SizedBox(width: 8),
                      Text(
                        'Position the barcode within the frame',
                        style: GoogleFonts.lato(
                          textStyle: TextStyle(
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
            duration: Duration(seconds: 2),
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
          SnackBar(
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
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<bool> _checkSkuExists(String skuid) async {
    try {
      final response = await supabase
          .from(componentcontroller.ClassName.value)
          .select()
          .eq('skuid', skuid)
          .single();
      return response != null;
    } catch (e) {
      return false;
    }
  }

  Future<void> _addComponent() async {
    try {
      print("Add Component button pressed");

      // Validate stock value
      int stockValue = int.tryParse(stockcontroller.text) ?? 0;
      print("Parsed stock value: $stockValue");

      if (stockValue < 0) {
        print("Stock is negative, showing SnackBar");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Stock cannot be negative. Please enter a valid stock value.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      // Check if SKU ID already exists
      bool skuExists = await _checkSkuExists(barcodecontroller.text);
      if (skuExists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'A component with this SKU ID already exists. Please use a different SKU ID.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // Proceed with insertion
      print("Inserting data into the database");
      print(componentcontroller.ClassName.value);

      await supabase.from(componentcontroller.ClassName.value).insert({
        'skuid': barcodecontroller.text,
        'name': componentcontroller.CompName.value,
        'boxno': componentcontroller.Boxname.value,
        'stock': stockcontroller.text
      });

      print("Data inserted successfully");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Component added successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      print("Error inserting data: $e");
      String errorMessage = 'Error adding component';

      if (e.toString().contains('duplicate key value')) {
        errorMessage =
            'A component with this SKU ID already exists. Please use a different SKU ID.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 191, 230, 249),
      body: Column(children: [
        SizedBox(height: 40),
        TextButton(
          onPressed: _startBarcodeScan,
          child: Container(
            width: 300,
            decoration: BoxDecoration(
              color: Color(0xff19335A),
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            padding: EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            child: Text(
              'Scan the Barcode',
              style: GoogleFonts.lato(
                textStyle: TextStyle(
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
              border: Border.all(color: Color.fromARGB(255, 4, 13, 56)),
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            child: TextFormField(
              controller: barcodecontroller,
              maxLines: 6,
              minLines: 1,
              style: TextStyle(color: Colors.black),
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                label: Text(
                  "SKU ID",
                  style: GoogleFonts.lato(
                    textStyle: TextStyle(
                        color: const Color.fromARGB(255, 136, 136, 136)),
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(25.0),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Color.fromARGB(255, 4, 13, 56)),
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            child: TextField(
              controller: componentcontroller.namecontroller,
              maxLines: 6,
              minLines: 1,
              style: TextStyle(color: const Color.fromARGB(255, 5, 5, 5)),
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                label: Text(
                  "Name",
                  style: GoogleFonts.lato(
                    textStyle: TextStyle(
                        color: const Color.fromARGB(255, 129, 128, 128)),
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
                  border: Border.all(color: Color.fromARGB(255, 4, 13, 56)),
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                child: TextFormField(
                  controller: componentcontroller.boxnocontroller,
                  maxLines: 6,
                  minLines: 1,
                  style: TextStyle(color: Color.fromARGB(255, 4, 13, 56)),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    label: Text(
                      "Box No.",
                      style: GoogleFonts.lato(
                        textStyle: TextStyle(
                            color: const Color.fromARGB(255, 129, 128, 128)),
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
                  border: Border.all(color: Color.fromARGB(255, 4, 13, 56)),
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                child: TextFormField(
                  controller: stockcontroller,
                  maxLines: 6,
                  minLines: 1,
                  style: TextStyle(color: Color.fromARGB(255, 4, 13, 56)),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    label: Text(
                      "Stock",
                      style: GoogleFonts.lato(
                        textStyle: TextStyle(
                            color: const Color.fromARGB(255, 129, 128, 128)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 40),
        TextButton(
          onPressed: _addComponent,
          child: Container(
            width: 300,
            decoration: const BoxDecoration(
              color: Color(0xff19335A),
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            padding: EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            child: Text(
              'Add Component',
              style: GoogleFonts.lato(
                textStyle: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
