import 'dart:io';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/fine_model.dart';

class ReceiptPdfService {
  /// Formats receipt number nicely e.g., "0000457" or "REC-0000457"
  static String formatReceiptNumber(FineModel fine) {
    if (fine.fineId.isEmpty) return 'REC-0000101';
    // If fineId is numeric or has numbers
    final digits = fine.fineId.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isNotEmpty) {
      return digits.padLeft(7, '0');
    }
    // Hash-based fallback
    final code = fine.fineId.hashCode.abs() % 1000000;
    return code.toString().padLeft(7, '0');
  }

  /// Formats date to 'dd-MM-yyyy' or similar matching user design
  static String formatReceiptDate(FineModel fine) {
    if (fine.paidAt != null && fine.paidAt!.isNotEmpty) {
      try {
        final dt = DateTime.parse(fine.paidAt!);
        return DateFormat('dd-MM-yyyy').format(dt);
      } catch (_) {}
    }
    if (fine.createdAt != null && fine.createdAt!.isNotEmpty) {
      try {
        final dt = DateTime.parse(fine.createdAt!);
        return DateFormat('dd-MM-yyyy').format(dt);
      } catch (_) {}
    }
    return DateFormat('dd-MM-yyyy').format(DateTime.now());
  }

  /// Generates the PDF document bytes matching the provided receipt design
  static Future<Uint8List> generateReceiptPdf(FineModel fine) async {
    final pdf = pw.Document();

    // Load custom fonts for crisp rendering and currency symbols
    pw.Font fontRegular;
    pw.Font fontBold;
    try {
      fontRegular = await PdfGoogleFonts.latoRegular();
      fontBold = await PdfGoogleFonts.montserratBold();
    } catch (_) {
      fontRegular = pw.Font.helvetica();
      fontBold = pw.Font.helveticaBold();
    }

    // Try loading ISA Logo
    pw.MemoryImage? logoImage;
    try {
      final bytes = await rootBundle.load('assets/images/isa-vesit-color-logo.png');
      logoImage = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {
      try {
        final bytes = await rootBundle.load('assets/logo/ISA-Header-(LogoOnly).png');
        logoImage = pw.MemoryImage(bytes.buffer.asUint8List());
      } catch (_) {}
    }

    final receiptNo = formatReceiptNumber(fine);
    final receiptDate = formatReceiptDate(fine);
    final memberName = fine.memberName ?? fine.memberId;
    final itemDesc = fine.componentName != null && fine.componentName!.isNotEmpty
        ? 'Fine: ${fine.componentName} (${fine.reason})'
        : 'Fine: ${fine.reason}';
    final qty = fine.quantity ?? 1;
    final amount = fine.amount;
    final amountFormatted = 'Rs. ${amount.toStringAsFixed(2)}';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 36),
        theme: pw.ThemeData.withFont(
          base: fontRegular,
          bold: fontBold,
        ),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ── 1. Top Section: Company Info & Logo ──
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Company / Institution Info
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'ISA VESIT INVENTORY',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 14,
                          color: PdfColor.fromHex('#0F172A'),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'VESIT, Hashu Advani Memorial Complex,',
                        style: pw.TextStyle(
                          font: fontRegular,
                          fontSize: 10,
                          color: PdfColor.fromHex('#4A5568'),
                        ),
                      ),
                      pw.Text(
                        "Collector's Colony, Chembur, Mumbai - 400074",
                        style: pw.TextStyle(
                          font: fontRegular,
                          fontSize: 10,
                          color: PdfColor.fromHex('#4A5568'),
                        ),
                      ),
                      pw.Text(
                        'Email: isa.vesit@ves.ac.in',
                        style: pw.TextStyle(
                          font: fontRegular,
                          fontSize: 10,
                          color: PdfColor.fromHex('#4A5568'),
                        ),
                      ),
                    ],
                  ),

                  // Logo Box
                  pw.Container(
                    width: 140,
                    height: 60,
                    padding: const pw.EdgeInsets.all(6),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: pw.BorderRadius.circular(8),
                      border: pw.Border.all(
                        color: PdfColor.fromHex('#CBD5E1'),
                        width: 1,
                      ),
                    ),
                    alignment: pw.Alignment.center,
                    child: logoImage != null
                        ? pw.Image(logoImage, fit: pw.BoxFit.contain)
                        : pw.Text(
                            'ISA-VESIT',
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 14,
                              color: PdfColor.fromHex('#19335A'),
                            ),
                          ),
                  ),
                ],
              ),

              pw.SizedBox(height: 36),

              // ── 2. Middle Section: Billed To & RECEIPT Header ──
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // Billed To
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Billed To',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 11,
                          color: PdfColor.fromHex('#1A202C'),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        memberName,
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 15,
                          color: PdfColor.fromHex('#19335A'),
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Member ID: ${fine.memberId}',
                        style: pw.TextStyle(
                          font: fontRegular,
                          fontSize: 10,
                          color: PdfColor.fromHex('#4A5568'),
                        ),
                      ),
                      if (fine.className != null && fine.className!.isNotEmpty)
                        pw.Text(
                          'Class: ${fine.className}',
                          style: pw.TextStyle(
                            font: fontRegular,
                            fontSize: 10,
                            color: PdfColor.fromHex('#4A5568'),
                          ),
                        ),
                      if (fine.memberEmail != null && fine.memberEmail!.isNotEmpty)
                        pw.Text(
                          'Email: ${fine.memberEmail}',
                          style: pw.TextStyle(
                            font: fontRegular,
                            fontSize: 10,
                            color: PdfColor.fromHex('#4A5568'),
                          ),
                        ),
                    ],
                  ),

                  // RECEIPT Big Title & Info
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'RECEIPT',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 26,
                          letterSpacing: 2,
                          color: PdfColor.fromHex('#19335A'),
                        ),
                      ),
                      pw.SizedBox(height: 12),
                      pw.Row(
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          pw.Text(
                            'Receipt #  ',
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 10,
                              color: PdfColor.fromHex('#1A202C'),
                            ),
                          ),
                          pw.SizedBox(
                            width: 80,
                            child: pw.Text(
                              receiptNo,
                              textAlign: pw.TextAlign.right,
                              style: pw.TextStyle(
                                font: fontRegular,
                                fontSize: 10,
                                color: PdfColor.fromHex('#2D3748'),
                              ),
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          pw.Text(
                            'Receipt date  ',
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 10,
                              color: PdfColor.fromHex('#1A202C'),
                            ),
                          ),
                          pw.SizedBox(
                            width: 80,
                            child: pw.Text(
                              receiptDate,
                              textAlign: pw.TextAlign.right,
                              style: pw.TextStyle(
                                font: fontRegular,
                                fontSize: 10,
                                color: PdfColor.fromHex('#2D3748'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 28),

              // ── 3. Table Header & Rows ──
              // Header Row (Dark Slate / Navy)
              pw.Container(
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#19335A'),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
                ),
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: pw.Row(
                  children: [
                    pw.SizedBox(
                      width: 40,
                      child: pw.Text(
                        'QTY',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 10,
                          color: PdfColors.white,
                        ),
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        'Description',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 10,
                          color: PdfColors.white,
                        ),
                      ),
                    ),
                    pw.SizedBox(
                      width: 80,
                      child: pw.Text(
                        'Unit Price',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 10,
                          color: PdfColors.white,
                        ),
                      ),
                    ),
                    pw.SizedBox(
                      width: 80,
                      child: pw.Text(
                        'Amount',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 10,
                          color: PdfColors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Table Body Row
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.SizedBox(
                      width: 40,
                      child: pw.Text(
                        '$qty',
                        style: pw.TextStyle(font: fontRegular, fontSize: 10),
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            itemDesc,
                            style: pw.TextStyle(font: fontRegular, fontSize: 10),
                          ),
                          if (fine.transactionId != null && fine.transactionId!.isNotEmpty) ...[
                            pw.SizedBox(height: 2),
                            pw.Text(
                              'Transaction Ref: #${fine.transactionId}',
                              style: pw.TextStyle(
                                font: fontRegular,
                                fontSize: 8.5,
                                color: PdfColor.fromHex('#718096'),
                              ),
                            ),
                          ],
                          if (fine.issueDate != null || fine.returnDate != null) ...[
                            pw.SizedBox(height: 2),
                            pw.Text(
                              'Issued: ${fine.issueDate ?? "—"}  |  Returned: ${fine.returnDate ?? "—"}',
                              style: pw.TextStyle(
                                font: fontRegular,
                                fontSize: 8.5,
                                color: PdfColor.fromHex('#718096'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    pw.SizedBox(
                      width: 80,
                      child: pw.Text(
                        amount.toStringAsFixed(2),
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(font: fontRegular, fontSize: 10),
                      ),
                    ),
                    pw.SizedBox(
                      width: 80,
                      child: pw.Text(
                        amountFormatted,
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(font: fontBold, fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ),

              // Divider
              pw.Divider(color: PdfColor.fromHex('#E2E8F0'), thickness: 1),

              pw.SizedBox(height: 12),

              // ── 4. Totals Block (Right Aligned) ──
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Paid Stamp / Collection info on Left
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#F0FDF4'),
                      borderRadius: pw.BorderRadius.circular(6),
                      border: pw.Border.all(
                        color: PdfColor.fromHex('#86EFAC'),
                        width: 1,
                      ),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          children: [
                            pw.Container(
                              width: 8,
                              height: 8,
                              decoration: pw.BoxDecoration(
                                color: PdfColor.fromHex('#16A34A'),
                                shape: pw.BoxShape.circle,
                              ),
                            ),
                            pw.SizedBox(width: 6),
                            pw.Text(
                              'STATUS: PAID & SETTLED',
                              style: pw.TextStyle(
                                font: fontBold,
                                fontSize: 9.5,
                                color: PdfColor.fromHex('#166534'),
                              ),
                            ),
                          ],
                        ),
                        if (fine.paidBy != null && fine.paidBy!.isNotEmpty) ...[
                          pw.SizedBox(height: 3),
                          pw.Text(
                            'Collected by: ${fine.paidBy}',
                            style: pw.TextStyle(
                              font: fontRegular,
                              fontSize: 8.5,
                              color: PdfColor.fromHex('#166534'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Totals breakdown on Right
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      // Subtotal
                      pw.Row(
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          pw.SizedBox(
                            width: 100,
                            child: pw.Text(
                              'Subtotal',
                              textAlign: pw.TextAlign.left,
                              style: pw.TextStyle(font: fontRegular, fontSize: 10),
                            ),
                          ),
                          pw.SizedBox(
                            width: 90,
                            child: pw.Text(
                              amountFormatted,
                              textAlign: pw.TextAlign.right,
                              style: pw.TextStyle(font: fontRegular, fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 6),
                      // Tax
                      pw.Row(
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          pw.SizedBox(
                            width: 100,
                            child: pw.Text(
                              'Tax ( 0% )',
                              textAlign: pw.TextAlign.left,
                              style: pw.TextStyle(font: fontRegular, fontSize: 10),
                            ),
                          ),
                          pw.SizedBox(
                            width: 90,
                            child: pw.Text(
                              'Rs. 0.00',
                              textAlign: pw.TextAlign.right,
                              style: pw.TextStyle(font: fontRegular, fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 8),

                      // Total Row with Top border and Double bottom border
                      pw.Container(
                        width: 190,
                        padding: const pw.EdgeInsets.symmetric(vertical: 6),
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(
                            top: pw.BorderSide(color: PdfColors.black, width: 1),
                            bottom: pw.BorderSide(color: PdfColors.black, width: 2),
                          ),
                        ),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'Total (INR)',
                              style: pw.TextStyle(font: fontBold, fontSize: 11),
                            ),
                            pw.Text(
                              amountFormatted,
                              style: pw.TextStyle(font: fontBold, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              pw.Spacer(),

              // ── 5. Notes & Footer ──
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Notes',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 10,
                      color: PdfColor.fromHex('#1A202C'),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Thank you for your payment! This official computer-generated receipt confirms the settlement of inventory dues and fines. Please retain this receipt for clearance and audit purposes.',
                    style: pw.TextStyle(
                      font: fontRegular,
                      fontSize: 8.5,
                      color: PdfColor.fromHex('#4A5568'),
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'For questions or support, contact us at isa.vesit@ves.ac.in or (+91) 98765-43210.',
                    style: pw.TextStyle(
                      font: fontRegular,
                      fontSize: 8.5,
                      color: PdfColor.fromHex('#718096'),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Direct print dialog via native system printing
  static Future<void> printReceipt(FineModel fine) async {
    final pdfBytes = await generateReceiptPdf(fine);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Receipt_${formatReceiptNumber(fine)}.pdf',
    );
  }

  /// Share PDF receipt via standard share sheet
  static Future<void> shareReceipt(FineModel fine) async {
    final pdfBytes = await generateReceiptPdf(fine);
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'Receipt_${formatReceiptNumber(fine)}.pdf',
    );
  }

  /// Save PDF file to downloads / device documents
  static Future<String?> saveReceiptToFile(FineModel fine) async {
    try {
      final pdfBytes = await generateReceiptPdf(fine);
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/Receipt_${formatReceiptNumber(fine)}.pdf');
      await file.writeAsBytes(pdfBytes);
      return file.path;
    } catch (_) {
      return null;
    }
  }
}
