import 'dart:convert';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory/src/controllers/cache_controller.dart';
import '../models/fine_model.dart';

/// Architecture: In-Memory Cache with Realtime Invalidation
/// - Reads transparently check the permanent [CacheController] first.
/// - Cache misses or [forceRefresh] fetches fresh data from Supabase and populates the cache.
/// - Any database insert/update/delete triggers Supabase Realtime Postgres events
///   in [CacheController], which automatically invalidates this table's cache entry.
class FineService {
  final SupabaseClient _supabase = Supabase.instance.client;
  static const String tableName = 'Fines';

  CacheController? get _cache {
    try {
      return Get.find<CacheController>();
    } catch (_) {
      return null;
    }
  }

  // Fetch member info from Members table by Email, Member ID, or Name
  Future<Map<String, String>?> getMemberByEmailOrId(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return null;

    try {
      // 1. Try querying by "Email Id"
      dynamic response = await _supabase
          .from('Members')
          .select()
          .ilike('Email Id', '%$trimmed%')
          .limit(1)
          .maybeSingle();

      // 2. If not found by email, try "ISA Login ID"
      if (response == null) {
        response = await _supabase
            .from('Members')
            .select()
            .ilike('ISA Login ID', '%$trimmed%')
            .limit(1)
            .maybeSingle();
      }

      // 3. If not found by ID, try "Name"
      if (response == null) {
        response = await _supabase
            .from('Members')
            .select()
            .ilike('Name', '%$trimmed%')
            .limit(1)
            .maybeSingle();
      }

      if (response != null) {
        return {
          'member_id': response['ISA Login ID']?.toString() ?? '',
          'name': response['Name']?.toString() ?? '',
          'email': response['Email Id']?.toString() ?? '',
          'phone': response['Phone Number']?.toString() ?? '',
          'class': response['Division']?.toString() ?? '',
        };
      }
    } catch (_) {}

    // Fallback: Fetch all members and match in memory
    try {
      final allMembers = await _supabase.from('Members').select();
      final lowerQuery = trimmed.toLowerCase();
      for (var m in allMembers as List<dynamic>) {
        final email = (m['Email Id'] ?? '').toString().toLowerCase();
        final id = (m['ISA Login ID'] ?? '').toString().toLowerCase();
        final name = (m['Name'] ?? '').toString().toLowerCase();

        if (email.contains(lowerQuery) ||
            id.contains(lowerQuery) ||
            name.contains(lowerQuery)) {
          return {
            'member_id': m['ISA Login ID']?.toString() ?? '',
            'name': m['Name']?.toString() ?? '',
            'email': m['Email Id']?.toString() ?? '',
            'phone': m['Phone Number']?.toString() ?? '',
            'class': m['Division']?.toString() ?? '',
          };
        }
      }
    } catch (_) {}

    return null;
  }

  // Live Database search across all 7 inventory tables in parallel
  Future<List<Map<String, dynamic>>> searchLiveComponents(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    const tables = [
      {'name': 'Microcontroller', 'cat': 'Microcontrollers'},
      {'name': 'Sensors', 'cat': 'Sensors'},
      {'name': 'Communication Modules', 'cat': 'Communication'},
      {'name': 'Displays and Indicators', 'cat': 'Displays'},
      {'name': 'Actuators and Motors', 'cat': 'Actuators & Motors'},
      {'name': 'Power Components', 'cat': 'Power Components'},
      {'name': 'Others', 'cat': 'Others'},
    ];

    final List<Map<String, dynamic>> results = [];
    final Set<String> seenIdentifiers = {};

    // Execute queries in parallel for instant speed
    final futures = tables.map((t) async {
      try {
        final tableRes = await _supabase
            .from(t['name']!)
            .select('name, skuid, stock, boxno')
            .or('name.ilike.%$trimmed%,skuid.ilike.%$trimmed%')
            .limit(10);

        return {
          'category': t['cat']!,
          'rows': tableRes as List<dynamic>,
        };
      } catch (_) {
        // Fallback: try querying name only
        try {
          final tableRes = await _supabase
              .from(t['name']!)
              .select('name, skuid, stock, boxno')
              .ilike('name', '%$trimmed%')
              .limit(10);
          return {
            'category': t['cat']!,
            'rows': tableRes as List<dynamic>,
          };
        } catch (_) {
          return {'category': t['cat']!, 'rows': <dynamic>[]};
        }
      }
    });

    final allTableResults = await Future.wait(futures);

    for (final tr in allTableResults) {
      final cat = tr['category'] as String;
      final rows = tr['rows'] as List<dynamic>;

      for (final r in rows) {
        final name = (r['name'] ?? '').toString().trim();
        final skuid = (r['skuid'] ?? '').toString().trim();
        final stock = int.tryParse(r['stock']?.toString() ?? '0') ?? 0;
        final boxno = (r['boxno'] ?? '').toString().trim();

        if (name.isNotEmpty) {
          final idKey = '$name|$skuid';
          if (!seenIdentifiers.contains(idKey)) {
            seenIdentifiers.add(idKey);
            results.add({
              'name': name,
              'skuid': skuid,
              'category': cat,
              'stock': stock,
              'boxno': boxno,
              'display': skuid.isNotEmpty ? '$name ($skuid)' : name,
            });
          }
        }
      }
    }

    return results;
  }

