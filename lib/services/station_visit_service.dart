// services/station_visit_service.dart (Version adaptée à votre Supabase)
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class StationVisitService {
  static bool _isInitialized = false;
  static bool _supabaseReady = false;

  // Accès rapide au client Supabase
  static SupabaseClient get _supabase => Supabase.instance.client;

  /// Initialisation du service avec détection automatique des tables
  static Future<void> initialize() async {
    if (_isInitialized) {
      print('✅ Service Supabase déjà initialisé');
      return;
    }

    try {
      print('🔄 Vérification structure Supabase...');

      // Test de connectivité et détection des tables
      await _detectAndCreateTables();

      _supabaseReady = true;
      _isInitialized = true;
      print('✅ Service Supabase opérationnel');
    } catch (e) {
      print('❌ Erreur initialisation Supabase: $e');
      _supabaseReady = false;
      _isInitialized = false;
      throw Exception('Supabase non disponible: $e');
    }
  }

  /// Détecter les tables existantes et créer celles manquantes
  static Future<void> _detectAndCreateTables() async {
    try {
      print('🔍 Détection des tables existantes...');

      // Tester d'abord la table users basique
      bool usersExists = await _tableExists('users');
      bool stationVisitsExists = await _tableExists('station_visits');

      print('📋 Tables détectées:');
      print('  - users: ${usersExists ? "✅" : "❌"}');
      print('  - station_visits: ${stationVisitsExists ? "✅" : "❌"}');

      // Créer les tables manquantes avec structure simple
      if (!usersExists) {
        await _createUsersTable();
      }

      if (!stationVisitsExists) {
        await _createStationVisitsTable();
      }

      // Vérifier/ajouter les colonnes manquantes
      await _ensureUserColumns();
    } catch (e) {
      print('⚠️ Erreur détection tables: $e');
      // Continuer même en cas d'erreur de détection
    }
  }

  /// Vérifier si une table existe
  static Future<bool> _tableExists(String tableName) async {
    try {
      await _supabase.from(tableName).select('*').limit(1);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Créer la table users si elle n'existe pas
  static Future<void> _createUsersTable() async {
    try {
      print('🏗️ Création table users...');
      await _supabase.rpc('create_users_table_if_not_exists');
    } catch (e) {
      print('⚠️ Impossible de créer automatiquement la table users: $e');
    }
  }

  /// Créer la table station_visits si elle n'existe pas
  static Future<void> _createStationVisitsTable() async {
    try {
      print('🏗️ Création table station_visits...');
      await _supabase.rpc('create_station_visits_table_if_not_exists');
    } catch (e) {
      print(
          '⚠️ Impossible de créer automatiquement la table station_visits: $e');
    }
  }

  /// S'assurer que la table users a les bonnes colonnes
  static Future<void> _ensureUserColumns() async {
    try {
      // Tenter d'insérer un utilisateur par défaut avec toutes les colonnes
      await _supabase.from('users').upsert({
        'id': 1,
        'username': 'user_default',
        'email': 'user@carburapp.com',
        'stations_visited_count': 0,
      }, onConflict: 'id');
    } catch (e) {
      print('⚠️ Structure users peut-être différente: $e');
    }
  }

  /// Marquer une visite de station (avec gestion d'erreurs)
  static Future<void> markStationVisit({
    required String stationId,
    required String stationName,
    required String stationBrand,
    required double latitude,
    required double longitude,
    int userId = 1,
    String? notes,
  }) async {
    try {
      if (!_supabaseReady) {
        await initialize();
      }

      // Essayer d'insérer la visite avec structure flexible
      final visitData = {
        'user_id': userId,
        'station_id': stationId,
        'station_name': stationName,
        'station_brand': stationBrand ?? '',
        'latitude': latitude,
        'longitude': longitude,
        'visit_date': DateTime.now().toIso8601String(),
        'notes': notes ?? '',
        'created_at': DateTime.now().toIso8601String(),
      };

      await _supabase.from('station_visits').insert(visitData);

      // Essayer de mettre à jour le compteur utilisateur
      try {
        await _updateUserVisitCount(userId);
      } catch (e) {
        print('⚠️ Impossible de mettre à jour le compteur: $e');
      }

      print('✅ Visite sauvée: $stationName');
    } catch (e) {
      print('❌ Erreur sauvegarde visite: $e');
      throw Exception('Impossible de sauvegarder la visite: $e');
    }
  }

  /// Mettre à jour le compteur de visites (avec fallback)
  static Future<void> _updateUserVisitCount(int userId) async {
    try {
      // Méthode 1: Incrément direct
      await _supabase.rpc('increment_user_visits', params: {'user_id': userId});
    } catch (e1) {
      try {
        // Méthode 2: Update manuel
        await _supabase.from('users').update({
          'stations_visited_count': 'stations_visited_count + 1'
        }).eq('id', userId);
      } catch (e2) {
        try {
          // Méthode 3: Recalcul complet
          final visitsCount = await _supabase
              .from('station_visits')
              .select('id')
              .eq('user_id', userId);

          await _supabase.from('users').update(
              {'stations_visited_count': visitsCount.length}).eq('id', userId);
        } catch (e3) {
          print('⚠️ Impossible de mettre à jour le compteur: $e3');
        }
      }
    }
  }

  /// Obtenir le nombre de stations visitées (avec fallback)
  static Future<int> getUserStationsVisitedCount([int userId = 1]) async {
    try {
      if (!_supabaseReady) {
        await initialize();
      }

      // Méthode 1: Depuis la table users
      try {
        final response = await _supabase
            .from('users')
            .select('stations_visited_count')
            .eq('id', userId)
            .maybeSingle();

        if (response != null && response['stations_visited_count'] != null) {
          return response['stations_visited_count'] as int;
        }
      } catch (e) {
        print('⚠️ Erreur lecture compteur users: $e');
      }

      // Méthode 2: Compter directement dans station_visits
      try {
        final visits = await _supabase
            .from('station_visits')
            .select('id')
            .eq('user_id', userId);
        return visits.length;
      } catch (e) {
        print('⚠️ Erreur comptage visits: $e');
      }

      return 0;
    } catch (e) {
      print('❌ Erreur compteur: $e');
      return 0;
    }
  }

  /// Obtenir l'historique des visites (avec gestion d'erreurs)
  static Future<List<Map<String, dynamic>>> getUserVisitHistory([
    int userId = 1,
    int? limit,
  ]) async {
    try {
      if (!_supabaseReady) {
        await initialize();
      }

      var query = _supabase
          .from('station_visits')
          .select('*')
          .eq('user_id', userId)
          .order('visit_date', ascending: false);

      if (limit != null && limit > 0) {
        query = query.limit(limit);
      }

      final response = await query;
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Erreur historique: $e');
      return [];
    }
  }

  /// Obtenir les statistiques utilisateur (robuste)
  static Future<Map<String, dynamic>> getUserStats([int userId = 1]) async {
    try {
      if (!_supabaseReady) {
        await initialize();
      }

      // Compteur total
      final totalCount = await getUserStationsVisitedCount(userId);

      // Récupérer toutes les visites pour calculer les stats
      final allVisits = await getUserVisitHistory(userId);

      // Calculer les stations uniques
      final uniqueStations =
          allVisits.map((visit) => visit['station_id']).toSet().length;

      // Calculer la marque la plus visitée
      final brandCounts = <String, int>{};
      for (final visit in allVisits) {
        final brand = visit['station_brand'] as String? ?? '';
        if (brand.isNotEmpty) {
          brandCounts[brand] = (brandCounts[brand] ?? 0) + 1;
        }
      }

      String? topBrand;
      if (brandCounts.isNotEmpty) {
        topBrand =
            brandCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      }

      // Dernière visite
      String? lastVisit;
      if (allVisits.isNotEmpty) {
        lastVisit = allVisits.first['visit_date'] as String?;
      }

      return {
        'total_visits': totalCount,
        'unique_stations': uniqueStations,
        'top_brand': topBrand,
        'last_visit': lastVisit,
        'data_source': 'supabase',
      };
    } catch (e) {
      print('❌ Erreur stats: $e');
      return {
        'total_visits': 0,
        'unique_stations': 0,
        'top_brand': null,
        'last_visit': null,
        'data_source': 'error',
      };
    }
  }

  /// Obtenir les stations les plus visitées (fallback manuel)
  static Future<List<Map<String, dynamic>>> getTopVisitedStations([
    int userId = 1,
    int limit = 5,
  ]) async {
    try {
      final visits = await getUserVisitHistory(userId);

      // Grouper par station
      final stationCounts = <String, Map<String, dynamic>>{};

      for (final visit in visits) {
        final stationId = visit['station_id'] as String;

        if (stationCounts.containsKey(stationId)) {
          stationCounts[stationId]!['visit_count'] =
              (stationCounts[stationId]!['visit_count'] as int) + 1;
        } else {
          stationCounts[stationId] = {
            'station_id': stationId,
            'station_name': visit['station_name'],
            'station_brand': visit['station_brand'],
            'visit_count': 1,
            'last_visit': visit['visit_date'],
          };
        }
      }

      // Trier et limiter
      final sortedStations = stationCounts.values.toList()
        ..sort((a, b) =>
            (b['visit_count'] as int).compareTo(a['visit_count'] as int));

      return sortedStations.take(limit).toList();
    } catch (e) {
      print('❌ Erreur top stations: $e');
      return [];
    }
  }

  /// Vérifier si une station a été visitée aujourd'hui
  static Future<bool> hasVisitedStationToday(
    String stationId, [
    int userId = 1,
  ]) async {
    try {
      if (!_supabaseReady) {
        await initialize();
      }

      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

      final response = await _supabase
          .from('station_visits')
          .select('id')
          .eq('user_id', userId)
          .eq('station_id', stationId)
          .gte('visit_date', startOfDay.toIso8601String())
          .lte('visit_date', endOfDay.toIso8601String())
          .limit(1);

      return response.isNotEmpty;
    } catch (e) {
      print('❌ Erreur vérification visite: $e');
      return false;
    }
  }

  /// Rechercher dans l'historique des visites
  static Future<List<Map<String, dynamic>>> searchVisitHistory(
    String searchTerm, [
    int userId = 1,
  ]) async {
    try {
      if (!_supabaseReady) {
        await initialize();
      }

      final response = await _supabase
          .from('station_visits')
          .select('*')
          .eq('user_id', userId)
          .or('station_name.ilike.%$searchTerm%,station_brand.ilike.%$searchTerm%,notes.ilike.%$searchTerm%')
          .order('visit_date', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Erreur recherche: $e');
      return [];
    }
  }

  /// Obtenir les visites récentes
  static Future<List<Map<String, dynamic>>> getRecentVisits([
    int userId = 1,
  ]) async {
    try {
      final weekAgo = DateTime.now().subtract(Duration(days: 7));

      final response = await _supabase
          .from('station_visits')
          .select('*')
          .eq('user_id', userId)
          .gte('visit_date', weekAgo.toIso8601String())
          .order('visit_date', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Erreur visites récentes: $e');
      return [];
    }
  }

  /// Réinitialiser toutes les données
  static Future<void> resetAllData([int userId = 1]) async {
    try {
      if (!_supabaseReady) {
        await initialize();
      }

      // Supprimer toutes les visites
      await _supabase.from('station_visits').delete().eq('user_id', userId);

      // Remettre le compteur à zéro (si possible)
      try {
        await _supabase
            .from('users')
            .update({'stations_visited_count': 0}).eq('id', userId);
      } catch (e) {
        print('⚠️ Impossible de remettre le compteur à zéro: $e');
      }

      print('✅ Données réinitialisées pour l\'utilisateur $userId');
    } catch (e) {
      print('❌ Erreur reset: $e');
      throw Exception('Impossible de réinitialiser les données: $e');
    }
  }

  /// Vérifier l'état de la connexion Supabase
  static Future<bool> isDatabaseReady() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }
      return _supabaseReady;
    } catch (e) {
      print('❌ Supabase non prêt: $e');
      return false;
    }
  }

  /// Obtenir des informations de diagnostic
  static Future<Map<String, dynamic>> getDiagnosticInfo() async {
    try {
      // Tester les tables
      bool usersExists = await _tableExists('users');
      bool stationVisitsExists = await _tableExists('station_visits');

      return {
        'timestamp': DateTime.now().toIso8601String(),
        'is_initialized': _isInitialized,
        'supabase_ready': _supabaseReady,
        'platform': kIsWeb ? 'Web' : 'Mobile/Desktop',
        'storage_type': 'Supabase Cloud',
        'supabase_url': Supabase.instance.client.supabaseUrl,
        'tables_exist': {
          'users': usersExists,
          'station_visits': stationVisitsExists,
        },
        'auth_status': Supabase.instance.client.auth.currentUser != null
            ? 'authenticated'
            : 'anonymous',
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
        'is_initialized': _isInitialized,
        'supabase_ready': false,
        'platform': kIsWeb ? 'Web' : 'Mobile/Desktop',
      };
    }
  }

  /// Tests complets du service (avec gestion d'erreurs)
  static Future<List<String>> runFullTest() async {
    List<String> results = [];

    try {
      results.add('🔍 Tests du service Supabase adaptatif...');

      // Test 1: Initialisation
      try {
        await initialize();
        results.add('✅ Initialisation OK');
      } catch (e) {
        results.add('❌ Initialisation échouée: $e');
        return results;
      }

      // Test 2: Détection des tables
      final diagnostics = await getDiagnosticInfo();
      final tablesInfo = diagnostics['tables_exist'] as Map<String, dynamic>?;
      if (tablesInfo != null) {
        results.add('📋 Tables détectées:');
        results.add('  - users: ${tablesInfo['users'] ? "✅" : "❌"}');
        results.add(
            '  - station_visits: ${tablesInfo['station_visits'] ? "✅" : "❌"}');
      }

      // Test 3: Test d'écriture
      try {
        final testStationId = 'test_${DateTime.now().millisecondsSinceEpoch}';
        await markStationVisit(
          stationId: testStationId,
          stationName: 'Station Test Adaptatif',
          stationBrand: 'TestAdaptatif',
          latitude: 48.8566,
          longitude: 2.3522,
          notes: 'Test avec service adaptatif',
        );
        results.add('✅ Écriture OK');
      } catch (e) {
        results.add('❌ Erreur écriture: $e');
      }

      // Test 4: Test de lecture
      try {
        final stats = await getUserStats();
        results.add('✅ Lecture OK: ${stats['total_visits']} visites');
      } catch (e) {
        results.add('❌ Erreur lecture: $e');
      }

      // Test 5: Test historique
      try {
        final history = await getUserVisitHistory(1, 5);
        results.add('✅ Historique OK: ${history.length} entrées récentes');
      } catch (e) {
        results.add('❌ Erreur historique: $e');
      }

      results.add('🎉 Tests terminés!');
    } catch (e) {
      results.add('❌ Erreur générale des tests: $e');
    }

    return results;
  }

  /// Exporter les données utilisateur
  static Future<Map<String, dynamic>> exportUserData([int userId = 1]) async {
    try {
      final stats = await getUserStats(userId);
      final history = await getUserVisitHistory(userId);
      final topStations = await getTopVisitedStations(userId, 10);

      return {
        'export_date': DateTime.now().toIso8601String(),
        'user_id': userId,
        'statistics': stats,
        'visit_history': history,
        'top_stations': topStations,
        'total_visits': history.length,
        'service_version': 'adaptive_supabase_v1',
      };
    } catch (e) {
      print('❌ Erreur export: $e');
      return {'error': e.toString()};
    }
  }
}
