import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:inventory/src/data/cartcomponent.dart';
import 'package:inventory/src/features/authentication/controllers/componentController.dart';
import 'package:inventory/src/features/authentication/controllers/emailcontroller.dart';
import 'package:inventory/src/features/authentication/controllers/thankyoucontroller.dart';
import 'package:inventory/src/features/main_app/thankyou.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:uuid/uuid.dart';

class Cartscreen extends StatefulWidget {
  const Cartscreen({super.key});

  @override
  State<Cartscreen> createState() => _CartscreenState();
}

class _CartscreenState extends State<Cartscreen> {
  final supabase = Supabase.instance.client;
  final TextEditingController Memberid = TextEditingController();
  TextEditingController Name = TextEditingController();
  final TextEditingController PhoneNumber = TextEditingController();
  final TextEditingController Class = TextEditingController();
  bool _isLoading = false;

  final ComponentController componentcontroller =
      Get.put(ComponentController());

  final Emailcontroller emailcontroller = Get.put(Emailcontroller());

  final Thankyoucontroller thankyoucontroller = Get.put(Thankyoucontroller());

  var day;

  var month;

  final uuid = const Uuid().v4();

  Future<void> updateQuantity(Cartcomponent component) async {
    componentcontroller.skuidanalyze(component.skuid);
    final tablestock = await supabase
        .from(componentcontroller.ClassName.value)
        .select('stock')
        .eq('skuid', component.skuid);
    final stockvalue = tablestock[0]['stock'] as int;
    final finalstock = stockvalue - component.Quantity;

    await supabase
        .from(componentcontroller.ClassName.value)
        .update({'stock': finalstock}).eq('skuid', component.skuid);
  }

  void scheduleNotification(DateTime scheduledDate) async {
    final response = await http.post(
      Uri.parse('https://onesignal.com/api/v1/notifications'),
      headers: {
        "Content-Type": "application/json; charset=UTF-8",
        "Authorization":
            "Basic ZjI3ZTcwZjEtNTU5Zi00NTYwLWJlMDEtNTUzYmE0ZWQ0MmIy"
      },
      body: jsonEncode({
        "app_id": "329b0b98-b961-4613-ae74-94e4c17dd44f",
        "included_segments": [
          "All"
        ], // You can target specific segments or use player IDs
        "contents": {"en": "Reminder: Please return the item you borrowed."},
        "send_after": scheduledDate.toIso8601String() // Scheduled date
      }),
    );

    if (response.statusCode == 200) {
      print("Notification scheduled successfully!");
    } else {
      print("Failed to schedule notification: ${response.body}");
    }
  }

  String Dateformater() {
    final taarikh = DateTime.now();
    int month = taarikh.month;
    int day = taarikh.day;
    int year = taarikh.year;

    String aslitaarikh = '$day/$month/$year';

    return aslitaarikh;
  }

  Future<void> returnQuantity(Cartcomponent component) async {
    componentcontroller.skuidanalyze(component.skuid);
    final tablestock = await supabase
        .from(componentcontroller.ClassName.value)
        .select('stock')
        .eq('skuid', component.skuid);

    if (tablestock.isEmpty) {
      print('No stock found for SKUID: ${component.skuid}');
      return;
    }

    final stockvalue = tablestock[0]['stock'] as int;
    final finalstock = stockvalue + component.Quantity;

    print('transaction id:');
    print(componentcontroller.transactionid.value);
    await supabase
        .from(componentcontroller.ClassName.value)
        .update({'stock': finalstock}).eq('skuid', component.skuid);

    await supabase.from('Transactions').update({'status': 'Returned'}).eq(
        'transaction_id', componentcontroller.transactionid.value);

    await supabase.from('Transactions').update({
      'returndate': Dateformater(),
    }).eq('transaction_id', componentcontroller.transactionid.value);

    thankyoucontroller.ThankyouStatus.value =
        'Successfully returned and re-added to the Inventory';
  }

  Future<void> insertCartComponents(
      String memberid,
      String name,
      String className,
      String phonenumber,
      List<Cartcomponent> cartcomponents) async {
    List<Map<String, dynamic>> cartcomponentsJson =
        cartcomponents.map((co) => co.toJson()).toList();

    final data = {
      'id': memberid,
      'name': name,
      'class': className,
      'phonenumber': phonenumber,
      'package': cartcomponentsJson,
      'issuedby': emailcontroller.Namefrommail.value,
      'status': componentcontroller.returnorissue.value ? 'Returned' : 'Issued',
      'issuedate': Dateformater(),
      'returndate':
          componentcontroller.returnorissue.value ? Dateformater() : 'soon',
      'transaction_id': uuid
    };

    try {
      await supabase.from('Transactions').insert(data);
    } catch (e) {
      print('Error inserting/updating record: $e');
    }
  }

