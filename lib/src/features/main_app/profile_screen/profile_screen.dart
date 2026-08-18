import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:inventory/src/features/authentication/controllers/emailcontroller.dart';
import 'package:inventory/src/features/authentication/screens/log_out_widget.dart';
import 'package:inventory/src/utils/theme/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _supabase = Supabase.instance.client;
  late final Emailcontroller emailGet;
  File? _image;
  final ImagePicker _picker = ImagePicker();
  bool _isDarkMode = false;
  String _displayName = '';
  String _displayEmail = '';

  @override
  void initState() {
    super.initState();
    emailGet = Get.isRegistered<Emailcontroller>()
        ? Get.find<Emailcontroller>()
        : Get.put(Emailcontroller());
    _loadUserProfile();
    _loadImage();
    _loadThemePreference();
  }

  Future<void> _loadUserProfile() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Resolve Email
    String email = emailGet.emailget.value.trim();
    if (email.isEmpty) {
      email = _supabase.auth.currentUser?.email ?? '';
    }
    if (email.isEmpty) {
      email = prefs.getString('email') ?? prefs.getString('saved_email') ?? '';
    }

    if (email.isNotEmpty) {
      emailGet.emailget.value = email;
      _displayEmail = email;
    }

    // 2. Resolve Name from emailToName map or formatted email
    String resolvedName = _resolveNameFromEmail(email);

    // 3. Try to fetch from Supabase 'admins' or 'members' table
    try {
      if (email.isNotEmpty) {
        final adminRes = await _supabase
            .from('admins')
            .select()
            .eq('emailid', email.toLowerCase());
        if (adminRes.isNotEmpty && adminRes.first['name'] != null) {
          resolvedName = adminRes.first['name'].toString();
        } else {
          final memberRes = await _supabase
              .from('members')
              .select()
              .eq('email', email.toLowerCase());
          if (memberRes.isNotEmpty && memberRes.first['name'] != null) {
            resolvedName = memberRes.first['name'].toString();
          }
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _displayName = resolvedName;
        _displayEmail = email.isNotEmpty ? email : 'admin@ves.ac.in';
        emailGet.Namefrommail.value = resolvedName;
      });
    }
  }

  String _resolveNameFromEmail(String email) {
    if (email.isEmpty) return 'Admin User';

    final normalized = email.trim().toLowerCase();

    // Check predefined mapping in emailGet
    if (emailGet.emailToName.containsKey(normalized)) {
      return emailGet.emailToName[normalized]!;
    }

    for (final entry in emailGet.emailToName.entries) {
      if (entry.key.toLowerCase() == normalized) {
        return entry.value;
      }
    }

    // Parse name from email format (e.g. 2024.tanvi.jagade@ves.ac.in -> Tanvi Jagade)
    try {
      final namePart = normalized.split('@').first;
      final segments = namePart.split(RegExp(r'[\._\-]'));
      final validSegments = segments.where((s) => !RegExp(r'^[0-9]+$').hasMatch(s) && s.isNotEmpty).toList();

      if (validSegments.isNotEmpty) {
        return validSegments
            .map((s) => s.substring(0, 1).toUpperCase() + s.substring(1))
            .join(' ');
      }
    } catch (_) {}

    return 'Inventory Administrator';
  }

  Future<void> _loadImage() async {
    final prefs = await SharedPreferences.getInstance();
    final imagePath = prefs.getString('profile_image');
    if (imagePath != null && mounted) {
      setState(() {
        _image = File(imagePath);
      });
    }
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('is_dark_mode') ?? Get.isDarkMode;
    if (mounted) {
      setState(() {
        _isDarkMode = isDark;
      });
    }
  }

  Future<void> _toggleDarkMode(bool value) async {
    setState(() {
      _isDarkMode = value;
    });
    Get.changeThemeMode(value ? ThemeMode.dark : ThemeMode.light);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', value);
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null && mounted) {
      setState(() {
        _image = File(pickedFile.path);
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_image', pickedFile.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CAppTheme.isDark(context);
    final primaryText = CAppTheme.primaryTextColor(context);
    final secondaryText = CAppTheme.secondaryTextColor(context);
    final accentColor = isDark ? const Color(0xff38BDF8) : const Color(0xff19335A);
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xff080E1A) : const Color(0xffF0F4F8),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xff0F172A) : const Color(0xff19335A),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'My Profile',
          style: GoogleFonts.montserrat(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SizedBox.expand(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: CAppTheme.bgGradient(context),
          ),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: screenHeight - kToolbarHeight - MediaQuery.of(context).padding.top,
              ),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    // Top Hero Profile Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 26),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? const [Color(0xff0F172A), Color(0xff1E293B)]
                              : const [Color(0xff19335A), Color(0xff2A4E80)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(24),
                          bottomRight: Radius.circular(24),
                        ),
                        border: Border(
                          bottom: BorderSide(
                            color: isDark ? const Color(0xff334155) : Colors.transparent,
                          ),
                        ),
                      ),
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              GestureDetector(
                                onTap: _pickImage,
                                child: Container(
                                  width: 104,
                                  height: 104,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.3),
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.15),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: _image != null
                                        ? Image.file(
                                            _image!,
                                            width: 104,
                                            height: 104,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => const Icon(
                                              Icons.person_rounded,
                                              size: 54,
                                              color: Color(0xff19335A),
                                            ),
                                          )
                                        : Image.asset(
                                            "assets/images/isa-vesit-color-logo.png",
                                            width: 104,
                                            height: 104,
                                            fit: BoxFit.contain,
                                            errorBuilder: (_, __, ___) => const Icon(
                                              Icons.person_rounded,
                                              size: 54,
                                              color: Color(0xff19335A),
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: _pickImage,
                                  child: Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xff0284C7) : const Color(0xff0845BB),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // User Name Display
                          Obx(
                            () {
                              final name = emailGet.Namefrommail.value.isNotEmpty
                                  ? emailGet.Namefrommail.value
                                  : (_displayName.isNotEmpty ? _displayName : 'Tanvi Jagade');
                              return Text(
                                name,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.montserrat(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 4),

                          // User Email Display
                          Obx(
                            () {
                              final mail = emailGet.emailget.value.isNotEmpty
                                  ? emailGet.emailget.value
                                  : _displayEmail;
                              return Text(
                                mail,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.lato(
                                  fontSize: 13,
                                  color: isDark ? const Color(0xff94A3B8) : Colors.white70,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),

                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.verified_user_rounded, color: Colors.white, size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  'INVENTORY ADMINISTRATOR',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Profile Settings Section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Preferences & Settings',
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: primaryText,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Dark Mode Switch Tile
                          Container(
                            decoration: CAppTheme.cardDecoration(context, radius: 14),
                            child: Material(
                              color: Colors.transparent,
                              child: SwitchListTile(
                                value: _isDarkMode,
                                onChanged: _toggleDarkMode,
                                activeThumbColor: accentColor,
                                secondary: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: accentColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    _isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                                    color: accentColor,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  'Dark Theme Mode',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: primaryText,
                                  ),
                                ),
                                subtitle: Text(
                                  _isDarkMode ? 'Dark UI theme active' : 'Light UI theme active',
                                  style: GoogleFonts.lato(fontSize: 12, color: secondaryText),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // App Info Card
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: CAppTheme.cardDecoration(context, radius: 14),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: accentColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.info_outline_rounded,
                                      color: accentColor, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'ISA VESIT Inventory System',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: primaryText,
                                        ),
                                      ),
                                      Text(
                                        'Version 2.4.0 • Enterprise Edition',
                                        style: GoogleFonts.lato(fontSize: 11.5, color: secondaryText),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // Logout Action
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: LogOUtWidget()),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
