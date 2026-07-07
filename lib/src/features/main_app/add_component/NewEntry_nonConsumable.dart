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
  final _formKey = GlobalKey<FormState>();
  final TextEditingController barcodecontroller = TextEditingController();
  final ComponentController componentcontroller =
      Get.put(ComponentController());
  final supabase = Supabase.instance.client;
  final TextEditingController boxnocontroller = TextEditingController();
  final TextEditingController stockcontroller = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    // Add listener to barcode controller for manual input
    barcodecontroller.addListener(() {
      if (barcodecontroller.text.isNotEmpty) {
        // Debounce the analysis to avoid too many calls while typing
        Future.delayed(const Duration(milliseconds: 500), () {
          if (barcodecontroller.text.isNotEmpty) {
            componentcontroller.skuidanalyze(barcodecontroller.text);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    barcodecontroller.dispose();
    stockcontroller.dispose();
    super.dispose();
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

      // Show loading indicator while analyzing SKU
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 16),
                Text('Analyzing barcode...'),
              ],
            ),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // Use async version to ensure component data is loaded
      await componentcontroller.skuidanalyze(scanResult);

      // Update stock controller with the quantity from database if available
      if (componentcontroller.Quantity.value > 0) {
        setState(() {
          stockcontroller.text = componentcontroller.Quantity.value.toString();
        });
      }

      if (mounted) {
        // Clear any existing snackbars
        ScaffoldMessenger.of(context).clearSnackBars();

        String message = 'Barcode scanned successfully';
        Color backgroundColor = Colors.green;

        // Check if there was an error loading microcontroller data
        if (componentcontroller.microcontrollerError.value.isNotEmpty) {
          message =
              'Barcode scanned, but database error: ${componentcontroller.microcontrollerError.value}';
          backgroundColor = Colors.orange;
        } else if (componentcontroller.CompName.value.isEmpty) {
          message = 'Barcode scanned, but component not recognized';
          backgroundColor = Colors.orange;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: backgroundColor,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('DEBUG: Error processing barcode: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
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
    // Prevent multiple taps
    if (_isLoading) return;

    try {
      print("Add Component button pressed");

      // Validate form
      if (!_formKey.currentState!.validate()) {
        return;
      }

      // Check if required fields are filled
      if (barcodecontroller.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter or scan a SKU ID'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      if (componentcontroller.CompName.value.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Component name is required. Please scan a valid SKU ID or enter manually.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      // Set loading state
      setState(() {
        _isLoading = true;
      });

      // Validate stock value
      int stockValue = int.tryParse(stockcontroller.text) ?? 0;
      print("Parsed stock value: $stockValue");

      // Check if SKU ID already exists
      bool skuExists = await _checkSkuExists(barcodecontroller.text);
      if (skuExists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
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
        'boxno': componentcontroller.boxnocontroller.text,
        'stock': stockcontroller.text
      });

      print("Data inserted successfully");

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
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
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      // Reset loading state
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 191, 230, 249),
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(children: [
            const SizedBox(height: 40),
            TextButton(
              onPressed: _startBarcodeScan,
              child: Container(
                width: 300,
                decoration: const BoxDecoration(
                  color: Color(0xff19335A),
                  borderRadius: BorderRadius.all(Radius.circular(8)),
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
                child: TextFormField(
                  controller: barcodecontroller,
                  maxLines: 6,
                  minLines: 1,
                  style: const TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    label: Text(
                      "SKU ID",
                      style: GoogleFonts.lato(
                        textStyle: const TextStyle(
                            color: Color.fromARGB(255, 136, 136, 136)),
                      ),
                    ),
                    suffixIcon: barcodecontroller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              barcodecontroller.clear();
                              componentcontroller.reset();
                              stockcontroller.clear();
                            },
                          )
                        : null,
                    helperText: "Scan barcode or enter SKU ID manually",
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter or scan a SKU ID';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    setState(
                        () {}); // Trigger rebuild to show/hide clear button
                  },
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
                  style: const TextStyle(color: Color.fromARGB(255, 5, 5, 5)),
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    label: Text(
                      "Name",
                      style: GoogleFonts.lato(
                        textStyle: const TextStyle(
                            color: Color.fromARGB(255, 129, 128, 128)),
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
                  border: Border.all(color: const Color.fromARGB(255, 4, 13, 56)),
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                ),
                child: TextFormField(
                  controller: componentcontroller.boxnocontroller,
                  maxLines: 6,
                  minLines: 1,
                  style: const TextStyle(color: Color.fromARGB(255, 4, 13, 56)),
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    label: Text(
                      "Box No.",
                      style: GoogleFonts.lato(
                        textStyle: const TextStyle(
                            color: Color.fromARGB(255, 129, 128, 128)),
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
                  border: Border.all(color: const Color.fromARGB(255, 4, 13, 56)),
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                ),
                child: TextFormField(
                  controller: stockcontroller,
                  maxLines: 6,
                  minLines: 1,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  style: const TextStyle(color: Color.fromARGB(255, 4, 13, 56)),
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    label: Text(
                      "Stock",
                      style: GoogleFonts.lato(
                        textStyle: const TextStyle(
                            color: Color.fromARGB(255, 129, 128, 128)),
                      ),
                    ),
                    helperText: "Enter the number of items in stock",
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter stock quantity';
                    }
                    final stock = int.tryParse(value);
                    if (stock == null || stock < 0) {
                      return 'Please enter a valid positive number';
                    }
                    return null;
                  },
                ),
              ),
            ),
            TextButton(
              onPressed: _isLoading ? null : _addComponent,
              child: Container(
                width: 300,
                decoration: BoxDecoration(
                  color: _isLoading ? Colors.grey : const Color(0xff19335A),
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                child: _isLoading
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Adding...',
                            style: GoogleFonts.lato(
                              textStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Text(
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
          ]),
        ),
      ),
    );
  }
}
