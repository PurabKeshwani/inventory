import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inventory/src/utils/theme/theme.dart';

class FinePolicyPdf extends StatelessWidget {
  const FinePolicyPdf({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = CAppTheme.isDark(context);
    final primaryText = CAppTheme.primaryTextColor(context);
    final secondaryText = CAppTheme.secondaryTextColor(context);
    final accentColor = isDark ? const Color(0xff38BDF8) : const Color(0xff19335A);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xff0F172A) : const Color(0xff19335A),
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
      body: Container(
        decoration: BoxDecoration(
          gradient: CAppTheme.bgGradient(context),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Hero Notice
              Container(
                padding: const EdgeInsets.all(16),
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
                    color: isDark ? const Color(0xff38BDF8).withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.15),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.4)
                          : const Color(0xff19335A).withValues(alpha: 0.2),
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
                        color: isDark ? const Color(0xff38BDF8).withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.policy_rounded, color: isDark ? const Color(0xff38BDF8) : Colors.white, size: 26),
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
              ),

              const SizedBox(height: 16),

              // 1. Objectives
              _buildSectionCard(
                context: context,
                title: '1. Objective & Purpose',
                icon: Icons.track_changes_rounded,
                child: Text(
                  'This policy outlines the responsibilities of students when borrowing components from ISA-VESIT and establishes a structured fine system for late returns, component damage, or lost equipment.',
                  style: GoogleFonts.lato(fontSize: 13.5, color: secondaryText, height: 1.45),
                ),
              ),

              const SizedBox(height: 14),

              // 2. Issuance & Timing
              _buildSectionCard(
                context: context,
                title: '2. Issuance & Operating Hours',
                icon: Icons.schedule_rounded,
                child: Column(
                  children: [
                    _buildBulletPoint(context, 'Eligibility: Only currently enrolled ISA Members are eligible to borrow components.'),
                    _buildBulletPoint(context, 'Issuance is subject to component availability and project necessity.'),
                    _buildBulletPoint(context, 'All loans and returns must be executed in the presence of an authorized ISA Council member.'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.access_time_filled_rounded, size: 18, color: accentColor),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Issuance & Return Timings:\nSlot 1: 1:00 PM – 1:30 PM\nSlot 2: 3:30 PM – 4:00 PM',
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: primaryText,
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
                context: context,
                title: '3. Fine Structure Matrix',
                icon: Icons.currency_rupee_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Late return fines are calculated based on component cost:',
                      style: GoogleFonts.lato(fontSize: 13, color: secondaryText),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Table(
                        border: TableBorder.all(
                          color: isDark ? const Color(0xff334155) : const Color(0xffE2EAF4),
                        ),
                        columnWidths: const {
                          0: FlexColumnWidth(1.2),
                          1: FlexColumnWidth(1.2),
                          2: FlexColumnWidth(2.2),
                        },
                        children: [
                          TableRow(
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xff0F172A) : const Color(0xff19335A),
                            ),
                            children: [
                              _buildTableHeader('Cost Range'),
                              _buildTableHeader('Fine Rate'),
                              _buildTableHeader('Calculation Example'),
                            ],
                          ),
                          _buildTableRow(context, '₹0 – ₹99', '₹10 Flat', '₹50 item = ₹10 fine applied'),
                          _buildTableRow(context, '₹100 – ₹499', '12%', '₹200 item = ₹24 fine applied'),
                          _buildTableRow(context, '₹500 – ₹999', '18%', '₹800 item = ₹144 fine applied'),
                          _buildTableRow(context, '₹1,000+', '28%', '₹1,000 item = ₹280 fine applied'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '• Maximum late fine cap per loan is capped at ₹2,500.\n• Fines must be cleared within 5 days of notification.',
                      style: GoogleFonts.lato(fontSize: 12, color: secondaryText, height: 1.35),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 4. Damage & Loss Policy
              _buildSectionCard(
                context: context,
                title: '4. Damage & Loss Liabilities',
                icon: Icons.warning_amber_rounded,
                child: Column(
                  children: [
                    _buildBulletPoint(context, 'Component Modifications: Soldering alterations, track cutting, or hardware modifications are strictly prohibited.'),
                    _buildBulletPoint(context, 'Component Damage: In case of physical, thermal, or electrical damage, the student must pay the full replacement cost of a brand new unit.'),
                    _buildBulletPoint(context, 'Component Loss: Full replacement cost is mandatory before end-semester clearances.'),
                    _buildBulletPoint(context, 'All components must be returned before commencement of end-semester examinations.'),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 5. Consequences of Non-Payment
              _buildSectionCard(
                context: context,
                title: '5. Consequences of Non-Payment',
                icon: Icons.gavel_rounded,
                child: Column(
                  children: [
                    _buildWarningBullet(context, 'Immediate suspension of ISA inventory borrowing privileges.'),
                    _buildWarningBullet(context, 'ISA Student Chapter Membership suspension.'),
                    _buildWarningBullet(context, 'Central Library clearance hold for college Leaving Certificate.'),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 6. Contact Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: CAppTheme.cardDecoration(context, radius: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.support_agent_rounded, color: accentColor, size: 24),
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
                              color: primaryText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Reach out to ISA Council or email isavesit@ves.ac.in',
                            style: GoogleFonts.lato(fontSize: 12, color: secondaryText),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final isDark = CAppTheme.isDark(context);
    final primaryText = CAppTheme.primaryTextColor(context);
    final accentColor = isDark ? const Color(0xff38BDF8) : const Color(0xff19335A);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: CAppTheme.cardDecoration(context, radius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: accentColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: primaryText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildBulletPoint(BuildContext context, String text) {
    final secondaryText = CAppTheme.secondaryTextColor(context);
    final accentColor = CAppTheme.isDark(context) ? const Color(0xff38BDF8) : const Color(0xff19335A);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: accentColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.lato(fontSize: 13, color: secondaryText, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningBullet(BuildContext context, String text) {
    final isDark = CAppTheme.isDark(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cancel_rounded, color: isDark ? const Color(0xffF87171) : Colors.red, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.lato(
                fontSize: 13,
                color: isDark ? const Color(0xffFCA5A5) : Colors.red[900],
                height: 1.35,
              ),
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

  TableRow _buildTableRow(BuildContext context, String col1, String col2, String col3) {
    final isDark = CAppTheme.isDark(context);
    final primaryText = CAppTheme.primaryTextColor(context);
    final secondaryText = CAppTheme.secondaryTextColor(context);
    final accentColor = isDark ? const Color(0xff38BDF8) : const Color(0xff19335A);

    return TableRow(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xff1E293B) : Colors.transparent,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(col1, textAlign: TextAlign.center, style: GoogleFonts.lato(fontSize: 11.5, fontWeight: FontWeight.bold, color: primaryText)),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(col2, textAlign: TextAlign.center, style: GoogleFonts.montserrat(fontSize: 11.5, fontWeight: FontWeight.bold, color: accentColor)),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(col3, style: GoogleFonts.lato(fontSize: 11, color: secondaryText)),
        ),
      ],
    );
  }
}
