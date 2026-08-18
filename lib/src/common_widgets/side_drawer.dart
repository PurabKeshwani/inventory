import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inventory/src/common_widgets/sidebar_screens/about_screen.dart';
import 'package:inventory/src/common_widgets/sidebar_screens/fine_policy_screen.dart';
import 'package:inventory/src/common_widgets/sidebar_screens/guidelines_screen.dart';
import 'package:inventory/src/features/analytics/analytics_screen.dart';
import 'package:inventory/src/features/bulk_upload/bulk_upload_screen.dart';
import 'package:inventory/src/features/main_app/menu_screen/menu_Screen.dart';
import 'package:inventory/src/features/main_app/search_screen/member_search_screen.dart';
import 'package:inventory/src/utils/theme/theme.dart';

class CustomSideDrawer extends StatelessWidget {
  const CustomSideDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = CAppTheme.isDark(context);

    final drawerBg = isDark ? const Color(0xff0F172A) : const Color(0xffF8FAFC);
    final tileTextColor = isDark ? const Color(0xffF1F5F9) : const Color(0xff1E293B);
    final iconColor = isDark ? const Color(0xff38BDF8) : const Color(0xff19335A);
    final sectionHeaderColor = isDark ? const Color(0xff94A3B8) : const Color(0xff64748B);
    final dividerColor = isDark ? const Color(0xff1E293B) : const Color(0xffE2E8F0);

    return Drawer(
      backgroundColor: drawerBg,
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          // Header Banner
          Container(
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? const [Color(0xff0F172A), Color(0xff1E293B)]
                    : const [Color(0xff19335A), Color(0xff2A4E80)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xff334155) : Colors.transparent,
                  width: 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    "assets/images/isa-vesit-color-logo.png",
                    height: 38,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.precision_manufacturing_rounded,
                      color: Color(0xff19335A),
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'ISA-VESIT Inventorium',
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Hardware & Lab Management Portal',
                  style: GoogleFonts.lato(
                    color: isDark ? const Color(0xff94A3B8) : Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── Core Features ──────────────────────────────────
          _buildDrawerTile(
            context: context,
            icon: Icons.history_edu_rounded,
            title: 'Transaction History',
            iconColor: iconColor,
            textColor: tileTextColor,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const MenuScreen()),
              );
            },
          ),
          _buildDrawerTile(
            context: context,
            icon: Icons.people_alt_rounded,
            title: 'Member Directory',
            iconColor: iconColor,
            textColor: tileTextColor,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const MemberSearchScreen()),
              );
            },
          ),
          _buildDrawerTile(
            context: context,
            icon: Icons.bar_chart_rounded,
            title: 'Analytics & Insights',
            iconColor: iconColor,
            textColor: tileTextColor,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AnalyticsScreen()),
              );
            },
          ),

          // ── Admin Tools ────────────────────────────────────
          Divider(height: 16, indent: 16, endIndent: 16, color: dividerColor),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'ADMIN TOOLS',
              style: GoogleFonts.montserrat(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: sectionHeaderColor,
                letterSpacing: 0.8,
              ),
            ),
          ),
          _buildDrawerTile(
            context: context,
            icon: Icons.upload_file_rounded,
            title: 'Bulk Upload Inventory',
            iconColor: iconColor,
            textColor: tileTextColor,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const BulkUploadScreen()),
              );
            },
          ),

          // ── Information & Policies ──────────────────────────
          Divider(height: 16, indent: 16, endIndent: 16, color: dividerColor),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'INFORMATION',
              style: GoogleFonts.montserrat(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: sectionHeaderColor,
                letterSpacing: 0.8,
              ),
            ),
          ),
          _buildDrawerTile(
            context: context,
            icon: Icons.gavel_rounded,
            title: 'Terms & Conditions',
            iconColor: iconColor,
            textColor: tileTextColor,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const GuidelinesScreen()),
              );
            },
          ),
          _buildDrawerTile(
            context: context,
            icon: Icons.policy_rounded,
            title: 'Fine Policy',
            iconColor: iconColor,
            textColor: tileTextColor,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const FinePolicyPdf()),
              );
            },
          ),
          _buildDrawerTile(
            context: context,
            icon: Icons.info_outline_rounded,
            title: 'About ISA-VESIT',
            iconColor: iconColor,
            textColor: tileTextColor,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AboutPage()),
              );
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDrawerTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Color iconColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: GoogleFonts.montserrat(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        size: 18,
        color: textColor.withValues(alpha: 0.4),
      ),
      onTap: onTap,
    );
  }
}
