import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RealtimeInventoryService {
  final supabase = Supabase.instance.client;

  RealtimeChannel subscribe(
    String tableName,
    VoidCallback callback,
  ) {
    return supabase
        .channel(tableName)
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: tableName,
          callback: (_) {
            callback();
          },
        )
        .subscribe();
  }
}