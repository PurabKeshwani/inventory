import 'package:flutter/material.dart';
import 'package:inventory/src/common_widgets/sidebar_screens/about_screen.dart';
import 'package:inventory/src/common_widgets/sidebar_screens/fine_policy_screen.dart';
import 'package:inventory/src/common_widgets/sidebar_screens/guidelines_screen.dart';
import 'package:inventory/src/features/analytics/analytics_screen.dart';
import 'package:inventory/src/features/bulk_upload/bulk_upload_screen.dart';
// import 'package:inventory/src/constants/image_strings.dart';

import 'package:inventory/src/features/main_app/menu_screen/menu_Screen.dart';
import 'package:inventory/src/features/main_app/search_screen/member_search_screen.dart';

class CustomSideDrawer extends StatelessWidget {
  const CustomSideDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.lightBlue[50],
      child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.lightBlue[100], // Adjust the header color here
              ),
              child: const SizedBox(
                  height: 40,
                  width: 40,
                  child: Image(
                      image: AssetImage(
                          "assets/images/isa-vesit-color-logo.png"))),
            ),

            // ── Core Features ──────────────────────────────────
            ListTile(
              leading: const Icon(Icons.history_edu_rounded, color: Colors.black87),
              title: const Text(
                'Transaction History',
                style: TextStyle(color: Colors.black),
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const MenuScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.people_alt_rounded, color: Colors.black87),
              title: const Text(
                'Member Directory',
                style: TextStyle(color: Colors.black),
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const MemberSearchScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart_rounded, color: Colors.black87),
              title: const Text(
                'Analytics',
                style: TextStyle(color: Colors.black),
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const AnalyticsScreen()),
                );
              },
            ),

            // ── Admin Tools ────────────────────────────────────
            const Divider(height: 1, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Admin Tools',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                  letterSpacing: 0.5,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.upload_file_rounded, color: Colors.black87),
              title: const Text(
                'Bulk Upload Inventory',
                style: TextStyle(color: Colors.black),
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const BulkUploadScreen()),
                );
              },
            ),

            // ── Information ────────────────────────────────────
            const Divider(height: 1, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Information',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                  letterSpacing: 0.5,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.gavel_rounded, color: Colors.black87),
              title: const Text(
                'Terms & Conditions',
                style: TextStyle(color: Colors.black),
              ),
              onTap: () {
                Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => GuidelinesScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.policy_rounded, color: Colors.black87),
              title: const Text(
                'Fine Policy',
                style: TextStyle(color: Colors.black),
              ),
              onTap: () {
                Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => FinePolicyPdf()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded, color: Colors.black87),
              title: const Text(
                'About',
                style: TextStyle(color: Colors.black),
              ),
              onTap: () {
                Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const AboutPage()));
              },
            ),
          ],
        ),
      );
  }
}
