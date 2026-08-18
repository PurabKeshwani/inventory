import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'models/fine_model.dart';
import 'services/receipt_pdf_service.dart';

class FineReceiptDialog extends StatefulWidget {
  final FineModel fine;

  const FineReceiptDialog({
    super.key,
    required this.fine,
  });

  static Future<void> show(BuildContext context, FineModel fine) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => FineReceiptDialog(fine: fine),
    );
  }

  @override
  State<FineReceiptDialog> createState() => _FineReceiptDialogState();
}

class _FineReceiptDialogState extends State<FineReceiptDialog> {
  bool _isProcessing = false;

  String get _receiptNo => ReceiptPdfService.formatReceiptNumber(widget.fine);
  String get _receiptDate => ReceiptPdfService.formatReceiptDate(widget.fine);

  Future<void> _handlePrint() async {
    setState(() => _isProcessing = true);
    try {
      await ReceiptPdfService.printReceipt(widget.fine);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleShare() async {
    setState(() => _isProcessing = true);
    try {
      await ReceiptPdfService.shareReceipt(widget.fine);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleDownload() async {
    setState(() => _isProcessing = true);
    try {
      final path = await ReceiptPdfService.saveReceiptToFile(widget.fine);
      if (mounted) {
        if (path != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Receipt PDF saved to: $path'),
              backgroundColor: Colors.green[700],
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          // Fallback to native print/save dialog
          await ReceiptPdfService.printReceipt(widget.fine);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fine = widget.fine;
    final memberName = fine.memberName ?? fine.memberId;
    final itemDesc = fine.componentName != null && fine.componentName!.isNotEmpty
        ? 'Fine: ${fine.componentName} (${fine.reason})'
        : 'Fine: ${fine.reason}';
    final qty = fine.quantity ?? 1;
    final amount = fine.amount;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 680, maxHeight: 860),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Action Header Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xff19335A),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Payment Receipt Preview',
                      style: GoogleFonts.montserrat(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (_isProcessing)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    else ...[
                      // Quick Print Button
                      IconButton(
                        icon: const Icon(Icons.print_rounded, color: Colors.white, size: 20),
                        tooltip: 'Print / Save PDF',
                        onPressed: _handlePrint,
                      ),
                      // Quick Share Button
                      IconButton(
                        icon: const Icon(Icons.share_rounded, color: Colors.white, size: 20),
                        tooltip: 'Share Receipt',
                        onPressed: _handleShare,
                      ),
                    ],
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Scrollable Receipt Document View (Paper Style)
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── 1. Top Section: Company Name / Address & Logo Box ──
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ISA VESIT INVENTORY',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xff19335A),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'VESIT, Hashu Advani Memorial Complex,',
                                    style: GoogleFonts.lato(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  Text(
                                    "Collector's Colony, Chembur, Mumbai - 400074",
                                    style: GoogleFonts.lato(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  Text(
                                    'Email: isa.vesit@ves.ac.in',
                                    style: GoogleFonts.lato(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Logo Box
                            Container(
                              width: 140,
                              height: 64,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Image.asset(
                                'assets/images/isa-vesit-color-logo.png',
                                fit: pw_fit,
                                errorBuilder: (_, __, ___) => Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.cloud_upload_outlined,
                                          size: 16, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(
                                        'ISA-VESIT',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xff19335A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 36),

                        // ── 2. Middle Section: Billed To & RECEIPT Title ──
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Billed To Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Billed To',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    memberName,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xff19335A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Member ID: ${fine.memberId}',
                                    style: GoogleFonts.lato(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  if (fine.className != null && fine.className!.isNotEmpty)
                                    Text(
                                      'Class: ${fine.className}',
                                      style: GoogleFonts.lato(
                                        fontSize: 12,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  if (fine.memberEmail != null && fine.memberEmail!.isNotEmpty)
                                    Text(
                                      'Email: ${fine.memberEmail}',
                                      style: GoogleFonts.lato(
                                        fontSize: 12,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            // RECEIPT Label & Details
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'RECEIPT',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2,
                                    color: const Color(0xff19335A),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Receipt #',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(width: 24),
                                    SizedBox(
                                      width: 80,
                                      child: Text(
                                        _receiptNo,
                                        textAlign: TextAlign.right,
                                        style: GoogleFonts.sourceCodePro(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Receipt date',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(width: 24),
                                    SizedBox(
                                      width: 80,
                                      child: Text(
                                        _receiptDate,
                                        textAlign: TextAlign.right,
                                        style: GoogleFonts.lato(
                                          fontSize: 12,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 32),

                        // ── 3. Table: QTY | Description | Unit Price | Amount ──
                        Container(
                          decoration: const BoxDecoration(
                            color: Color(0xff19335A),
                            borderRadius: BorderRadius.all(Radius.circular(4)),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 44,
                                child: Text(
                                  'QTY',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'Description',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 90,
                                child: Text(
                                  'Unit Price',
                                  textAlign: TextAlign.right,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 90,
                                child: Text(
                                  'Amount',
                                  textAlign: TextAlign.right,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Table Row Content
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 44,
                                child: Text(
                                  '$qty',
                                  style: GoogleFonts.lato(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      itemDesc,
                                      style: GoogleFonts.lato(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    if (fine.transactionId != null && fine.transactionId!.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'Transaction Ref: #${fine.transactionId}',
                                        style: GoogleFonts.lato(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                    if (fine.issueDate != null || fine.returnDate != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'Issued: ${fine.issueDate ?? "—"}  •  Returned: ${fine.returnDate ?? "—"}',
                                        style: GoogleFonts.lato(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: 90,
                                child: Text(
                                  amount.toStringAsFixed(2),
                                  textAlign: TextAlign.right,
                                  style: GoogleFonts.lato(
                                    fontSize: 13,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 90,
                                child: Text(
                                  '₹${amount.toStringAsFixed(2)}',
                                  textAlign: TextAlign.right,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Divider(height: 1, color: Color(0xffCBD5E1)),

                        const SizedBox(height: 16),

                        // ── 4. Totals Block & Status Stamp ──
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Paid Stamp / Collection info on Left
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xffF0FDF4),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xff86EFAC)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.check_circle, size: 16, color: Color(0xff16A34A)),
                                      const SizedBox(width: 6),
                                      Text(
                                        'STATUS: PAID & SETTLED',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xff166534),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (fine.paidBy != null && fine.paidBy!.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Collected by: ${fine.paidBy}',
                                      style: GoogleFonts.lato(
                                        fontSize: 11,
                                        color: const Color(0xff166534),
                                      ),
                                    ),
                                  ],
                                  if (fine.paidAt != null && fine.paidAt!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'Payment Time: ${_formatDateTime(fine.paidAt!)}',
                                      style: GoogleFonts.lato(
                                        fontSize: 11,
                                        color: const Color(0xff166534),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // Totals breakdown on Right
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 100,
                                      child: Text(
                                        'Subtotal',
                                        style: GoogleFonts.lato(fontSize: 12.5, color: Colors.grey[700]),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 100,
                                      child: Text(
                                        '₹${amount.toStringAsFixed(2)}',
                                        textAlign: TextAlign.right,
                                        style: GoogleFonts.lato(fontSize: 12.5, color: Colors.black87),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 100,
                                      child: Text(
                                        'Sales Tax (5%)',
                                        style: GoogleFonts.lato(fontSize: 12.5, color: Colors.grey[700]),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 100,
                                      child: Text(
                                        '₹0.00',
                                        textAlign: TextAlign.right,
                                        style: GoogleFonts.lato(fontSize: 12.5, color: Colors.black87),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  width: 200,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: const BoxDecoration(
                                    border: Border(
                                      top: BorderSide(color: Colors.black, width: 1),
                                      bottom: BorderSide(color: Colors.black, width: 2),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Total (INR)',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                      Text(
                                        '₹${amount.toStringAsFixed(2)}',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 40),

                        // ── 5. Notes Section ──
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Notes',
                              style: GoogleFonts.montserrat(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Thank you for settling your fine. Please retain this receipt for laboratory clearance, dues clearance, and semester audit purposes.',
                              style: GoogleFonts.lato(
                                fontSize: 11.5,
                                color: Colors.grey[700],
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'For questions or support, contact us at isa.vesit@ves.ac.in or (555) 987-6543.',
                              style: GoogleFonts.lato(
                                fontSize: 11.5,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom Button Toolbar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Close',
                        style: GoogleFonts.lato(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xff19335A),
                        side: const BorderSide(color: Color(0xff19335A)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: Text(
                        'Share PDF',
                        style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      onPressed: _handleShare,
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff19335A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 2,
                      ),
                      icon: const Icon(Icons.print_rounded, size: 18),
                      label: Text(
                        'Print / Download Receipt',
                        style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      onPressed: _handlePrint,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return DateFormat('dd/MM/yyyy, hh:mm a').format(dt);
    } catch (_) {
      return iso;
    }
  }

  BoxFit get pw_fit => BoxFit.contain;
}
