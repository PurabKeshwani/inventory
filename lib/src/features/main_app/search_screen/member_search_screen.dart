import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory/src/utils/theme/theme.dart';

class Member {
  final String name;
  final String email;
  final String id;
  final String division;
  String phone;
  final String? profileImageUrl;

  Member({
    required this.name,
    required this.email,
    required this.id,
    required this.division,
    required this.phone,
    this.profileImageUrl,
  });

  factory Member.fromJson(Map<String, dynamic> json, {String? profileImageUrl}) {
    return Member(
      name: (json['Name'] ?? 'Unknown Member').toString(),
      email: (json['Email Id'] ?? '').toString(),
      id: (json['ISA Login ID'] ?? '').toString(),
      division: (json['Division'] ?? 'N/A').toString(),
      phone: (json['Phone Number'] ?? '').toString(),
      profileImageUrl: profileImageUrl,
    );
  }
}

class MemberSearchScreen extends StatefulWidget {
  const MemberSearchScreen({super.key});

  @override
  State<MemberSearchScreen> createState() => _MemberSearchScreenState();
}

class _MemberSearchScreenState extends State<MemberSearchScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _queryController = TextEditingController();

  bool _hasSearched = false;
  bool _isLoading = false;
  Member? _foundMember;
  String _searchedQuery = '';

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _searchMember(String rawInput) async {
    final query = rawInput.trim();
    if (query.isEmpty) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _searchedQuery = query;
      _foundMember = null;
    });

    try {
      // 1. Try matching by Email Id
      var res = await _supabase
          .from('Members')
          .select()
          .ilike('Email Id', query)
          .maybeSingle();

      // 2. Fallback: Match by ISA Login ID
      if (res == null) {
        res = await _supabase
            .from('Members')
            .select()
            .ilike('ISA Login ID', query)
            .maybeSingle();
      }

      // 3. Fallback: Partial match on Email or ID
      if (res == null) {
        final list = await _supabase
            .from('Members')
            .select()
            .or('Email Id.ilike.%$query%,ISA Login ID.ilike.%$query%')
            .limit(1);
        if (list.isNotEmpty) {
          res = list.first;
        }
      }

      if (res != null) {
        final memberId = res['ISA Login ID']?.toString() ?? '';
        String? profileUrl;

        if (memberId.isNotEmpty) {
          try {
            final pRes = await _supabase
                .from('profiles')
                .select('profile_image_url')
                .eq('member_id', memberId)
                .maybeSingle();
            profileUrl = pRes?['profile_image_url'];
          } catch (_) {}
        }

        if (mounted) {
          setState(() {
            _foundMember = Member.fromJson(Map<String, dynamic>.from(res!),
                profileImageUrl: profileUrl);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _foundMember = null;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _foundMember = null;
          _isLoading = false;
        });
      }
    }
  }

  void _openQrScanner() {
    final MobileScannerController scannerController = MobileScannerController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.qr_code_scanner_rounded, color: Color(0xff19335A)),
            const SizedBox(width: 8),
            Text(
              'Scan Member QR',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: const Color(0xff19335A),
              ),
            ),
          ],
        ),
        content: SizedBox(
          height: 280,
          width: 280,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: MobileScanner(
              controller: scannerController,
              onDetect: (capture) {
                for (final barcode in capture.barcodes) {
                  if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
                    final raw = barcode.rawValue!.trim();
                    scannerController.stop();
                    Navigator.of(dialogContext).pop();

                    String lookupQuery = raw;
                    try {
                      final Map<String, dynamic> parsed = jsonDecode(raw);
                      lookupQuery = (parsed['email'] ??
                              parsed['Email Id'] ??
                              parsed['member_id'] ??
                              parsed['id'] ??
                              raw)
                          .toString();
                    } catch (_) {}

                    _queryController.text = lookupQuery;
                    _searchMember(lookupQuery);
                    break;
                  }
                }
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              scannerController.stop();
              Navigator.of(dialogContext).pop();
            },
            child: Text('Cancel', style: GoogleFonts.lato(color: Colors.grey[700])),
          ),
        ],
      ),
    );
  }

  Future<void> _editPhoneNumber() async {
    if (_foundMember == null) return;
    final isDark = CAppTheme.isDark(context);
    final phoneController = TextEditingController(text: _foundMember!.phone);

    final bool? updated = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xff1E293B) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? const Color(0xff334155) : const Color(0xffE2EAF4),
          ),
        ),
        title: Text(
          'Edit Phone Number',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xff19335A),
            fontSize: 16,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Update contact number for ${_foundMember!.name}:',
              style: GoogleFonts.lato(
                fontSize: 13,
                color: isDark ? const Color(0xff94A3B8) : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              style: GoogleFonts.lato(
                color: isDark ? Colors.white : Colors.black87,
              ),
              decoration: InputDecoration(
                labelText: 'Phone Number',
                labelStyle: TextStyle(
                  color: isDark ? const Color(0xff94A3B8) : Colors.grey[700],
                ),
                hintText: 'Enter 10-digit number',
                hintStyle: TextStyle(
                  color: isDark ? const Color(0xff64748B) : Colors.grey[400],
                ),
                prefixIcon: Icon(
                  Icons.phone_rounded,
                  color: isDark ? const Color(0xff38BDF8) : const Color(0xff19335A),
                ),
                filled: true,
                fillColor: isDark ? const Color(0xff0F172A) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xff334155) : const Color(0xffCBD5E1),
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.lato(
                color: isDark ? const Color(0xff94A3B8) : Colors.grey[700],
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? const Color(0xff0284C7) : const Color(0xff19335A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text('Save', style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (updated == true) {
      final newPhone = phoneController.text.trim();
      try {
        await _supabase
            .from('Members')
            .update({'Phone Number': newPhone})
            .eq('ISA Login ID', _foundMember!.id);

        setState(() {
          _foundMember!.phone = newPhone;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Phone number updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update phone number: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

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
          'Member Directory',
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
              // Search & QR Scan Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: CAppTheme.cardDecoration(context, radius: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lookup Member',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: primaryText,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xff0F172A) : const Color(0xffF4F7FB),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark ? const Color(0xff334155) : const Color(0xffE2EAF4),
                              ),
                            ),
                            child: TextField(
                              controller: _queryController,
                              onSubmitted: _searchMember,
                              style: GoogleFonts.lato(
                                fontSize: 13,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Enter Email ID or Login ID...',
                                hintStyle: GoogleFonts.lato(
                                  fontSize: 12,
                                  color: isDark ? const Color(0xff64748B) : Colors.grey[500],
                                ),
                                prefixIcon: Icon(Icons.search_rounded, size: 18, color: accentColor),
                                suffixIcon: _queryController.text.isNotEmpty
                                    ? IconButton(
                                        icon: Icon(Icons.clear, size: 16, color: secondaryText),
                                        onPressed: () {
                                          _queryController.clear();
                                          setState(() {});
                                        },
                                      )
                                    : null,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // QR Scan Button
                        InkWell(
                          onTap: _openQrScanner,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            height: 44,
                            width: 44,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xff0284C7).withValues(alpha: 0.2)
                                  : const Color(0xff19335A).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xff38BDF8).withValues(alpha: 0.4)
                                    : const Color(0xff19335A).withValues(alpha: 0.2),
                              ),
                            ),
                            child: Icon(
                              Icons.qr_code_scanner_rounded,
                              color: accentColor,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 42,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : () => _searchMember(_queryController.text),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? const Color(0xff0284C7) : const Color(0xff19335A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        child: _isLoading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              'Search Member',
                              style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Results Section
              if (_isLoading)
                Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                    ),
                  ),
                )
              else if (_hasSearched && _foundMember == null)
                // NOT A MEMBER STATE
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xff1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person_off_rounded, size: 40, color: Colors.red),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Not a ISA member',
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xffF87171) : Colors.red[800],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'No registered record found matching "$_searchedQuery". Please verify the email address or ISA Login ID.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.lato(
                          fontSize: 13,
                          color: secondaryText,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                )
              else if (_foundMember != null)
                // MEMBER FOUND CARD
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: CAppTheme.cardDecoration(context, radius: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Member Profile Header
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: accentColor.withValues(alpha: 0.1),
                            backgroundImage: _foundMember!.profileImageUrl != null &&
                                    _foundMember!.profileImageUrl!.isNotEmpty
                                ? NetworkImage(_foundMember!.profileImageUrl!)
                                : null,
                            child: _foundMember!.profileImageUrl == null ||
                                    _foundMember!.profileImageUrl!.isEmpty
                                ? Icon(Icons.person_rounded, size: 30, color: accentColor)
                                : null,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _foundMember!.name,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: primaryText,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'VERIFIED ISA MEMBER',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? const Color(0xff4ADE80) : Colors.green[800],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                      Divider(height: 1, color: isDark ? const Color(0xff334155) : const Color(0xffE2E8F0)),
                      const SizedBox(height: 14),

                      // Details
                      _buildInfoRow(Icons.badge_rounded, 'Login ID', _foundMember!.id, context),
                      const SizedBox(height: 10),
                      _buildInfoRow(Icons.school_rounded, 'Division / Class', _foundMember!.division, context),
                      const SizedBox(height: 10),
                      _buildInfoRow(Icons.email_rounded, 'Email Address', _foundMember!.email, context),
                      const SizedBox(height: 10),
                      _buildInfoRow(
                        Icons.phone_rounded,
                        'Phone Number',
                        _foundMember!.phone.isNotEmpty ? _foundMember!.phone : 'No phone registered',
                        context,
                      ),

                      const SizedBox(height: 18),

                      // Edit Phone Number Action
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _editPhoneNumber,
                          icon: const Icon(Icons.edit_rounded, size: 16),
                          label: Text(
                            'Edit Phone Number',
                            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: accentColor,
                            side: BorderSide(color: accentColor, width: 1.2),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, BuildContext context) {
    final isDark = CAppTheme.isDark(context);
    final primaryText = CAppTheme.primaryTextColor(context);
    final secondaryText = CAppTheme.secondaryTextColor(context);
    final accentColor = isDark ? const Color(0xff38BDF8) : const Color(0xff19335A);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: accentColor),
        const SizedBox(width: 8),
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: GoogleFonts.lato(fontSize: 12.5, color: secondaryText),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: primaryText,
            ),
          ),
        ),
      ],
    );
  }
}
