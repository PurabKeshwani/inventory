import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

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
          'About ISA & Inventorium',
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
            // Top Hero Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.precision_manufacturing_rounded,
                            color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ISA-VESIT Inventorium',
                              style: GoogleFonts.montserrat(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Empowering Student Innovation & Automation',
                              style: GoogleFonts.lato(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Section 1: Global ISA
            _buildAboutCard(
              title: 'International Society of Automation (ISA)',
              icon: Icons.public_rounded,
              content:
                  'The International Society of Automation (ISA) is a leading global non-profit organization dedicated to advancing automation and control technology. ISA supports professionals and students through educational programs, international technical certifications, and networking opportunities to shape the future of industrial automation.',
            ),

            const SizedBox(height: 14),

            // Section 2: ISA-VESIT Chapter
            _buildAboutCard(
              title: 'ISA-VESIT Student Chapter',
              icon: Icons.school_rounded,
              content:
                  'ISA-VESIT is the student chapter of ISA at Vivekanand Education Society Institute of Technology (VESIT). Our mission is to bridge academic knowledge and industry practice by providing students with hands-on workshops, technical seminars, research opportunities, and access to modern lab resources.',
            ),

            const SizedBox(height: 14),

            // Section 3: Inventorium App Capabilities
            Container(
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
                      const Icon(Icons.rocket_launch_rounded, size: 18, color: Color(0xff19335A)),
                      const SizedBox(width: 8),
                      Text(
                        'Key App Features',
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
                  _buildFeatureItem(
                    icon: Icons.inventory_2_rounded,
                    title: 'Real-Time Inventory Tracking',
                    desc: 'Instant tracking of microcontrollers, sensors, and communication modules.',
                  ),
                  _buildFeatureItem(
                    icon: Icons.qr_code_scanner_rounded,
                    title: 'QR & Barcode Scanning',
                    desc: 'Fast barcode checkout and student QR member verification.',
                  ),
                  _buildFeatureItem(
                    icon: Icons.history_rounded,
                    title: 'Audit Logs & Lazy Loaded History',
                    desc: 'Comprehensive records of active and past loans with due tracking.',
                  ),
                  _buildFeatureItem(
                    icon: Icons.notifications_active_rounded,
                    title: 'Automated Reminders & Fines',
                    desc: 'Scheduled return reminders and transparent fine assessment.',
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

  Widget _buildAboutCard({
    required String title,
    required IconData icon,
    required String content,
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
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xff19335A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Text(
            content,
            style: GoogleFonts.lato(fontSize: 13, color: Colors.grey[800], height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xff19335A).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: const Color(0xff19335A)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.montserrat(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xff19335A)),
                ),
                Text(
                  desc,
                  style: GoogleFonts.lato(fontSize: 11.5, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}