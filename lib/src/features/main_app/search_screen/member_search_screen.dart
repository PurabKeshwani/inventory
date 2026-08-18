import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      name: (json['Name'] ?? json['name'] ?? 'Unknown Member').toString(),
      email: (json['Email Id'] ?? json['email'] ?? '').toString(),
      id: (json['ISA Login ID'] ?? json['id'] ?? json['member_id'] ?? '').toString(),
      division: (json['Division'] ?? json['division'] ?? json['class'] ?? 'N/A').toString(),
      phone: (json['Phone Number'] ?? json['phone'] ?? '').toString(),
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

  bool _isLoading = true;
  List<Member> _allMembers = [];
  List<Member> _filteredMembers = [];
  String _selectedDivision = 'All';
  List<String> _divisions = ['All'];

  @override
  void initState() {
    super.initState();
    _loadAllMembers();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _loadAllMembers() async {
    setState(() => _isLoading = true);

    try {
      final res = await _supabase
          .from('Members')
          .select()
          .order('Name', ascending: true);

      final membersList = (res as List<dynamic>)
          .map((m) => Member.fromJson(Map<String, dynamic>.from(m)))
          .toList();

      final divSet = <String>{'All'};
      for (final m in membersList) {
        if (m.division.isNotEmpty && m.division != 'N/A') {
          divSet.add(m.division);
        }
      }

      if (mounted) {
        setState(() {
          _allMembers = membersList;
          _filteredMembers = membersList;
          _divisions = divSet.toList()..sort();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterMembers(String query) {
    final q = query.trim().toLowerCase();

    setState(() {
      _filteredMembers = _allMembers.where((m) {
        final matchesQuery = q.isEmpty ||
            m.name.toLowerCase().contains(q) ||
            m.email.toLowerCase().contains(q) ||
            m.id.toLowerCase().contains(q) ||
            m.phone.contains(q) ||
            m.division.toLowerCase().contains(q);

        final matchesDivision =
            _selectedDivision == 'All' || m.division.toLowerCase() == _selectedDivision.toLowerCase();

        return matchesQuery && matchesDivision;
      }).toList();
    });
  }

  void _onDivisionSelected(String division) {
    setState(() {
      _selectedDivision = division;
    });
    _filterMembers(_queryController.text);
  }

  void _openQrScanner() {
    final MobileScannerController scannerController = MobileScannerController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        final isDark = CAppTheme.isDark(context);
        final primaryText = CAppTheme.primaryTextColor(context);
        final accentColor = isDark ? const Color(0xff38BDF8) : const Color(0xff19335A);

        return AlertDialog(
          backgroundColor: isDark ? const Color(0xff0F172A) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: isDark ? const Color(0xff334155) : Colors.transparent),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.qr_code_scanner_rounded, color: accentColor, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Scan Member QR',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: primaryText,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(dialogContext),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  height: 260,
                  width: 260,
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
                          _filterMembers(lookupQuery);
                          break;
                        }
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editPhoneNumber(Member member) async {
    final isDark = CAppTheme.isDark(context);
    final phoneController = TextEditingController(text: member.phone);
    final accentColor = isDark ? const Color(0xff38BDF8) : const Color(0xff19335A);

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
              'Update contact number for ${member.name}:',
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
                  color: accentColor,
                ),
                filled: true,
                fillColor: isDark ? const Color(0xff0F172A) : const Color(0xffF8FAFC),
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
              backgroundColor: accentColor,
              foregroundColor: isDark ? const Color(0xff080E1A) : Colors.white,
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
            .eq('ISA Login ID', member.id);

        setState(() {
          member.phone = newPhone;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Phone number updated successfully!'),
              backgroundColor: Color(0xff15803D),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update phone number: $e'),
              backgroundColor: Colors.red[700],
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
          'Member Directory',
          style: GoogleFonts.montserrat(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Refresh Members',
            onPressed: _loadAllMembers,
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: CAppTheme.bgGradient(context),
        ),
        child: Column(
          children: [
            // Top Search & Filter Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xff0F172A) : Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xff334155) : const Color(0xffE2EAF4),
                  ),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Search TextField
                      Expanded(
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xff1E293B) : const Color(0xffF4F7FB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? const Color(0xff334155) : const Color(0xffE2EAF4),
                            ),
                          ),
                          child: TextField(
                            controller: _queryController,
                            onChanged: _filterMembers,
                            style: GoogleFonts.lato(
                              fontSize: 13,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search by Name, Email, Login ID, Class...',
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
                                        _filterMembers('');
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // QR Scan Button
                      InkWell(
                        onTap: _openQrScanner,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: 44,
                          width: 44,
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xff38BDF8).withValues(alpha: 0.15)
                                : const Color(0xff19335A).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
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

                  // Division Filter Pills
                  if (_divisions.length > 1) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 30,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _divisions.length,
                        itemBuilder: (context, index) {
                          final div = _divisions[index];
                          final isSelected = div == _selectedDivision;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(div),
                              labelStyle: GoogleFonts.montserrat(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? (isDark ? const Color(0xff080E1A) : Colors.white)
                                    : (isDark ? const Color(0xff94A3B8) : Colors.grey[700]),
                              ),
                              selected: isSelected,
                              selectedColor: accentColor,
                              backgroundColor: isDark ? const Color(0xff1E293B) : const Color(0xffF1F5F9),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              onSelected: (_) => _onDivisionSelected(div),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Members List
            Expanded(
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: accentColor, strokeWidth: 3),
                          const SizedBox(height: 14),
                          Text(
                            'Loading members directory...',
                            style: GoogleFonts.lato(fontSize: 13, color: secondaryText),
                          ),
                        ],
                      ),
                    )
                  : _filteredMembers.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.people_outline_rounded, size: 48, color: secondaryText),
                                const SizedBox(height: 12),
                                Text(
                                  'No Members Found',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: primaryText,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Try searching by different keywords or scan a student ID.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.lato(fontSize: 12.5, color: secondaryText),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                          itemCount: _filteredMembers.length,
                          itemBuilder: (context, index) {
                            final member = _filteredMembers[index];
                            return _buildMemberCard(member, context);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberCard(Member member, BuildContext context) {
    final isDark = CAppTheme.isDark(context);
    final primaryText = CAppTheme.primaryTextColor(context);
    final secondaryText = CAppTheme.secondaryTextColor(context);
    final accentColor = isDark ? const Color(0xff38BDF8) : const Color(0xff19335A);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: CAppTheme.cardDecoration(context, radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xff1E293B) : const Color(0xffE2EAF4),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    member.name.isNotEmpty ? member.name.substring(0, 1).toUpperCase() : 'M',
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Name & Verification Badge
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      style: GoogleFonts.montserrat(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: primaryText,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: isDark ? 0.2 : 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'VERIFIED MEMBER',
                            style: GoogleFonts.montserrat(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: isDark ? const Color(0xff4ADE80) : Colors.green[800],
                            ),
                          ),
                        ),
                        if (member.division.isNotEmpty && member.division != 'N/A') ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              member.division,
                              style: GoogleFonts.montserrat(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: accentColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: isDark ? const Color(0xff334155) : const Color(0xffE2EAF4)),
          const SizedBox(height: 10),

          // Metadata Details
          _buildDetailRow(Icons.badge_rounded, 'Login ID', member.id, context),
          const SizedBox(height: 6),
          _buildDetailRow(Icons.email_rounded, 'Email', member.email, context),
          const SizedBox(height: 6),
          _buildDetailRow(
            Icons.phone_rounded,
            'Phone',
            member.phone.isNotEmpty ? member.phone : 'Not registered',
            context,
          ),

          const SizedBox(height: 12),

          // Edit Contact Button
          SizedBox(
            width: double.infinity,
            height: 36,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: accentColor.withValues(alpha: 0.4)),
                foregroundColor: accentColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.edit_rounded, size: 14),
              label: Text(
                'Edit Phone Number',
                style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              onPressed: () => _editPhoneNumber(member),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, BuildContext context) {
    final isDark = CAppTheme.isDark(context);
    final primaryText = CAppTheme.primaryTextColor(context);
    final secondaryText = CAppTheme.secondaryTextColor(context);
    final accentColor = isDark ? const Color(0xff38BDF8) : const Color(0xff19335A);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 14, color: accentColor),
        const SizedBox(width: 8),
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: GoogleFonts.lato(fontSize: 11.5, color: secondaryText),
          ),
        ),
        Expanded(
          child: InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Copied $label: $value')),
              );
            },
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.lato(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: primaryText,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
