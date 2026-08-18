import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inventory/src/utils/theme/theme.dart';

class CustomBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const CustomBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = CAppTheme.isDark(context);

    final bgColor = isDark ? const Color(0xff0F172A) : Colors.white;
    final selectedColor = isDark ? const Color(0xff38BDF8) : const Color(0xff19335A);
    final unselectedColor = isDark ? const Color(0xff64748B) : const Color(0xff94A3B8);
    final topBorderColor = isDark ? const Color(0xff1E293B) : const Color(0xffE2E8F0);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          top: BorderSide(color: topBorderColor, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.4) : Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: bgColor,
        elevation: 0,
        currentIndex: currentIndex,
        selectedItemColor: selectedColor,
        unselectedItemColor: unselectedColor,
        selectedLabelStyle: GoogleFonts.montserrat(
          fontSize: 11.5,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: GoogleFonts.lato(
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
        items: [
          const BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.only(bottom: 2),
              child: Icon(Icons.home_rounded),
            ),
            activeIcon: Padding(
              padding: EdgeInsets.only(bottom: 2),
              child: Icon(Icons.home_rounded),
            ),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.only(bottom: 2),
              child: Icon(Icons.inventory_2_outlined),
            ),
            activeIcon: Padding(
              padding: EdgeInsets.only(bottom: 2),
              child: Icon(Icons.inventory_2_rounded),
            ),
            label: 'Components',
          ),
          BottomNavigationBarItem(
            icon: Container(
              margin: const EdgeInsets.only(bottom: 2),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? const [Color(0xff0284C7), Color(0xff38BDF8)]
                      : const [Color(0xff19335A), Color(0xff2A4E80)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? const Color(0xff38BDF8).withValues(alpha: 0.35)
                        : const Color(0xff19335A).withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
            ),
            label: 'Add',
          ),
          const BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.only(bottom: 2),
              child: Icon(Icons.receipt_long_outlined),
            ),
            activeIcon: Padding(
              padding: EdgeInsets.only(bottom: 2),
              child: Icon(Icons.receipt_long_rounded),
            ),
            label: 'Transactions',
          ),
          const BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.only(bottom: 2),
              child: Icon(Icons.pending_actions_outlined),
            ),
            activeIcon: Padding(
              padding: EdgeInsets.only(bottom: 2),
              child: Icon(Icons.pending_actions_rounded),
            ),
            label: 'Fines',
          ),
        ],
        onTap: onTap,
      ),
    );
  }
}
