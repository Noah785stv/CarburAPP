// services/station_visit_service.dart (Version corrigée)
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io';

class StationVisitService {
  static Database? _database;
  static const String _tableName = 'station_visits';
  static const String _usersTableName = 'users';

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    try {
      String path = join(await getDatabasesPath(), 'gas_stations.db');

      return await openDatabase(
        path,
        version: 1,
        onCreate: (db, version) async {
          // Table pour les utilisateurs avec compteur de visites
          await db.execute('''
            CREATE TABLE $_usersTableName(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              username TEXT NOT NULL,
              email TEXT,
              stations_visited_count INTEGER DEFAULT 0,
              created_at TEXT DEFAULT CURRENT_TIMESTAMP
            )
          ''');

          // Table pour enregistrer chaque visite de station
          await db.execute('''
            CREATE TABLE $_tableName(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              user_id INTEGER,
              station_id TEXT NOT NULL,
              station_name TEXT NOT NULL,
              station_brand TEXT,
              latitude REAL NOT NULL,
              longitude REAL NOT NULL,
              visit_date TEXT DEFAULT CURRENT_TIMESTAMP,
              notes TEXT,
              FOREIGN KEY (user_id) REFERENCES $_usersTableName (id)
            )
          ''');

          // Insérer un utilisateur par défaut
          await db.insert(_usersTableName, {
            'username': 'user_default',
            'email': 'user@example.com',
            'stations_visited_count': 0,
          });

          print('✅ Base de données initialisée avec succès');
        },
        onOpen: (db) {
          print('✅ Base de données ouverte');
        },
      );
    } catch (e) {
      print('❌ Erreur lors de l\'initialisation de la base de données: $e');
      rethrow;
    }
  }

  /// Marquer qu'on vient de passer dans une station
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
      final db = await database;

      await db.transaction((txn) async {
        // Enregistrer la visite
        await txn.insert(_tableName, {
          'user_id': userId,
          'station_id': stationId,
          'station_name': stationName,
          'station_brand': stationBrand,
          'latitude': latitude,
          'longitude': longitude,
          'visit_date': DateTime.now().toIso8601String(),
          'notes': notes,
        });

        // Incrémenter le compteur de l'utilisateur
        await txn.rawUpdate(
          '''
          UPDATE $_usersTableName 
          SET stations_visited_count = stations_visited_count + 1 
          WHERE id = ?
        ''',
          [userId],
        );
      });

      print('✅ Visite de station enregistrée: $stationName');
    } catch (e) {
      print('❌ Erreur lors de l\'enregistrement de la visite: $e');
      throw Exception('Erreur lors de l\'enregistrement: ${e.toString()}');
    }
  }

  /// Obtenir le nombre total de stations visitées par un utilisateur
  static Future<int> getUserStationsVisitedCount([int userId = 1]) async {
    try {
      final db = await database;

      final result = await db.query(
        _usersTableName,
        columns: ['stations_visited_count'],
        where: 'id = ?',
        whereArgs: [userId],
      );

      if (result.isNotEmpty) {
        return result.first['stations_visited_count'] as int? ?? 0;
      }
      return 0;
    } catch (e) {
      print('❌ Erreur lors de la récupération du compteur: $e');
      return 0;
    }
  }

  /// Obtenir l'historique des visites d'un utilisateur
  static Future<List<Map<String, dynamic>>> getUserVisitHistory([
    int userId = 1,
  ]) async {
    try {
      final db = await database;

      final result = await db.query(
        _tableName,
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'visit_date DESC',
      );

      return result;
    } catch (e) {
      print('❌ Erreur lors de la récupération de l\'historique: $e');
      return [];
    }
  }

  /// Vérifier si une station a déjà été visitée aujourd'hui
  static Future<bool> hasVisitedStationToday(
    String stationId, [
    int userId = 1,
  ]) async {
    try {
      final db = await database;

      final today = DateTime.now();
      final startOfDay =
          DateTime(today.year, today.month, today.day).toIso8601String();
      final endOfDay =
          DateTime(
            today.year,
            today.month,
            today.day,
            23,
            59,
            59,
          ).toIso8601String();

      final result = await db.query(
        _tableName,
        where: 'user_id = ? AND station_id = ? AND visit_date BETWEEN ? AND ?',
        whereArgs: [userId, stationId, startOfDay, endOfDay],
      );

      return result.isNotEmpty;
    } catch (e) {
      print('❌ Erreur lors de la vérification: $e');
      return false;
    }
  }

  /// Obtenir les statistiques de l'utilisateur
  static Future<Map<String, dynamic>> getUserStats([int userId = 1]) async {
    try {
      final db = await database;

      // Compteur total
      final totalCount = await getUserStationsVisitedCount(userId);

      // Stations uniques visitées
      final uniqueStationsResult = await db.rawQuery(
        '''
        SELECT COUNT(DISTINCT station_id) as unique_count 
        FROM $_tableName 
        WHERE user_id = ?
      ''',
        [userId],
      );

      final uniqueStations =
          uniqueStationsResult.first['unique_count'] as int? ?? 0;

      // Marque la plus visitée
      final topBrandResult = await db.rawQuery(
        '''
        SELECT station_brand, COUNT(*) as count 
        FROM $_tableName 
        WHERE user_id = ? AND station_brand != '' 
        GROUP BY station_brand 
        ORDER BY count DESC 
        LIMIT 1
      ''',
        [userId],
      );

      final topBrand =
          topBrandResult.isNotEmpty
              ? topBrandResult.first['station_brand'] as String?
              : null;

      return {
        'total_visits': totalCount,
        'unique_stations': uniqueStations,
        'top_brand': topBrand,
      };
    } catch (e) {
      print('❌ Erreur lors de la récupération des statistiques: $e');
      return {'total_visits': 0, 'unique_stations': 0, 'top_brand': null};
    }
  }

  /// Réinitialiser toutes les données (pour les tests)
  static Future<void> resetAllData() async {
    try {
      final db = await database;

      await db.transaction((txn) async {
        await txn.delete(_tableName);
        await txn.update(
          _usersTableName,
          {'stations_visited_count': 0},
          where: 'id = ?',
          whereArgs: [1],
        );
      });

      print('✅ Toutes les données ont été réinitialisées');
    } catch (e) {
      print('❌ Erreur lors de la réinitialisation: $e');
    }
  }

  /// Vérifier l'état de la base de données
  static Future<bool> isDatabaseReady() async {
    try {
      final db = await database;
      final result = await db.rawQuery('SELECT 1');
      return result.isNotEmpty;
    } catch (e) {
      print('❌ Base de données non prête: $e');
      return false;
    }
  }
}
