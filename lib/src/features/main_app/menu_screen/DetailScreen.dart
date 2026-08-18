import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inventory/src/features/main_app/menu_screen/models/transaction_model.dart';

class DetailScreen extends StatelessWidget {
  final TransactionModel transaction;

  const DetailScreen({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isReturned = transaction.isReturned;

    return Scaffold(
      backgroundColor: const Color(0xffF4F7FB),
      appBar: AppBar(
        title: Text(
          'Transaction Details',
          style: GoogleFonts.montserrat(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: const Color(0xff19335A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status & Transaction Header Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isReturned
                      ? [const Color(0xff0D7A53), const Color(0xff1DB978)]
                      : [const Color(0xff19335A), const Color(0xff2A4E80)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: (isReturned ? Colors.green : const Color(0xff19335A))
                        .withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isReturned
                                  ? Icons.check_circle_rounded
                                  : Icons.hourglass_top_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isReturned ? 'RETURNED' : 'DUE / ACTIVE',
                              style: GoogleFonts.lato(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, color: Colors.white70, size: 20),
                        tooltip: 'Copy Transaction ID',
                        onPressed: () async {
                          await Clipboard.setData(
                              ClipboardData(text: transaction.transactionId));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Transaction ID copied to clipboard!'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Transaction ID',
                    style: GoogleFonts.lato(fontSize: 11, color: Colors.white70),
                  ),
                  Text(
                    transaction.transactionId,
                    style: GoogleFonts.robotoMono(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Borrower Information Card
            _buildSectionCard(
              title: 'Borrower Information',
              icon: Icons.person_rounded,
              child: Column(
                children: [
                  _buildDetailRow('Member Name', transaction.memberName, isBold: true),
                  const SizedBox(height: 10),
                  _buildDetailRow('Borrower ID', transaction.borrowerId),
                  const SizedBox(height: 10),
                  _buildDetailRow('Class / Division', transaction.division),
                  const SizedBox(height: 10),
                  _buildDetailRow(
                    'Phone Number',
                    transaction.phoneNumber.isNotEmpty ? transaction.phoneNumber : 'N/A',
                  ),
                  if (transaction.issuedBy != null && transaction.issuedBy!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _buildDetailRow('Issued By', transaction.issuedBy!),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Dates Card
            _buildSectionCard(
              title: 'Timeline & Dates',
              icon: Icons.event_note_rounded,
              child: Column(
                children: [
                  _buildDetailRow('Issued Date', transaction.issueDate),
                  const SizedBox(height: 10),
                  _buildDetailRow(
                    isReturned ? 'Returned Date' : 'Expected Due Date',
                    transaction.returnDate ?? 'Pending',
                    valueColor: isReturned ? Colors.green[800] : Colors.orange[900],
                    isBold: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Package Items Card
            _buildSectionCard(
              title: 'Package Manifest (${transaction.packageItems.length} items)',
              icon: Icons.inventory_2_rounded,
              child: transaction.packageItems.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Text(
                        'No component items listed in this transaction.',
                        style: GoogleFonts.lato(color: Colors.grey[600]),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: transaction.packageItems.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = transaction.packageItems[index];
                        final cName = item['compname'] ?? item['name'] ?? 'Component';
                        final qty = item['Quantity'] ?? item['quantity'] ?? '1';
                        final sku = item['skuid']?.toString() ?? '';

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xffF9FBFE),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xffE2EAF4)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      cName.toString(),
                                      style: GoogleFonts.montserrat(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xff19335A),
                                      ),
                                    ),
                                    if (sku.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'SKU: $sku',
                                        style: GoogleFonts.lato(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xff19335A).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Qty: $qty',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xff19335A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xff19335A)),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xff19335A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    Color? valueColor,
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.lato(
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: GoogleFonts.montserrat(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor ?? const Color(0xff19335A),
          ),
        ),
      ],
    );
  }
}
