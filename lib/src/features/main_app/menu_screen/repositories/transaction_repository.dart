import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/transaction_model.dart';

class TransactionRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<TransactionModel>> fetchTransactions() async {
    try {
      // Fetch transactions
      final fetchedPackage = await _supabase.from('Transactions').select();
      final List<TransactionModel> transactions = [];

      for (var item in fetchedPackage) {
        try {
          // Create transaction model from JSON
          TransactionModel transaction = TransactionModel.fromJson(item);

          // Fetch profile image if ID exists
          String? imageUrl;
          if (item['id'] != null) {
            final profileData = await _supabase
                .from('profiles')
                .select('profile_image_url')
                .eq('member_id', item['id'].toString())
                .maybeSingle();

            imageUrl = profileData?['profile_image_url']?.toString();
          }

          // Add transaction with profile image
          transactions.add(transaction.copyWith(profileImageUrl: imageUrl));
        } catch (e) {
          // Add transaction without profile image on error
          transactions.add(TransactionModel.fromJson(item));
        }
      }

      return transactions;
    } catch (e) {
      throw Exception('Failed to fetch transactions: $e');
    }
  }

  Future<String?> fetchProfileImage(String memberId) async {
    try {
      final profileData = await _supabase
          .from('profiles')
          .select('profile_image_url')
          .eq('member_id', memberId)
          .maybeSingle();

      return profileData?['profile_image_url']?.toString();
    } catch (e) {
      return null;
    }
  }
}
