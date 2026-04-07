import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:inventory/src/features/authentication/controllers/emailcontroller.dart';

class SymposiumScannerScreen extends StatefulWidget {
  const SymposiumScannerScreen({super.key});

  @override
  State<SymposiumScannerScreen> createState() => _SymposiumScannerScreenState();
}

class _SymposiumScannerScreenState extends State<SymposiumScannerScreen> {
  // Replace this placeholder with the actual App Script Web App URL later
  static const String webAppUrl =
      "https://script.google.com/macros/s/AKfycbx4eDapq6o1wW2zihiz57YiSNR8IZSVO5qFXaUjOqdqRUdV9y8Bk-VDck3FTZzqhQsVOg/exec";

  bool isContinuousScan = false;
  bool isProcessing = false;
  int _progressPercent = 0;
  Timer? _progressTimer;
  Set<String> processedScanIds = {};

  Future<void> _addSymposiumTransaction(String memberId, Map<String, dynamic> memberResponse) async {
    try {
      final Emailcontroller emailcontroller = Get.put(Emailcontroller());
      final String uuid = const Uuid().v4();
      final DateTime now = DateTime.now();
      final String today = '${now.day}/${now.month}/${now.year}';
      
      String name = memberResponse['Name'] ?? 'Unknown';
      String className = memberResponse['Division'] ?? 'Unknown';
      String phoneStr = memberResponse['Phone Number'] ?? '0';
      num phoneNum = num.tryParse(phoneStr) ?? 0;

      final List<Map<String, dynamic>> funPackage = [
        {
          "compname": "🎉 Symposium All-Access Pass 🚀",
          "skuid": "SYM-PASS",
          "Quantity": 1
        }
      ];

      final Map<String, dynamic> data = {
        'id': memberId,
        'name': name,
        'class': className,
        'phonenumber': phoneNum,
        'package': funPackage,
        'issuedby': emailcontroller.Namefrommail.value,
        'status': 'Attended',
        'issuedate': today,
        'returndate': 'Forever',
        'transaction_id': uuid
      };

      await Supabase.instance.client.from('Transactions').insert(data);
    } catch (e) {
      print('Failed to insert fun transaction: $e');
    }
  }