  // Future<void> getDetails(String id) async {
  //   final details =
  //       await supabase.from('Members').select().eq('ISA Login ID', id);

  //   Name.text = details.first['Name'] as String;
  //   Class.text = details.first['Division'] as String;
  // }

  final MobileScannerController scannerController = MobileScannerController();

  void _scanQRCode() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: SizedBox(
          height: 300,
          width: 300,
          child: MobileScanner(
            controller: scannerController,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  try {
                    Map<String, dynamic> scannedData =
                        jsonDecode(barcode.rawValue!);
                    setState(() {
                      Memberid.text = scannedData['member_id'] ?? '';
                      Name.text = scannedData['name'] ?? '';
                      Class.text = scannedData['division'] ?? '';
                      PhoneNumber.text = scannedData['phone_number'] ?? '';
                    });
                    scannerController.stop();
                    Navigator.of(context).pop();
                  } catch (e) {
                    print('Error parsing QR code data: $e');
                  }
                }
              }
            },
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    print('Return Transaction ID: ${componentcontroller.transactionid.value}');
  }

  @override
  void dispose() {
    scannerController.dispose();
    super.dispose();
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String hintText,
    Widget? suffixIcon,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.lato(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xff19335A),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.black87),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: Colors.grey[500]),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xff19335A), width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildComponentTable() {
    if (componentcontroller.Cartcomponents.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No components added',
              style: GoogleFonts.lato(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            decoration: const BoxDecoration(
              color: Color(0xff19335A),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Table(
              children: [
                TableRow(
                  children: [
                    _buildTableHeaderCell('SKU ID'),
                    _buildTableHeaderCell('Component'),
                    _buildTableHeaderCell('Qty'),
                  ],
                ),
              ],
            ),
          ),
          // Table Body
          ...componentcontroller.Cartcomponents.asMap().entries.map((entry) {
            final index = entry.key;
            final component = entry.value;
            final isEven = index % 2 == 0;

            return Container(
              color: isEven ? Colors.grey[50] : Colors.white,
              child: Table(
                children: [
                  TableRow(
                    children: [
                      _buildTableCell(component.skuid),
                      _buildTableCell(component.compname),
                      _buildTableCell(component.Quantity.toString(),
                          isCenter: true),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTableHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
      child: Text(
        text,
        style: GoogleFonts.lato(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildTableCell(String text, {bool isCenter = true}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 12, 2, 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: Colors.black87,
        ),
        textAlign: isCenter ? TextAlign.center : TextAlign.left,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Future<void> _handleCheckout() async {
    setState(() {
      _isLoading = true;
    });
    try {
      if (componentcontroller.returnorissue.value == false) {
        await insertCartComponents(
          Memberid.text,
          Name.text,
          Class.text,
          PhoneNumber.text,
          componentcontroller.Cartcomponents,
        );

        for (var item in componentcontroller.Cartcomponents) {
          await updateQuantity(item);
        }
      } else {
        for (var item in componentcontroller.Cartcomponents) {
          await returnQuantity(item);
        }
      }
      DateTime issueDate = DateTime.now();
      DateTime scheduledDate = issueDate.add(const Duration(days: 14));

      String scheduledDateString =
          DateFormat('yyyy-MM-dd HH:mm:ss').format(scheduledDate);
      scheduleNotification(scheduledDate);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => Thankyou()),
      );
    } catch (e) {
      print('Error during checkout: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ComponentController componentcontroller =
        Get.put(ComponentController());
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xff19335A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          'Cart',
          style: GoogleFonts.montserrat(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xffF8FBFF),
              Color(0xffE8F4FD),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Member Information Card
              Card(
                color: Colors.white,
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Member Information",
                        style: GoogleFonts.lato(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xff19335A),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildInputField(
                        label: "Member ID",
                        controller: Memberid,
                        hintText: "Enter Member ID",
                        suffixIcon: IconButton(
                          onPressed: _scanQRCode,
                          icon: const Icon(Icons.qr_code_scanner,
                              color: Color(0xff19335A)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildInputField(
                        label: "Name",
                        controller: Name,
                        hintText: "Enter Name",
                      ),
                      const SizedBox(height: 16),
                      _buildInputField(
                        label: "Class/Division",
                        controller: Class,
                        hintText: "Enter Class",
                      ),
                      const SizedBox(height: 16),
                      _buildInputField(
                        label: "Phone Number",
                        controller: PhoneNumber,
                        hintText: "Enter Phone Number",
                        keyboardType: TextInputType.phone,
                      ),
                    ],
                  ),
                ),
              ),

              // Component List Card
              Card(
                color: Colors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Component List",
                        style: GoogleFonts.lato(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xff19335A),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildComponentTable(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Checkout Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleCheckout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isLoading ? Colors.grey : const Color(0xff19335A),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'Checkout',
                          style: GoogleFonts.lato(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