  // Search component names across all 7 inventory tables for autocomplete suggestions
  Future<List<String>> searchComponentNames(String query) async {
    final list = await searchLiveComponents(query);
    return list.map((item) => item['display'] as String).toList();
  }

  // Fetch all fines with full enrichment for spreadsheet/table layout:
  // Name | Mobile Number | Component | Qty | Class | Issue Date | Return Date | Fine
  Future<List<FineModel>> getAllFines({bool forceRefresh = false}) async {
    // 1. Check in-memory cache first
    if (!forceRefresh && _cache != null && _cache!.hasData(tableName)) {
      return _cache!.get<FineModel>(tableName)!;
    }

    try {
      final response = await _supabase
          .from(tableName)
          .select()
          .order('created_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      List<FineModel> fines = data.map((json) {
        final fine = FineModel.fromJson(json);
        final normalizedStatus =
            (fine.status.isEmpty || fine.status == 'pending') ? 'due' : fine.status;
        return fine.copyWith(status: normalizedStatus);
      }).toList();

      // Gather member IDs for enrichment
      final memberIds =
          fines.map((f) => f.memberId).where((id) => id.isNotEmpty).toSet().toList();

      // Fetch Members data for Name, Phone, Email, Division
      final Map<String, Map<String, String>> memberInfoMap = {};
      if (memberIds.isNotEmpty) {
        try {
          final membersResponse = await _supabase
              .from('Members')
              .select();

          for (var m in membersResponse as List<dynamic>) {
            final id = m['ISA Login ID']?.toString();
            if (id != null) {
              memberInfoMap[id] = {
                'name': m['Name']?.toString() ?? '',
                'email': m['Email Id']?.toString() ?? '',
                'phone': m['Phone Number']?.toString() ?? '',
                'class': m['Division']?.toString() ?? '',
              };
            }
          }
        } catch (_) {}
      }

      // Fetch Transactions data for Component items, Qty, Issue Date, Return Date, Class, Phone
      final Map<String, Map<String, dynamic>> txInfoMap = {};
      try {
        final txResponse = await _supabase.from('Transactions').select();
        for (var tx in txResponse as List<dynamic>) {
          final txId = tx['transaction_id']?.toString() ?? '';
          final memberId = tx['id']?.toString() ?? '';

          String compSummary = '';
          int totalQty = 0;
          try {
            var packageRaw = tx['package'];
            List<dynamic> pkgList = [];
            if (packageRaw is String) {
              pkgList = jsonDecode(packageRaw);
            } else if (packageRaw is List) {
              pkgList = packageRaw;
            }

            if (pkgList.isNotEmpty) {
              final names = <String>[];
              for (var p in pkgList) {
                final cName =
                    p['compname']?.toString() ?? p['name']?.toString() ?? 'Component';
                final qty = int.tryParse(
                        p['Quantity']?.toString() ?? p['quantity']?.toString() ?? '1') ??
                    1;
                totalQty += qty;
                names.add('$cName (Qty: $qty)');
              }
              compSummary = names.join(', ');
            }
          } catch (_) {}

          final txData = {
            'name': tx['name']?.toString(),
            'phone': tx['phonenumber']?.toString(),
            'class': tx['class']?.toString(),
            'component': compSummary,
            'qty': totalQty > 0 ? totalQty : 1,
            'issueDate': tx['issuedate']?.toString(),
            'returnDate': tx['returndate']?.toString(),
          };

          if (txId.isNotEmpty) {
            txInfoMap[txId] = txData;
          }
          if (memberId.isNotEmpty && !txInfoMap.containsKey(memberId)) {
            txInfoMap[memberId] = txData;
          }
        }
      } catch (_) {}

      // Enrich fines with all fields
      fines = fines.map((fine) {
        final memberInfo = memberInfoMap[fine.memberId];
        final txInfo = (fine.transactionId != null ? txInfoMap[fine.transactionId!] : null) ??
            txInfoMap[fine.memberId];

        final resolvedName = fine.memberName ?? memberInfo?['name'] ?? txInfo?['name'];
        final resolvedEmail = fine.memberEmail ?? memberInfo?['email'];
        final resolvedPhone = fine.phoneNumber ?? memberInfo?['phone'] ?? txInfo?['phone'];
        final resolvedClass = fine.className ?? memberInfo?['class'] ?? txInfo?['class'];
        final resolvedComponent =
            fine.componentName ?? txInfo?['component'] ?? fine.reason;
        final resolvedQty = fine.quantity ?? (txInfo?['qty'] as int?) ?? 1;
        final resolvedIssueDate = fine.issueDate ?? txInfo?['issueDate'];
        final now = DateTime.now();
        final formattedSystemDate = '${now.day}/${now.month}/${now.year}';

        final rawReturnDate = fine.returnDate ?? txInfo?['returnDate'];
        final resolvedReturnDate = (rawReturnDate != null &&
                rawReturnDate.isNotEmpty &&
                rawReturnDate.toLowerCase() != 'soon' &&
                rawReturnDate.toLowerCase() != 'pending')
            ? rawReturnDate
            : formattedSystemDate;

        return fine.copyWith(
          memberName: resolvedName,
          memberEmail: resolvedEmail,
          phoneNumber: resolvedPhone,
          className: resolvedClass,
          componentName: resolvedComponent,
          quantity: resolvedQty,
          issueDate: resolvedIssueDate,
          returnDate: resolvedReturnDate,
        );
      }).toList();

      // 3. Store in cache
      _cache?.set<FineModel>(tableName, fines);

      return fines;
    } catch (_) {
      return [];
    }
  }

  // Update fine status to paid (supports both fine_id and id primary keys)
  Future<bool> markFineAsPaid({
    required String fineId,
    required String paidBy,
  }) async {
    final updateData = {
      'status': 'paid',
      'paid_by': paidBy,
      'paid_at': DateTime.now().toIso8601String(),
    };

    try {
      await _supabase.from(tableName).update(updateData).eq('fine_id', fineId);
      _cache?.invalidate(tableName);
      return true;
    } catch (_) {
      try {
        await _supabase.from(tableName).update(updateData).eq('id', fineId);
        _cache?.invalidate(tableName);
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  // Update fine status to due (supports both fine_id and id primary keys)
  Future<bool> markFineAsDue({
    required String fineId,
  }) async {
    final updateData = {
      'status': 'due',
      'paid_by': null,
      'paid_at': null,
    };

    try {
      await _supabase.from(tableName).update(updateData).eq('fine_id', fineId);
      _cache?.invalidate(tableName);
      return true;
    } catch (_) {
      try {
        await _supabase.from(tableName).update(updateData).eq('id', fineId);
        _cache?.invalidate(tableName);
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  // Create a new fine (fetches member ID from Members table if email is provided, and saves member_id into Fines table)
  Future<String?> createFine(FineModel fine) async {
    try {
      String resolvedMemberId = fine.memberId.trim();

      // If memberId is an email address or if memberEmail is provided, look up ISA Login ID
      if (resolvedMemberId.contains('@') ||
          (fine.memberEmail != null && fine.memberEmail!.isNotEmpty) ||
          resolvedMemberId.isEmpty) {
        final emailToLookup = resolvedMemberId.contains('@')
            ? resolvedMemberId
            : (fine.memberEmail ?? resolvedMemberId);
        final memberInfo = await getMemberByEmailOrId(emailToLookup);
        if (memberInfo != null && memberInfo['member_id'] != null && memberInfo['member_id']!.isNotEmpty) {
          resolvedMemberId = memberInfo['member_id']!;
        }
      }

      if (resolvedMemberId.isEmpty) {
        return 'Could not determine Member ID. Please check the email or member ID.';
      }

      final payload = <String, dynamic>{
        'member_id': resolvedMemberId,
        'reason': fine.reason.isNotEmpty ? fine.reason : 'Late Return / Damage',
        'amount': fine.amount,
        'status': fine.status.isNotEmpty ? fine.status : 'due',
      };

      if (fine.transactionId != null && fine.transactionId!.isNotEmpty) {
        payload['transaction_id'] = fine.transactionId;
      }
      if (fine.createdBy != null && fine.createdBy!.isNotEmpty) {
        payload['created_by'] = fine.createdBy;
      }
      if (fine.notes != null && fine.notes!.isNotEmpty) {
        payload['notes'] = fine.notes;
      }
      if (fine.isPaid) {
        payload['paid_by'] = fine.paidBy;
        payload['paid_at'] = fine.paidAt ?? DateTime.now().toIso8601String();
      }

      await _supabase.from(tableName).insert(payload);
      _cache?.invalidate(tableName);
      return null; // Success
    } catch (e) {
      return e.toString();
    }
  }

  // Fetch fines for a specific transaction ID
  Future<List<FineModel>> getFinesByTransactionId(String transactionId) async {
    try {
      final response = await _supabase
          .from(tableName)
          .select()
          .eq('transaction_id', transactionId);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => FineModel.fromJson(json)).toList();
    } catch (_) {
      return [];
    }
  }

  // Delete a fine from database (supports both fine_id and id primary keys)
  Future<bool> deleteFine(String fineId) async {
    try {
      await _supabase.from(tableName).delete().eq('fine_id', fineId);
      _cache?.invalidate(tableName);
      return true;
    } catch (_) {
      try {
        await _supabase.from(tableName).delete().eq('id', fineId);
        _cache?.invalidate(tableName);
        return true;
      } catch (_) {
        return false;
      }
    }
  }
}
