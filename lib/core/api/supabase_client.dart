import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String url = 'https://gkarotahjtyvmhjqejts.supabase.co';
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdrYXJvdGFoanR5dm1oanFlanRzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ2MDQyMTYsImV4cCI6MjA5MDE4MDIxNn0.wtLB6lMFV3nWx-KUMVNoLszSjGfA7-Kttmzvw_xZy9Q';
}

class SupabaseClientManager {
  static final SupabaseClientManager _instance = SupabaseClientManager._internal();
  factory SupabaseClientManager() => _instance;
  SupabaseClientManager._internal();

  late final SupabaseClient client;

  Future<void> init() async {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
    );
    client = Supabase.instance.client;
  }
}
