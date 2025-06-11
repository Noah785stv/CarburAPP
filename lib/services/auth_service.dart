// lib/services/auth_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class AuthService {
  // Inscription avec email/mot de passe
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    String preferredFuelType = 'SP95',
  }) async {
    try {
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'phone': phone,
          'preferred_fuel_type': preferredFuelType,
        },
      );

      // Créer le profil utilisateur après inscription
      if (response.user != null) {
        await _createUserProfile(
          userId: response.user!.id,
          email: email,
          fullName: fullName,
          phone: phone,
          preferredFuelType: preferredFuelType,
        );
      }

      return response;
    } catch (e) {
      rethrow;
    }
  }

  // Connexion avec email/mot de passe
  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  // Déconnexion
  static Future<void> signOut() async {
    try {
      await supabase.auth.signOut();
    } catch (e) {
      rethrow;
    }
  }

  // Récupérer l'utilisateur actuel
  static User? getCurrentUser() {
    return supabase.auth.currentUser;
  }

  // Vérifier si l'utilisateur est connecté
  static bool isLoggedIn() {
    return supabase.auth.currentUser != null;
  }

  // Réinitialisation de mot de passe
  static Future<void> resetPassword(String email) async {
    try {
      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: 'https://votre-app.com/reset-password', // Optionnel
      );
    } catch (e) {
      rethrow;
    }
  }

  // Mettre à jour le profil utilisateur
  static Future<void> updateProfile({
    String? fullName,
    String? phone,
    String? preferredFuelType,
  }) async {
    try {
      final user = getCurrentUser();
      if (user == null) throw Exception('Utilisateur non connecté');

      // Mettre à jour les métadonnées d'auth
      final Map<String, dynamic> data = {};
      if (fullName != null) data['full_name'] = fullName;
      if (phone != null) data['phone'] = phone;
      if (preferredFuelType != null)
        data['preferred_fuel_type'] = preferredFuelType;

      if (data.isNotEmpty) {
        await supabase.auth.updateUser(UserAttributes(data: data));
      }

      // Mettre à jour la table users
      final Map<String, dynamic> updates = {};
      if (fullName != null) updates['full_name'] = fullName;
      if (phone != null) updates['phone'] = phone;
      if (preferredFuelType != null)
        updates['preferred_fuel_type'] = preferredFuelType;

      if (updates.isNotEmpty) {
        await supabase.from('users').update(updates).eq('id', user.id);
      }
    } catch (e) {
      rethrow;
    }
  }

  // Créer le profil utilisateur dans la table users
  static Future<void> _createUserProfile({
    required String userId,
    required String email,
    required String fullName,
    String? phone,
    String preferredFuelType = 'SP95',
  }) async {
    try {
      await supabase.from('users').insert({
        'id': userId,
        'email': email,
        'full_name': fullName,
        'phone': phone,
        'preferred_fuel_type': preferredFuelType,
      });
    } catch (e) {
      // Ne pas faire échouer l'inscription si la création du profil échoue
      print('Erreur lors de la création du profil: $e');
    }
  }

  // Récupérer le profil utilisateur complet
  static Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final user = getCurrentUser();
      if (user == null) return null;

      final response =
          await supabase.from('users').select().eq('id', user.id).single();

      return response;
    } catch (e) {
      print('Erreur lors de la récupération du profil: $e');
      return null;
    }
  }

  // Stream pour écouter les changements d'état d'authentification
  static Stream<AuthState> get authStateChanges {
    return supabase.auth.onAuthStateChange;
  }
}

// Classe pour les erreurs d'authentification personnalisées
class AuthException implements Exception {
  final String message;
  final String? code;

  AuthException(this.message, {this.code});

  @override
  String toString() => message;
}

// Helper pour gérer les erreurs Supabase
class AuthErrorHandler {
  static String getErrorMessage(dynamic error) {
    if (error is AuthException) {
      switch (error.message) {
        case 'Invalid login credentials':
          return 'Email ou mot de passe incorrect';
        case 'Email not confirmed':
          return 'Veuillez confirmer votre email';
        case 'User already registered':
          return 'Un compte existe déjà avec cet email';
        case 'Password should be at least 6 characters':
          return 'Le mot de passe doit contenir au moins 6 caractères';
        case 'Unable to validate email address: invalid format':
          return 'Format d\'email invalide';
        default:
          return error.message;
      }
    }

    if (error.toString().contains('email')) {
      return 'Problème avec l\'adresse email';
    }

    if (error.toString().contains('password')) {
      return 'Problème avec le mot de passe';
    }

    return 'Une erreur est survenue. Veuillez réessayer.';
  }
}