  void _startSimulatedProgress() {
    _progressPercent = 0;
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (mounted) {
        setState(() {
          if (_progressPercent < 85) {
            _progressPercent += 5;
          } else if (_progressPercent < 95) {
            _progressPercent += 1;
          }
        });
      }
    });
  }

  void _stopSimulatedProgress() {
    _progressTimer?.cancel();
    if (mounted) {
      setState(() {
        _progressPercent = 100;
      });
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  Future<void> _processBarcode(String scanResult) async {
    if (isProcessing) return;

    String memberId = scanResult.trim();
    if (memberId.isEmpty) return;

    // Try to decode JSON if the QR code from Lumina app contains a JSON payload
    try {
      Map<String, dynamic> scannedData = jsonDecode(memberId);
      memberId = scannedData['member_id']?.toString() ?? memberId;
      memberId = memberId.trim();
    } catch (e) {
      // If it's not JSON, we'll just use the raw string.
    }

    if (isContinuousScan && processedScanIds.contains(memberId)) {
      return;
    }

    setState(() {
      isProcessing = true;
    });
    _startSimulatedProgress();

    try {
      final memberResponse = await Supabase.instance.client
          .from('Members')
          .select()
          .eq('ISA Login ID', memberId)
          .maybeSingle();

      if (memberResponse == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Member with ID $memberId not found!'),
                backgroundColor: Colors.red),
          );
        }
      } else {
        String name = memberResponse['Name'] ?? 'Unknown Member';

        if (webAppUrl == "YOUR_GOOGLE_APPS_SCRIPT_WEB_APP_URL") {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      'Simulated Attendance for $name! Add the Webhook URL.'),
                  backgroundColor: Colors.orange),
            );
          }
        } else {
          try {
            http.Response response = await http.post(
              Uri.parse(webAppUrl),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'member_id': memberId,
                'name': name,
                'timestamp': DateTime.now().toIso8601String(),
              }),
            );

            // Google Apps Script usually returns a 302 redirect.
            if (response.statusCode == 302) {
              String redirectUrl = response.headers['location'] ?? '';
              if (redirectUrl.isEmpty) {
                final match = RegExp(r'HREF="([^"]+)"', caseSensitive: false).firstMatch(response.body);
                if (match != null) {
                  redirectUrl = match.group(1) ?? '';
                  redirectUrl = redirectUrl.replaceAll('&amp;', '&');
                }
              }
              if (redirectUrl.isNotEmpty) {
                // Ensure there are no accidental spaces in the URI
                redirectUrl = redirectUrl.replaceAll(' ', '');
                response = await http.get(Uri.parse(redirectUrl));
              }
            }

            if (response.statusCode == 200 || response.statusCode == 302) {
              try {
                final Map<String, dynamic> responseBody = jsonDecode(response.body);
                
                if (responseBody['status'] == 'duplicate') {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$name is already marked present!'), backgroundColor: Colors.orange),
                    );
                  }
                } else if (responseBody['status'] == 'success') {
                  await _addSymposiumTransaction(memberId, memberResponse);
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Attendance marked for $name!'), backgroundColor: Colors.green),
                    );
                  }
                } else if (responseBody.containsKey('error')) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Sheet Error: ${responseBody['error']}'), backgroundColor: Colors.red),
                    );
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Unknown response: ${response.body}'), backgroundColor: Colors.orange),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Raw: ${response.body}'), backgroundColor: Colors.purple),
                  );
                }
              }
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(
                          'Failed to update Google Sheet. Code: ${response.statusCode}'),
                      backgroundColor: Colors.red),
                );
              }
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('Network error: $e'),
                    backgroundColor: Colors.red),
              );
            }
          }
        }

        if (isContinuousScan) {
          processedScanIds.add(memberId);
          Future.delayed(Duration(seconds: 5), () {
            if (mounted) {
              processedScanIds.remove(memberId);
            }
          });
        }

        if (!isContinuousScan && mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      _stopSimulatedProgress();
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        setState(() {
          isProcessing = false;
          _progressPercent = 0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Symposium Scanner',
          style: GoogleFonts.lato(
            textStyle: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        backgroundColor: Color(0xff19335A),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Continuous Scan Mode',
                  style: GoogleFonts.lato(
                    textStyle: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xff19335A),
                    ),
                  ),
                ),
                Switch(
                  value: isContinuousScan,
                  activeColor: Color(0xff19335A),
                  onChanged: (value) {
                    setState(() {
                      isContinuousScan = value;
                    });
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  onDetect: (capture) {
                    final List<Barcode> barcodes = capture.barcodes;
                    if (barcodes.isNotEmpty) {
                      final String? code = barcodes.first.rawValue;
                      if (code != null) {
                        _processBarcode(code);
                      }
                    }
                  },
                ),
                // Overlay for UI
                Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                // Corner markers
                Positioned(
                  top: MediaQuery.of(context).size.height * 0.2,
                  left: MediaQuery.of(context).size.width * 0.15,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                        border: Border(
                            top: BorderSide(color: Colors.white, width: 3),
                            left: BorderSide(color: Colors.white, width: 3))),
                  ),
                ),
                Positioned(
                  top: MediaQuery.of(context).size.height * 0.2,
                  right: MediaQuery.of(context).size.width * 0.15,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                        border: Border(
                            top: BorderSide(color: Colors.white, width: 3),
                            right: BorderSide(color: Colors.white, width: 3))),
                  ),
                ),
                Positioned(
                  bottom: MediaQuery.of(context).size.height * 0.2,
                  left: MediaQuery.of(context).size.width * 0.15,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                        border: Border(
                            bottom: BorderSide(color: Colors.white, width: 3),
                            left: BorderSide(color: Colors.white, width: 3))),
                  ),
                ),
                Positioned(
                  bottom: MediaQuery.of(context).size.height * 0.2,
                  right: MediaQuery.of(context).size.width * 0.15,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                        border: Border(
                            bottom: BorderSide(color: Colors.white, width: 3),
                            right: BorderSide(color: Colors.white, width: 3))),
                  ),
                ),
                if (isProcessing)
                  Center(
                    child: Container(
                      padding: EdgeInsets.all(20),
                      width: 150,
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 60,
                                height: 60,
                                child: CircularProgressIndicator(
                                  value: _progressPercent / 100,
                                  color: Colors.lightBlue,
                                  backgroundColor: Colors.white24,
                                  strokeWidth: 6,
                                ),
                              ),
                              Text(
                                '$_progressPercent%',
                                style: GoogleFonts.lato(
                                  textStyle: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 15),
                          Text('Marking...',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(20),
            color: Color(0xff19335A),
            width: double.infinity,
            child: Text(
              isContinuousScan
                  ? 'Scan QR codes one after another. Wait 5s between scanning the same QR.'
                  : 'Scan a QR code to mark attendance. It will close after one scan.',
              style: GoogleFonts.lato(
                textStyle: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
              textAlign: TextAlign.center,
            ),
          )
        ],
      ),
    );
  }
}
