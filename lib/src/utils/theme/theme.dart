import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CAppTheme {
  // ── Helper Utilities ─────────────────────────────────────────
  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  /// Dynamic background gradient that looks gorgeous in both Light and Dark mode
  static LinearGradient bgGradient(BuildContext context) {
    if (isDark(context)) {
      return const LinearGradient(
        colors: [
          Color(0xff080E1A), // Ultra deep navy-black
          Color(0xff0F172A), // Slate 900
          Color(0xff162032), // Dark slate blue
        ],
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
      );
    }
    return const LinearGradient(
      colors: [
        Color.fromARGB(255, 175, 220, 255),
        Color.fromARGB(255, 225, 246, 252),
        Color.fromARGB(255, 245, 254, 255),
      ],
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
    );
  }

  /// Theme-aware primary text color
  static Color primaryTextColor(BuildContext context) {
    return isDark(context) ? const Color(0xffF8FAFC) : const Color(0xff19335A);
  }

  /// Theme-aware secondary text color
  static Color secondaryTextColor(BuildContext context) {
    return isDark(context) ? const Color(0xff94A3B8) : const Color(0xff64748B);
  }

  /// Theme-aware container / card border color
  static Color borderColor(BuildContext context) {
    return isDark(context) ? const Color(0xff334155) : const Color(0xffE2EAF4);
  }

  /// Theme-aware elevated card decoration
  static BoxDecoration cardDecoration(BuildContext context, {double radius = 14}) {
    final dark = isDark(context);
    return BoxDecoration(
      color: dark ? const Color(0xff1E293B) : Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: dark ? const Color(0xff334155) : const Color(0xffE2EAF4),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: dark ? Colors.black.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.04),
          blurRadius: dark ? 8 : 6,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  // ── Light Theme ──────────────────────────────────────────────
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xffF4F7FB),
    primaryColor: const Color(0xff19335A),
    colorScheme: const ColorScheme.light(
      primary: Color(0xff19335A),
      secondary: Color(0xff0845BB),
      tertiary: Color(0xff0284C7),
      surface: Colors.white,
      onSurface: Color(0xff0F172A),
      onPrimary: Colors.white,
      surfaceContainerHighest: Color(0xffF1F5F9),
      outline: Color(0xffCBD5E1),
    ),
    cardColor: Colors.white,
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 1.5,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xffE2EAF4), width: 1),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xff19335A),
      foregroundColor: Colors.white,
      elevation: 0,
      titleTextStyle: GoogleFonts.montserrat(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
      iconTheme: const IconThemeData(color: Colors.white),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: Color(0xff19335A),
      unselectedItemColor: Color(0xff64748B),
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: Color(0xffF8FAFC),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titleTextStyle: GoogleFonts.montserrat(
        color: const Color(0xff19335A),
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
      contentTextStyle: GoogleFonts.lato(
        color: const Color(0xff334155),
        fontSize: 14,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      hintStyle: GoogleFonts.lato(color: const Color(0xff94A3B8), fontSize: 13),
      labelStyle: GoogleFonts.lato(color: const Color(0xff475569), fontSize: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xffCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xffCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xff19335A), width: 1.5),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xffE2E8F0),
      thickness: 1,
    ),
    textTheme: TextTheme(
      headlineLarge: GoogleFonts.montserrat(color: const Color(0xff0F172A), fontWeight: FontWeight.bold),
      headlineMedium: GoogleFonts.montserrat(color: const Color(0xff0F172A), fontWeight: FontWeight.bold),
      titleLarge: GoogleFonts.montserrat(color: const Color(0xff19335A), fontWeight: FontWeight.w600),
      titleMedium: GoogleFonts.montserrat(color: const Color(0xff19335A), fontWeight: FontWeight.w600),
      bodyLarge: GoogleFonts.lato(color: const Color(0xff1E293B)),
      bodyMedium: GoogleFonts.lato(color: const Color(0xff334155)),
      bodySmall: GoogleFonts.lato(color: const Color(0xff64748B)),
    ),
  );

  // ── Dark Theme (Sleek Cyber Navy / Midnight Slate) ────────────
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xff080E1A), // Midnight Void
    primaryColor: const Color(0xff38BDF8), // Electric Sky Blue
    colorScheme: const ColorScheme.dark(
      primary: Color(0xff38BDF8),
      secondary: Color(0xff818CF8),
      tertiary: Color(0xff34D399),
      surface: Color(0xff1E293B), // Slate 800
      onSurface: Color(0xffF8FAFC),
      onPrimary: Color(0xff080E1A),
      surfaceContainerHighest: Color(0xff0F172A),
      outline: Color(0xff334155),
    ),
    cardColor: const Color(0xff1E293B),
    cardTheme: CardThemeData(
      color: const Color(0xff1E293B),
      elevation: 0,
      shadowColor: Colors.black.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xff334155), width: 1),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xff0F172A),
      foregroundColor: const Color(0xffF8FAFC),
      elevation: 0,
      titleTextStyle: GoogleFonts.montserrat(
        color: const Color(0xffF8FAFC),
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
      iconTheme: const IconThemeData(color: Color(0xffF8FAFC)),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xff0F172A),
      selectedItemColor: Color(0xff38BDF8),
      unselectedItemColor: Color(0xff64748B),
      type: BottomNavigationBarType.fixed,
      elevation: 10,
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: Color(0xff0F172A),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xff1E293B),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titleTextStyle: GoogleFonts.montserrat(
        color: const Color(0xffF8FAFC),
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
      contentTextStyle: GoogleFonts.lato(
        color: const Color(0xffCBD5E1),
        fontSize: 14,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xff0F172A),
      hintStyle: GoogleFonts.lato(color: const Color(0xff64748B), fontSize: 13),
      labelStyle: GoogleFonts.lato(color: const Color(0xff94A3B8), fontSize: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xff334155)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xff334155)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xff38BDF8), width: 1.5),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xff334155),
      thickness: 1,
    ),
    textTheme: TextTheme(
      headlineLarge: GoogleFonts.montserrat(color: const Color(0xffF8FAFC), fontWeight: FontWeight.bold),
      headlineMedium: GoogleFonts.montserrat(color: const Color(0xffF8FAFC), fontWeight: FontWeight.bold),
      titleLarge: GoogleFonts.montserrat(color: const Color(0xffF8FAFC), fontWeight: FontWeight.w600),
      titleMedium: GoogleFonts.montserrat(color: const Color(0xffF8FAFC), fontWeight: FontWeight.w600),
      bodyLarge: GoogleFonts.lato(color: const Color(0xffF1F5F9)),
      bodyMedium: GoogleFonts.lato(color: const Color(0xffCBD5E1)),
      bodySmall: GoogleFonts.lato(color: const Color(0xff94A3B8)),
    ),
  );
}
