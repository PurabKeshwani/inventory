import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inventory/src/data/Cartcomponent.dart';
import 'package:inventory/src/data/model.dart';
import 'package:inventory/src/features/authentication/controllers/componentController.dart';
import 'package:inventory/src/features/main_app/components_in_class_screen/component_in_class_screen.dart';
import 'package:inventory/src/features/main_app/dashboard/classes_widget.dart';
import 'package:inventory/src/utils/theme/theme.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final supabase = Supabase.instance.client;
  final MobileScannerController _scannerController = MobileScannerController();

  final List<String> _categoryTables = [
    'Microcontroller',
    'Communication Modules',
    'Sensors',
    'Displays and Indicators',
    'Actuators and Motors',
    'Power Components',
    'Others',
  ];

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _openBarcodeIdentifier() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final isDark = CAppTheme.isDark(context);
        final primaryText = CAppTheme.primaryTextColor(context);
        final accentColor = isDark ? const Color(0xff38BDF8) : const Color(0xff19335A);

        return AlertDialog(
          backgroundColor: isDark ? const Color(0xff0F172A) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: isDark ? const Color(0xff334155) : Colors.transparent),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.qr_code_scanner_rounded, color: accentColor, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Identify Component',
                    style: GoogleFonts.montserrat(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: primaryText,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(dialogContext),
              ),
            ],
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Scan any component barcode or QR sticker to identify its name, category, box location, and stock.',
                style: GoogleFonts.lato(
                  fontSize: 12.5,
                  color: isDark ? const Color(0xff94A3B8) : Colors.grey[700],
                ),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 280,
                  width: 280,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      MobileScanner(
                        controller: _scannerController,
                        onDetect: (capture) {
                          final List<Barcode> barcodes = capture.barcodes;
                          for (final barcode in barcodes) {
                            if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
                              _scannerController.stop();
                              Navigator.pop(dialogContext);
                              _handleIdentifiedCode(barcode.rawValue!);
                              break;
                            }
                          }
                        },
                      ),
                      // Scanner Overlay Box
                      Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xff38BDF8),
                            width: 2.5,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: ValueListenableBuilder(
                      valueListenable: _scannerController.torchState,
                      builder: (context, state, child) {
                        return Icon(
                          state == TorchState.on ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                          color: accentColor,
                        );
                      },
                    ),
                    onPressed: () => _scannerController.toggleTorch(),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Toggle Flashlight',
                    style: GoogleFonts.lato(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xff94A3B8) : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleIdentifiedCode(String rawCode) async {
    // Show Loading Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: CAppTheme.isDark(context) ? const Color(0xff1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(strokeWidth: 3),
              const SizedBox(width: 16),
              Text(
                'Identifying component...',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: CAppTheme.primaryTextColor(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    String targetSku = rawCode.trim();

    // Check if JSON
    try {
      final decoded = jsonDecode(rawCode);
      if (decoded is Map<String, dynamic>) {
        targetSku = (decoded['skuid'] ?? decoded['sku'] ?? decoded['name'] ?? rawCode).toString().trim();
      }
    } catch (_) {}

    Map<String, dynamic>? foundComponent;
    String? foundCategory;

    // Search across categories in Supabase
    try {
      for (final category in _categoryTables) {
        final response = await supabase
            .from(category)
            .select()
            .or('skuid.eq.$targetSku,compname.ilike.%$targetSku%');

        if (response.isNotEmpty) {
          foundComponent = response.first;
          foundCategory = category;
          break;
        }
      }

      // Also try prefix matching if exact not found
      if (foundComponent == null) {
        final prefix = targetSku.split('-').first.trim();
        if (prefix.isNotEmpty && prefix.length >= 2) {
          for (final category in _categoryTables) {
            final response = await supabase
                .from(category)
                .select()
                .ilike('skuid', '$prefix%');

            if (response.isNotEmpty) {
              foundComponent = response.first;
              foundCategory = category;
              break;
            }
          }
        }
      }
    } catch (_) {}

    if (mounted) {
      Navigator.pop(context); // Dismiss loading

      if (foundComponent != null && foundCategory != null) {
        _showComponentDetailsModal(foundComponent, foundCategory, targetSku);
      } else {
        _showNotFoundDialog(targetSku);
      }
    }
  }

  void _showComponentDetailsModal(Map<String, dynamic> data, String category, String scannedSku) {
    final isDark = CAppTheme.isDark(context);
    final primaryText = CAppTheme.primaryTextColor(context);
    final secondaryText = CAppTheme.secondaryTextColor(context);
    final accentColor = isDark ? const Color(0xff38BDF8) : const Color(0xff19335A);

    final compName = (data['compname'] ?? data['name'] ?? 'Unknown Component').toString();
    final skuId = (data['skuid'] ?? scannedSku).toString();
    final boxNo = (data['boxno'] ?? data['boxNo'] ?? '—').toString();
    final stock = int.tryParse((data['quantity'] ?? data['stock'] ?? '0').toString()) ?? 0;
    final warning = (data['warning'] ?? data['notes'] ?? '').toString();
    final isAvailable = stock > 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xff0F172A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: isDark ? const Color(0xff334155) : Colors.transparent,
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xff334155) : Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),

              // Header: Identified Pill + Close
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xff38BDF8).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xff38BDF8).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xff38BDF8)),
                        const SizedBox(width: 5),
                        Text(
                          'COMPONENT IDENTIFIED',
                          style: GoogleFonts.montserrat(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xff38BDF8),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Component Title & Category
              Text(
                compName,
                style: GoogleFonts.montserrat(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: primaryText,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.category_rounded, size: 14, color: secondaryText),
                  const SizedBox(width: 6),
                  Text(
                    category,
                    style: GoogleFonts.lato(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Info Tiles Grid
              Row(
                children: [
                  // SKU Tile
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xff1E293B) : const Color(0xffF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0xff334155) : const Color(0xffE2EAF4),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('SKU ID', style: GoogleFonts.lato(fontSize: 11, color: secondaryText)),
                          const SizedBox(height: 3),
                          Text(
                            skuId,
                            style: GoogleFonts.sourceCodePro(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: primaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Box Location
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xff1E293B) : const Color(0xffF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0xff334155) : const Color(0xffE2EAF4),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Storage Box', style: GoogleFonts.lato(fontSize: 11, color: secondaryText)),
                          const SizedBox(height: 3),
                          Text(
                            boxNo,
                            style: GoogleFonts.montserrat(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: primaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Stock Status Banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isAvailable
                      ? (isDark ? Colors.green.withValues(alpha: 0.15) : Colors.green[50])
                      : (isDark ? Colors.red.withValues(alpha: 0.15) : Colors.red[50]),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isAvailable
                        ? (isDark ? Colors.green.withValues(alpha: 0.3) : Colors.green)
                        : (isDark ? Colors.red.withValues(alpha: 0.3) : Colors.red),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isAvailable ? Icons.check_circle_rounded : Icons.cancel_rounded,
                          color: isAvailable ? (isDark ? const Color(0xff4ADE80) : Colors.green[700]) : Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isAvailable ? 'In Stock & Available' : 'Out of Stock / Issued',
                              style: GoogleFonts.montserrat(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isAvailable ? (isDark ? const Color(0xff4ADE80) : Colors.green[800]) : Colors.red[800],
                              ),
                            ),
                            Text(
                              isAvailable ? '$stock units ready in lab' : 'All units currently issued',
                              style: GoogleFonts.lato(
                                fontSize: 11.5,
                                color: isDark ? const Color(0xff94A3B8) : Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Text(
                      '$stock',
                      style: GoogleFonts.montserrat(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isAvailable ? (isDark ? const Color(0xff4ADE80) : Colors.green[800]) : Colors.red[800],
                      ),
                    ),
                  ],
                ),
              ),

              if (warning.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: isDark ? 0.15 : 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.withValues(alpha: isDark ? 0.3 : 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          warning,
                          style: GoogleFonts.lato(
                            fontSize: 12,
                            color: isDark ? const Color(0xffFDBA74) : Colors.orange[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  // Add to Cart
                  if (isAvailable) ...[
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
                            foregroundColor: isDark ? const Color(0xff080E1A) : Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                          label: Text(
                            'Add to Cart',
                            style: GoogleFonts.montserrat(fontSize: 13.5, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            final compCtrl = Get.find<ComponentController>();
                            compCtrl.Cartcomponents.add(
                              Cartcomponent(
                                compname: compName,
                                skuid: skuId,
                                Quantity: 1,
                              ),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('$compName added to cart!'),
                                backgroundColor: const Color(0xff15803D),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],

                  // Scan Another Button
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: accentColor),
                          foregroundColor: accentColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                        label: Text(
                          'Scan Next',
                          style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _openBarcodeIdentifier();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNotFoundDialog(String scannedSku) {
    final isDark = CAppTheme.isDark(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xff0F172A) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: isDark ? const Color(0xff334155) : Colors.transparent),
        ),
        title: Row(
          children: [
            const Icon(Icons.help_outline_rounded, color: Colors.orange, size: 24),
            const SizedBox(width: 8),
            Text(
              'Unrecognized Code',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: CAppTheme.primaryTextColor(context),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No component in the 7 categories matched the scanned code:',
              style: GoogleFonts.lato(fontSize: 13, color: CAppTheme.secondaryTextColor(context)),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xff1E293B) : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                scannedSku,
                style: GoogleFonts.sourceCodePro(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: CAppTheme.primaryTextColor(context),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? const Color(0xff38BDF8) : const Color(0xff19335A),
              foregroundColor: isDark ? const Color(0xff080E1A) : Colors.white,
            ),
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
            label: const Text('Try Again'),
            onPressed: () {
              Navigator.pop(ctx);
              _openBarcodeIdentifier();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CAppTheme.isDark(context);
    final accentColor = isDark ? const Color(0xff38BDF8) : const Color(0xff19335A);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: accentColor,
        foregroundColor: isDark ? const Color(0xff080E1A) : Colors.white,
        icon: const Icon(Icons.qr_code_scanner_rounded),
        label: Text(
          'Identify Barcode',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
        ),
        onPressed: _openBarcodeIdentifier,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: CAppTheme.bgGradient(context),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Lab Header Banner with Quick Scan Trigger
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? const [Color(0xff0F172A), Color(0xff1E293B)]
                        : const [Color(0xff19335A), Color(0xff2A4E80)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xff38BDF8).withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.15),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withOpacity(0.4)
                          : const Color(0xff19335A).withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xff38BDF8).withValues(alpha: 0.15)
                                : Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.inventory_2_rounded,
                            color: isDark ? const Color(0xff38BDF8) : Colors.white,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ISA Hardware Inventory',
                                style: GoogleFonts.montserrat(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '7 Categories • Live lab components database',
                                style: GoogleFonts.lato(
                                  color: isDark ? const Color(0xff94A3B8) : Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Quick Identify Barcode Button
                    InkWell(
                      onTap: _openBarcodeIdentifier,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xff38BDF8).withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xff38BDF8).withValues(alpha: 0.35)
                                : Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.qr_code_scanner_rounded,
                              color: isDark ? const Color(0xff38BDF8) : Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Quick Scan to Identify Any Component',
                              style: GoogleFonts.montserrat(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark ? const Color(0xff38BDF8) : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Hardware Categories',
                      style: GoogleFonts.montserrat(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: CAppTheme.primaryTextColor(context),
                      ),
                    ),
                    Text(
                      'Live Stock',
                      style: GoogleFonts.lato(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: CAppTheme.secondaryTextColor(context),
                      ),
                    ),
                  ],
                ),
              ),

              // Category Card Items
              const ClassContainer(label: "Microcontroller"),
              const ClassContainer(label: "Communication Modules"),
              const ClassContainer(label: "Sensors"),
              const ClassContainer(label: "Displays and Indicators"),
              const ClassContainer(label: "Actuators and Motors"),
              const ClassContainer(label: "Power Components"),
              const ClassContainer(label: "Others"),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}
