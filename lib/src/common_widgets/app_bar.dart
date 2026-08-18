import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inventory/src/features/main_app/profile_screen/profile_screen.dart';
import 'package:inventory/src/utils/theme/theme.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = CAppTheme.isDark(context);

    return AppBar(
      backgroundColor: isDark ? const Color(0xff0F172A) : const Color(0xff19335A),
      elevation: isDark ? 0 : 2,
      shadowColor: Colors.black.withOpacity(0.15),
      leading: IconButton(
        icon: const Icon(Icons.menu_rounded, color: Colors.white),
        tooltip: 'Navigation Menu',
        onPressed: () {
          Scaffold.of(context).openDrawer();
        },
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xff38BDF8).withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.precision_manufacturing_rounded,
              size: 18,
              color: isDark ? const Color(0xff38BDF8) : Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'ISA-VESIT',
            style: GoogleFonts.montserrat(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark
                    ? const Color(0xff38BDF8).withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: const Icon(Icons.person_rounded, color: Colors.white, size: 20),
          ),
          tooltip: 'Admin Profile',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            );
          },
        ),
        const SizedBox(width: 6),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
