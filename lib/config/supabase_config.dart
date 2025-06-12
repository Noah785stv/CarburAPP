// lib/config/supabase_config.dart (Version corrigée)
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  // ⚠️ REMPLACEZ CES VALEURS PAR LES VÔTRES depuis le dashboard Supabase
  static const String supabaseUrl = 'https://wutkoucfufkobaeyrjqp.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind1dGtvdWNmdWZrb2JhZXlyanFwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDk1OTM5MjAsImV4cCI6MjA2NTE2OTkyMH0.vsS8X8dV7FBAotkmV_uSWEfRxq0LXArBPwsOLV0gL0M';

  static Future<void> initialize() async {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
        // Configuration simplifiée pour compatibilité
        debug: false, // Mettre à true pour voir les logs en développement
      );

      print('✅ Supabase initialisé avec succès');
    } catch (e) {
      print('❌ Erreur initialisation Supabase: $e');
      rethrow;
    }
  }

  // Méthode pour obtenir le client Supabase
  static SupabaseClient get client => Supabase.instance.client;

  // Méthode pour vérifier la connexion
  static Future<bool> isConnected() async {
    try {
      // Test simple de connectivité
      await client.from('users').select('count').limit(1);
      return true;
    } catch (e) {
      print('⚠️ Supabase non connecté: $e');
      return false;
    }
  }

  // Méthode pour obtenir des infos de diagnostic
  static Map<String, dynamic> getDiagnosticInfo() {
    try {
      return {
        'url': supabaseUrl,
        'is_initialized': Supabase.instance.client != null,
        'auth_user': Supabase.instance.client.auth.currentUser?.id,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }
}

// Getter global pour accéder facilement à Supabase
final supabase = Supabase.instance.client;
