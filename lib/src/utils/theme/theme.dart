import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CAppTheme {
  // Light Theme
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xffF4F7FB),
    primaryColor: const Color(0xff19335A),
    colorScheme: const ColorScheme.light(
      primary: Color(0xff19335A),
      secondary: Color(0xff0845BB),
      surface: Colors.white,
      onSurface: Colors.black87,
      onPrimary: Colors.white,
    ),
    cardColor: Colors.white,
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
    textTheme: TextTheme(
      headlineLarge: GoogleFonts.montserrat(color: Colors.black87, fontWeight: FontWeight.bold),
      headlineMedium: GoogleFonts.montserrat(color: Colors.black87, fontWeight: FontWeight.bold),
      titleLarge: GoogleFonts.montserrat(color: Colors.black87, fontWeight: FontWeight.w600),
      bodyLarge: GoogleFonts.lato(color: Colors.black87),
      bodyMedium: GoogleFonts.lato(color: Colors.black87),
    ),
  );

  // Dark Theme
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xff0F172A), // Slate 900
    primaryColor: const Color(0xff3B82F6),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xff3B82F6),
      secondary: Color(0xff60A5FA),
      surface: Color(0xff1E293B), // Slate 800
      onSurface: Colors.white,
      onPrimary: Colors.white,
    ),
    cardColor: const Color(0xff1E293B),
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xff0F172A),
      foregroundColor: Colors.white,
      elevation: 0,
      titleTextStyle: GoogleFonts.montserrat(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
      iconTheme: const IconThemeData(color: Colors.white),
    ),
    textTheme: TextTheme(
      headlineLarge: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold),
      headlineMedium: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold),
      titleLarge: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w600),
      bodyLarge: GoogleFonts.lato(color: Colors.white70),
      bodyMedium: GoogleFonts.lato(color: Colors.white70),
    ),
  );
}
