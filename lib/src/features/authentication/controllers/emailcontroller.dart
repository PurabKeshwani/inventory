import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:inventory/src/features/main_app/main_screen/main_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Emailcontroller extends GetxController {
  RxString emailget = ''.obs;
  RxBool isValidating = false.obs;
  RxString Namefrommail = ''.obs;
  RxBool isLoadingAdmins = false.obs;

  /// Dynamic list of authorized admin emails loaded from Supabase 'admins' table
  final RxList<String> emails = <String>[].obs;

  /// Dynamic mapping of admin email -> admin display name loaded from Supabase
  final RxMap<String, String> emailToName = <String, String>{}.obs;

  SupabaseClient? get _supabase {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  @override
  void onInit() {
    super.onInit();
    fetchAdminsFromSupabase();
  }

  /// Fetches all registered admins from Supabase 'admins' table and caches them
  Future<void> fetchAdminsFromSupabase() async {
    final client = _supabase;
    if (client == null) return;

    try {
      isLoadingAdmins.value = true;
      final response = await client
          .from('admins')
          .select('emailid, name')
          .order('name', ascending: true);

      final List<dynamic> records = response as List<dynamic>;
      final List<String> fetchedEmails = [];
      final Map<String, String> fetchedMap = {};

      for (final row in records) {
        final email = (row['emailid'] ?? '').toString().trim();
        final name = (row['name'] ?? '').toString().trim();
        if (email.isNotEmpty) {
          fetchedEmails.add(email);
          fetchedMap[email.toLowerCase()] =
              name.isNotEmpty ? name : formatNameFromEmail(email);
        }
      }

      emails.assignAll(fetchedEmails);
      emailToName.assignAll(fetchedMap);
    } catch (e) {
      debugPrint('Error fetching admin roster from Supabase: $e');
    } finally {
      isLoadingAdmins.value = false;
    }
  }

  /// Verifies if a given email is registered in Supabase 'admins' table.
  /// If valid, sets [emailget], [Namefrommail], and [isValidating].
  Future<bool> verifyAndSetAdmin(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) {
      isValidating.value = false;
      return false;
    }

    final client = _supabase;
    if (client != null) {
      try {
        // 1. Direct query to Supabase 'admins' table (case-insensitive)
        final response = await client
            .from('admins')
            .select('emailid, name')
            .ilike('emailid', trimmed)
            .limit(1);

        if (response.isNotEmpty) {
          final data = response.first;
          final resolvedEmail = (data['emailid'] ?? trimmed).toString().trim();
          final resolvedName = (data['name'] ?? '').toString().trim().isNotEmpty
              ? data['name'].toString().trim()
              : formatNameFromEmail(resolvedEmail);

          emailget.value = resolvedEmail;
          Namefrommail.value = resolvedName;
          isValidating.value = true;

          // Ensure cached mappings include this admin
          if (!emails.contains(resolvedEmail)) {
            emails.add(resolvedEmail);
          }
          emailToName[resolvedEmail.toLowerCase()] = resolvedName;
          return true;
        }
      } catch (e) {
        debugPrint('Error verifying admin status against Supabase: $e');
      }
    }

    // 2. Fallback: check already fetched cached list
    final normalized = trimmed.toLowerCase();
    final match = emails.firstWhereOrNull(
      (e) => e.trim().toLowerCase() == normalized,
    );
    if (match != null) {
      emailget.value = match;
      Namefrommail.value =
          emailToName[normalized] ?? formatNameFromEmail(match);
      isValidating.value = true;
      return true;
    }

    isValidating.value = false;
    return false;
  }

  /// Verifies current [emailget] against Supabase and navigates to [MainScreen] if authorized.
  Future<bool> mailchecker() async {
    final valid = await verifyAndSetAdmin(emailget.value);
    if (valid) {
      Get.offAll(() => const MainScreen());
      return true;
    } else {
      isValidating.value = false;
      return false;
    }
  }

  /// Formats an email like '2024.tanvi.jagade@ves.ac.in' into 'Tanvi Jagade'
  static String formatNameFromEmail(String email) {
    if (email.isEmpty) return 'Admin User';
    try {
      final namePart = email.trim().toLowerCase().split('@').first;
      final segments = namePart.split(RegExp(r'[\._\-]'));
      final validSegments = segments
          .where((s) => !RegExp(r'^[0-9]+$').hasMatch(s) && s.isNotEmpty)
          .toList();

      if (validSegments.isNotEmpty) {
        return validSegments
            .map((s) => s.substring(0, 1).toUpperCase() + s.substring(1))
            .join(' ');
      }
    } catch (_) {}
    return 'Inventory Administrator';
  }
}

