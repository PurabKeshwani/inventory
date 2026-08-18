import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class FinePolicyPdf extends StatelessWidget {
  const FinePolicyPdf({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF4F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xff19335A),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Fine Policy & Regulations',
          style: GoogleFonts.montserrat(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Hero Notice
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xff19335A), Color(0xff2A4E80)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xff19335A).withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.policy_rounded, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ISA-VESIT Inventory Rules',
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Official loan policy, fine structure & care guidelines',
                          style: GoogleFonts.lato(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 1. Objectives
            _buildSectionCard(
              title: '1. Objective & Purpose',
              icon: Icons.track_changes_rounded,
              child: Text(
                'This policy outlines the responsibilities of students when borrowing components from ISA-VESIT and establishes a structured fine system for late returns, component damage, or lost equipment.',
                style: GoogleFonts.lato(fontSize: 13.5, color: Colors.grey[800], height: 1.45),
              ),
            ),

            const SizedBox(height: 14),

            // 2. Issuance & Timing
            _buildSectionCard(
              title: '2. Issuance & Operating Hours',
              icon: Icons.schedule_rounded,
              child: Column(
                children: [
                  _buildBulletPoint('Eligibility: Only currently enrolled ISA Members are eligible to borrow components.'),
                  _buildBulletPoint('Issuance is subject to component availability and project necessity.'),
                  _buildBulletPoint('All loans and returns must be executed in the presence of an authorized ISA Council member.'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xff19335A).withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time_filled_rounded, size: 18, color: Color(0xff19335A)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Issuance & Return Timings:\nSlot 1: 1:00 PM – 1:30 PM\nSlot 2: 3:30 PM – 4:00 PM',
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xff19335A),
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // 3. Fine Structure Table
            _buildSectionCard(
              title: '3. Fine Structure Matrix',
              icon: Icons.currency_rupee_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Late return fines are calculated based on component cost:',
                    style: GoogleFonts.lato(fontSize: 13, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Table(
                      border: TableBorder.all(color: const Color(0xffE2EAF4)),
                      columnWidths: const {
                        0: FlexColumnWidth(1.2),
                        1: FlexColumnWidth(1.2),
                        2: FlexColumnWidth(2.2),
                      },
                      children: [
                        TableRow(
                          decoration: const BoxDecoration(color: Color(0xff19335A)),
                          children: [
                            _buildTableHeader('Cost Range'),
                            _buildTableHeader('Fine Rate'),
                            _buildTableHeader('Calculation Example'),
                          ],
                        ),
                        _buildTableRow('₹0 – ₹99', '₹10 Flat', '₹50 item = ₹10 fine applied'),
                        _buildTableRow('₹100 – ₹499', '12%', '₹200 item = ₹24 fine applied'),
                        _buildTableRow('₹500 – ₹999', '18%', '₹800 item = ₹144 fine applied'),
                        _buildTableRow('₹1,000+', '28%', '₹1,000 item = ₹280 fine applied'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '• Maximum late fine cap per loan is capped at ₹2,500.\n• Fines must be cleared within 5 days of notification.',
                    style: GoogleFonts.lato(fontSize: 12, color: Colors.grey[700], height: 1.35),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // 4. Damage & Loss Policy
            _buildSectionCard(
              title: '4. Damage & Loss Liabilities',
              icon: Icons.warning_amber_rounded,
              child: Column(
                children: [
                  _buildBulletPoint('Component Modifications: Soldering alterations, track cutting, or hardware modifications are strictly prohibited.'),
                  _buildBulletPoint('Component Damage: In case of physical, thermal, or electrical damage, the student must pay the full replacement cost of a brand new unit.'),
                  _buildBulletPoint('Component Loss: Full replacement cost is mandatory before end-semester clearances.'),
                  _buildBulletPoint('All components must be returned before commencement of end-semester examinations.'),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // 5. Consequences of Non-Payment
            _buildSectionCard(
              title: '5. Consequences of Non-Payment',
              icon: Icons.gavel_rounded,
              child: Column(
                children: [
                  _buildWarningBullet('Immediate suspension of ISA inventory borrowing privileges.'),
                  _buildWarningBullet('ISA Student Chapter Membership suspension.'),
                  _buildWarningBullet('Central Library clearance hold for college Leaving Certificate.'),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // 6. Contact Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xff19335A).withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xff19335A).withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.support_agent_rounded, color: Color(0xff19335A), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Questions or Fine Appeals?',
                          style: GoogleFonts.montserrat(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xff19335A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sr. Treasurer: Payaal Kapoor • 9820008894\nJr. Treasurer: Sakshi Gupta • 9833744631',
                          style: GoogleFonts.lato(fontSize: 12, color: Colors.grey[800], height: 1.35),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: Color(0xff19335A), size: 18),
                    tooltip: 'Copy Contacts',
                    onPressed: () {
                      Clipboard.setData(const ClipboardData(
                          text: 'Sr. Treasurer: Payaal Kapoor (9820008894), Jr. Treasurer: Sakshi Gupta (9833744631)'));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Treasurer contacts copied to clipboard!')),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
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
        border: Border.all(color: const Color(0xffE2EAF4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 6,
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
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 6, right: 10),
            decoration: const BoxDecoration(
              color: Color(0xff19335A),
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.lato(fontSize: 13, color: Colors.grey[800], height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cancel_rounded, color: Colors.red, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.lato(fontSize: 13, color: Colors.red[900], height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.montserrat(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  TableRow _buildTableRow(String col1, String col2, String col3) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(col1, textAlign: TextAlign.center, style: GoogleFonts.lato(fontSize: 11.5, fontWeight: FontWeight.bold)),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(col2, textAlign: TextAlign.center, style: GoogleFonts.montserrat(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xff19335A))),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(col3, style: GoogleFonts.lato(fontSize: 11, color: Colors.grey[700])),
        ),
      ],
    );
  }
}
