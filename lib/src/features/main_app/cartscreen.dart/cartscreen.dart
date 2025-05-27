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
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'dart:convert';
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

  final uuid = Uuid().v4();

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

    String aslitaarikh = '${day}/${month}/${year}';

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

  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');

  QRViewController? controller;

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      if (scanData.code != null) {
        setState(() {
          Map<String, dynamic> scannedData = jsonDecode(scanData.code!);

          Memberid.text = scannedData['member_id'] ?? '';
          Name.text = scannedData['name'] ?? '';
          Class.text = scannedData['division'] ?? '';
          PhoneNumber.text = scannedData['phone_number'] ?? '';
        });
      }

      controller.pauseCamera();
      Navigator.of(context).pop();
    });
  }

  void _scanQRCode() {
    controller?.resumeCamera();
  }

  @override
  void initState() {
    super.initState();
    print('Return Transaction ID: ${componentcontroller.transactionid.value}');
  }

  @override
  Widget build(BuildContext context) {
    final ComponentController componentcontroller =
        Get.put(ComponentController());
    return Scaffold(
        appBar: AppBar(
          backgroundColor: Color(0xffC5E3FF),
          elevation: 0,
          leading: IconButton(
            icon:
                Icon(Icons.menu, color: Colors.black87), // Hamburger menu icon
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
          title: Text(
            'ISA-VESIT',
            style: GoogleFonts.montserrat(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: SingleChildScrollView(
          child: Container(
            width: MediaQuery.of(context).size.width * 1,
            decoration: BoxDecoration(
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
            child: Padding(
              padding: const EdgeInsets.only(top: 15, left: 30),
              child: Container(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Member ID:",
                      style: GoogleFonts.lato(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color.fromARGB(255, 3, 38, 66)),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Padding(
                              padding: const EdgeInsets.only(right: 40),
                              child: TextField(
                                style: const TextStyle(color: Colors.black),
                                controller: Memberid,
                                decoration: InputDecoration(
                                    hintText: "Enter Member ID",
                                    suffixIcon: IconButton(
                                        onPressed: () {
                                          _scanQRCode();
                                          showDialog(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                    content: Container(
                                                      height: 300,
                                                      width: 300,
                                                      child: QRView(
                                                          key: qrKey,
                                                          onQRViewCreated:
                                                              _onQRViewCreated),
                                                    ),
                                                  ));
                                        },
                                        icon:
                                            const Icon(Icons.qr_code_scanner))),
                              )),
                        ),
                      ],
                    ),
                    SizedBox(
                      height: 20,
                    ),
                    Text(
                      "Name:",
                      style: GoogleFonts.lato(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color.fromARGB(255, 3, 38, 66)),
                    ),
                    Padding(
                        padding: const EdgeInsets.only(right: 30),
                        child: TextField(
                          style: const TextStyle(
                            color: Colors.black,
                          ),
                          controller: Name,
                          decoration: InputDecoration(
                            hintText: "Enter Name",
                          ),
                        )),
                    SizedBox(
                      height: 20,
                    ),
                    Text(
                      "Class/Div",
                      style: GoogleFonts.lato(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color.fromARGB(255, 3, 38, 66)),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 30),
                      child: TextField(
                        style: const TextStyle(
                          color: Colors.black,
                        ),
                        controller: Class,
                        decoration: InputDecoration(
                          hintText: "Enter Class",
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 20,
                    ),
                    Text(
                      "Phone Number:",
                      style: GoogleFonts.lato(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color.fromARGB(255, 3, 38, 66)),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 30),
                      child: TextField(
                        controller: PhoneNumber,
                        style: const TextStyle(
                          color: Colors.black,
                        ),
                        decoration: InputDecoration(
                          hintText: "Enter Phone no.",
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 20,
                    ),
                    Text(
                      "Component List:",
                      style: GoogleFonts.lato(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color.fromARGB(255, 3, 38, 66)),
                    ),
                    SizedBox(
                      height: 10,
                    ),
                    Container(
                      width: MediaQuery.of(context).size.width * 0.9,
                      height: MediaQuery.of(context).size.height * 0.27,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black),
                      ),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  Container(
                                    width: 131,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: Colors
                                          .transparent, // Transparent background
                                      border: Border.all(
                                        color: Colors.black, // Border color
                                        width: 1,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        "SkuId",
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 140,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: Colors
                                          .transparent, // Transparent background
                                      border: Border.all(
                                        color: Colors.black, // Border color
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      "Component Name",
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 80,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: Colors
                                          .transparent, // Transparent background
                                      border: Border.all(
                                        color: Colors.black, // Border color
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      "Quantity",
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          ListView.builder(
                              shrinkWrap: true, // Add this
                              physics: NeverScrollableScrollPhysics(),
                              itemCount:
                                  componentcontroller.Cartcomponents.length,
                              itemBuilder: (ctx, index) {
                                final component =
                                    componentcontroller.Cartcomponents[index];
                                return Padding(
                                  padding: const EdgeInsets.only(top: 5),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 131,
                                        height: 20,
                                        child: Text(
                                          component.skuid,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        width: 140,
                                        height: 20,
                                        child: Text(
                                          component.compname,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        width: 80,
                                        height: 20,
                                        child: Center(
                                          child: Text(
                                            component.Quantity.toString(),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              })
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 10,
                    ),
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () async {
                              setState(() {
                                _isLoading = true;
                              });
                              try {
                                if (componentcontroller.returnorissue.value ==
                                    false) {
                                  await insertCartComponents(
                                      Memberid.text,
                                      Name.text,
                                      Class.text,
                                      PhoneNumber.text,
                                      componentcontroller.Cartcomponents);

                                  for (var item
                                      in componentcontroller.Cartcomponents) {
                                    await updateQuantity(item);
                                  }
                                } else {
                                  for (var item
                                      in componentcontroller.Cartcomponents) {
                                    await returnQuantity(item);
                                  }
                                }
                                DateTime issueDate = DateTime.now();
                                DateTime scheduledDate =
                                    issueDate.add(const Duration(days: 14));

                                String scheduledDateString =
                                    DateFormat('yyyy-MM-dd HH:mm:ss')
                                        .format(scheduledDate);
                                scheduleNotification(scheduledDate);
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => Thankyou()));
                              } catch (e) {
                                print('Error during checkout: $e');
                                setState(() {
                                  _isLoading = false;
                                });
                              }
                            },
                      child: Container(
                        width: 300,
                        decoration: BoxDecoration(
                          color: _isLoading ? Colors.grey : Color(0xff19335A),
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12),
                        alignment: Alignment.center,
                        child: _isLoading
                            ? CircularProgressIndicator(color: Colors.white)
                            : Text(
                                'Checkout',
                                style: GoogleFonts.lato(
                                  textStyle: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ));
  }
}
