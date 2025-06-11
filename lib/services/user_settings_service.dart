// lib/services/user_settings_service.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import 'auth_service.dart';

class UserSettingsService extends ChangeNotifier {
  static final UserSettingsService _instance = UserSettingsService._internal();
  factory UserSettingsService() => _instance;
  UserSettingsService._internal();

  // Cache des paramètres pour éviter de refaire des requêtes
  static Map<String, String> _cachedSettings = {};
  static DateTime? _lastCacheUpdate;
  static const Duration _cacheExpiry = Duration(minutes: 5);

  /// Récupérer un paramètre utilisateur spécifique
  static Future<String?> getUserSetting(
    String settingKey, {
    String? defaultValue,
  }) async {
    try {
      final currentUser = AuthService.getCurrentUser();
      if (currentUser == null) {
        return defaultValue;
      }

      // Vérifier le cache
      if (_cachedSettings.containsKey(settingKey) &&
          _lastCacheUpdate != null &&
          DateTime.now().difference(_lastCacheUpdate!) < _cacheExpiry) {
        return _cachedSettings[settingKey];
      }

      // Récupérer depuis la base de données
      final setting = await _fetchUserSetting(currentUser.id, settingKey);

      // Mettre en cache
      if (setting != null) {
        _cachedSettings[settingKey] = setting;
        _lastCacheUpdate = DateTime.now();
      }

      return setting ?? defaultValue;
    } catch (e) {
      print('Erreur lors de la récupération du paramètre $settingKey: $e');
      return defaultValue;
    }
  }

  /// Récupérer le rayon de recherche de l'utilisateur
  static Future<double> getSearchRadius() async {
    try {
      final radiusStr = await getUserSetting(
        'search_radius',
        defaultValue: '5',
      );
      return double.tryParse(radiusStr ?? '5') ?? 5.0;
    } catch (e) {
      print('Erreur lors de la récupération du rayon de recherche: $e');
      return 5.0; // Valeur par défaut
    }
  }

  /// Récupérer le carburant préféré de l'utilisateur
  static Future<String> getPreferredFuelType() async {
    try {
      final currentUser = AuthService.getCurrentUser();
      if (currentUser == null) return 'SP95';

      // D'abord essayer depuis le profil utilisateur
      final userProfile =
          await supabase
              .from('users')
              .select('preferred_fuel_type')
              .eq('id', currentUser.id)
              .maybeSingle();

      if (userProfile != null && userProfile['preferred_fuel_type'] != null) {
        return userProfile['preferred_fuel_type'];
      }

      // Sinon essayer depuis les paramètres
      final fuelType = await getUserSetting(
        'preferred_fuel_type',
        defaultValue: 'SP95',
      );
      return fuelType ?? 'SP95';
    } catch (e) {
      print('Erreur lors de la récupération du carburant préféré: $e');
      return 'SP95';
    }
  }

  /// Récupérer les notifications activées
  static Future<bool> getNotificationsEnabled() async {
    try {
      final notifStr = await getUserSetting(
        'notifications_enabled',
        defaultValue: 'true',
      );
      return notifStr?.toLowerCase() == 'true';
    } catch (e) {
      print('Erreur lors de la récupération des notifications: $e');
      return true;
    }
  }

  /// Méthode privée pour récupérer un paramètre depuis la BDD
  static Future<String?> _fetchUserSetting(
    String userId,
    String settingKey,
  ) async {
    try {
      // Récupérer l'ID du paramètre
      final settingRecord =
          await supabase
              .from('settings')
              .select('id, default_value')
              .eq('setting_key', settingKey)
              .eq('is_active', true)
              .maybeSingle();

      if (settingRecord == null) {
        print(
          'Paramètre $settingKey non trouvé dans les paramètres disponibles',
        );
        return null;
      }

      // Récupérer la valeur utilisateur
      final userSetting =
          await supabase
              .from('user_settings')
              .select('setting_value')
              .eq('user_id', userId)
              .eq('setting_id', settingRecord['id'])
              .maybeSingle();

      return userSetting?['setting_value']?.toString() ??
          settingRecord['default_value']?.toString();
    } catch (e) {
      print('Erreur lors de la récupération du paramètre $settingKey: $e');
      return null;
    }
  }

  /// Mettre à jour un paramètre utilisateur avec notification
  static Future<bool> updateUserSetting(
    String settingKey,
    String newValue,
  ) async {
    try {
      final currentUser = AuthService.getCurrentUser();
      if (currentUser == null) return false;

      // Récupérer l'ID du paramètre
      final settingRecord =
          await supabase
              .from('settings')
              .select('id')
              .eq('setting_key', settingKey)
              .single();

      final settingId = settingRecord['id'];

      // Vérifier si le paramètre utilisateur existe
      final existingSetting =
          await supabase
              .from('user_settings')
              .select('*')
              .eq('user_id', currentUser.id)
              .eq('setting_id', settingId)
              .maybeSingle();

      if (existingSetting != null) {
        // Mettre à jour
        await supabase
            .from('user_settings')
            .update({'setting_value': newValue})
            .eq('user_id', currentUser.id)
            .eq('setting_id', settingId);
      } else {
        // Créer
        await supabase.from('user_settings').insert({
          'user_id': currentUser.id,
          'setting_id': settingId,
          'setting_value': newValue,
        });
      }

      // Mettre à jour le cache
      _cachedSettings[settingKey] = newValue;

      // Notifier les listeners (pour synchronisation entre pages)
      _instance.notifyListeners();

      print('✅ Paramètre $settingKey mis à jour: $newValue');
      return true;
    } catch (e) {
      print('❌ Erreur lors de la mise à jour du paramètre $settingKey: $e');
      return false;
    }
  }

  /// Vider le cache (utile après déconnexion)
  static void clearCache() {
    _cachedSettings.clear();
    _lastCacheUpdate = null;
  }

  /// Forcer le rechargement du cache
  static Future<void> refreshCache() async {
    _cachedSettings.clear();
    _lastCacheUpdate = null;
    _instance.notifyListeners();
  }

  /// Écouter les changements de paramètres
  static UserSettingsService get instance => _instance;
}
