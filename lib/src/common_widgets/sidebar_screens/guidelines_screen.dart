import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inventory/src/utils/theme/theme.dart';

class GuidelinesScreen extends StatelessWidget {
  const GuidelinesScreen({super.key});

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
          'Terms & Conditions',
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
              // Header Banner
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
                          ? Colors.black.withOpacity(0.4)
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
                      child: Icon(Icons.gavel_rounded, color: isDark ? const Color(0xff38BDF8) : Colors.white, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Inventory Usage Agreement',
                            style: GoogleFonts.montserrat(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Terms governing hardware loans & member compliance',
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

              _buildTermSection(
                context: context,
                number: '1',
                title: 'Membership & Eligibility',
                content: 'Borrowing privileges are strictly reserved for verified, active ISA-VESIT student members. Account credentials and QR badges are non-transferable.',
              ),

              const SizedBox(height: 12),

              _buildTermSection(
                context: context,
                number: '2',
                title: 'Permitted Usage & Care',
                content: 'All borrowed components, microcontrollers, and sensors must be utilized exclusively for academic research, coursework, or official college competitions. Users are expected to exercise extreme care and ESD precautions.',
              ),

              const SizedBox(height: 12),

              _buildTermSection(
                context: context,
                number: '3',
                title: 'Loan Durations & Reissuance',
                content: 'Components are issued for a maximum standard loan period (up to 30 days). Reissuance must be approved in person by an ISA council member within 1 month of the original issue date.',
              ),

              const SizedBox(height: 12),

              _buildTermSection(
                context: context,
                number: '4',
                title: 'Mandatory Return Deadlines',
                content: 'All outstanding hardware loans must be checked in and returned to the inventory council before the commencement of semester end examinations without exception.',
              ),

              const SizedBox(height: 12),

              _buildTermSection(
                context: context,
                number: '5',
                title: 'Liability for Damage or Loss',
                content: 'Modifications, track-cutting, or permanent soldering alterations are strictly prohibited. In the event of hardware damage or loss, the borrower is legally and academically liable for the full replacement cost.',
              ),

              const SizedBox(height: 12),

              _buildTermSection(
                context: context,
                number: '6',
                title: 'Dispute Resolution & Appeals',
                content: 'Any discrepancy regarding component condition or fine assessment must be submitted in writing to the ISA Faculty In-Charge and Student Council within 3 working days.',
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTermSection({
    required BuildContext context,
    required String number,
    required String title,
    required String content,
  }) {
    final isDark = CAppTheme.isDark(context);
    final primaryText = CAppTheme.primaryTextColor(context);
    final secondaryText = CAppTheme.secondaryTextColor(context);
    final accentColor = isDark ? const Color(0xff38BDF8) : const Color(0xff19335A);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: CAppTheme.cardDecoration(context, radius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xff0284C7) : const Color(0xff19335A),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    number,
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
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
          Text(
            content,
            style: GoogleFonts.lato(
              fontSize: 13,
              color: secondaryText,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
