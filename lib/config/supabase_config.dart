// lib/config/supabase_config.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  // ⚠️ REMPLACEZ CES VALEURS PAR LES VÔTRES depuis le dashboard Supabase
  static const String supabaseUrl = 'https://wutkoucfufkobaeyrjqp.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind1dGtvdWNmdWZrb2JhZXlyanFwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDk1OTM5MjAsImV4cCI6MjA2NTE2OTkyMH0.vsS8X8dV7FBAotkmV_uSWEfRxq0LXArBPwsOLV0gL0M'; // clé anon

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
      realtimeClientOptions: const RealtimeClientOptions(
        logLevel: RealtimeLogLevel.info,
      ),
      storageOptions: const StorageClientOptions(retryAttempts: 10),
    );
  }
}

// Getter global pour accéder facilement à Supabase
final supabase = Supabase.instance.client;
