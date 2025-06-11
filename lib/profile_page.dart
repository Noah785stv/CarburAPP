// profil_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert'; // Pour json.decode
import '../services/auth_service.dart';
import '../config/supabase_config.dart';

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with TickerProviderStateMixin {
  // Variables pour les données utilisateur
  String _userName = '';
  String _userEmail = '';
  String _userPhone = '';
  String _preferredFuelType = 'SP95';

  // Variables d'état
  bool _isLoading = true;
  bool _isUpdating = false;
  String? _errorMessage;
  User? _currentUser;

  // Statistiques
  int _favoriteStations = 0;
  int _vehicleCount = 0;

  // Listes pour véhicules et paramètres
  List<Map<String, dynamic>> _userVehicles = [];
  List<Map<String, dynamic>> _userSettings = [];

  // Controller pour tabs
  late TabController _tabController;

  // Options pour les véhicules
  final List<String> _fuelTypes = [
    'SP95',
    'SP98',
    'Diesel',
    'E85',
    'GPL',
    'Électrique',
    'Hybride',
  ];
  final List<String> _transmissionTypes = [
    'Manuelle',
    'Automatique',
    'Semi-automatique',
  ];
  final List<String> _bodyTypes = [
    'Citadine',
    'Berline',
    'SUV',
    'Break',
    'Coupé',
    'Cabriolet',
    'Monospace',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _currentUser = AuthService.getCurrentUser();

      if (_currentUser == null) {
        throw Exception('Utilisateur non connecté');
      }

      // Récupérer le profil utilisateur
      final userProfile =
          await supabase
              .from('users')
              .select()
              .eq('id', _currentUser!.id)
              .single();

      // Récupérer les véhicules
      await _loadUserVehicles();

      // Récupérer les paramètres
      await _loadUserSettings();

      // Récupérer les statistiques
      await _loadUserStatistics();

      setState(() {
        _userName = userProfile['full_name'] ?? '';
        _userEmail = userProfile['email'] ?? _currentUser!.email ?? '';
        _userPhone = userProfile['phone'] ?? '';
        _preferredFuelType = userProfile['preferred_fuel_type'] ?? 'SP95';
        _isLoading = false;
      });
    } catch (e) {
      print('Erreur lors du chargement du profil: $e');
      setState(() {
        _errorMessage = 'Erreur lors du chargement du profil';
        _isLoading = false;

        if (_currentUser != null) {
          _userEmail = _currentUser!.email ?? '';
          _userName = _currentUser!.userMetadata?['full_name'] ?? 'Utilisateur';
          _userPhone = _currentUser!.userMetadata?['phone'] ?? '';
          _preferredFuelType =
              _currentUser!.userMetadata?['preferred_fuel_type'] ?? 'SP95';
        }
      });
    }
  }

  Future<void> _loadUserVehicles() async {
    if (_currentUser == null) return;

    try {
      final vehicles = await supabase.rpc(
        'get_user_vehicles',
        params: {'user_uuid': _currentUser!.id},
      );

      setState(() {
        _userVehicles = List<Map<String, dynamic>>.from(vehicles);
        _vehicleCount = _userVehicles.length;
      });
    } catch (e) {
      print('Erreur lors du chargement des véhicules: $e');
      // Fallback: charger directement depuis les tables
      try {
        final userVehicles = await supabase
            .from('user_vehicles')
            .select('''
              *, 
              vehicles:vehicle_id (
                id, make, model, year, fuel_type, fuel_capacity, 
                license_plate, color, transmission, body_type
              )
            ''')
            .eq('user_id', _currentUser!.id);

        setState(() {
          _userVehicles =
              userVehicles.map((uv) {
                final vehicle = uv['vehicles'];
                return {
                  'vehicle_id': vehicle['id'],
                  'make': vehicle['make'],
                  'model': vehicle['model'],
                  'year': vehicle['year'],
                  'fuel_type': vehicle['fuel_type'],
                  'fuel_capacity': vehicle['fuel_capacity'],
                  'license_plate': vehicle['license_plate'],
                  'nickname': uv['nickname'],
                  'is_primary': uv['is_primary'],
                  'relationship_type': uv['relationship_type'],
                };
              }).toList();
          _vehicleCount = _userVehicles.length;
        });
      } catch (e2) {
        print('Erreur fallback véhicules: $e2');
      }
    }
  }

  Future<void> _loadUserSettings() async {
    if (_currentUser == null) return;

    try {
      print('🔄 Chargement des paramètres utilisateur...'); // Debug

      // Essayer d'abord avec la fonction RPC
      try {
        final settings = await supabase.rpc(
          'get_user_settings',
          params: {'user_uuid': _currentUser!.id},
        );

        setState(() {
          _userSettings = List<Map<String, dynamic>>.from(settings);
        });
        print('✅ Paramètres chargés via RPC: ${_userSettings.length}'); // Debug
        return;
      } catch (rpcError) {
        print('⚠️ Erreur RPC, fallback vers requête manuelle: $rpcError');
      }

      // Fallback : charger manuellement
      final allSettings = await supabase
          .from('settings')
          .select('*')
          .eq('is_active', true)
          .order('setting_name');

      print('📋 Paramètres disponibles: ${allSettings.length}'); // Debug

      List<Map<String, dynamic>> userSettingsResult = [];

      for (final setting in allSettings) {
        // Récupérer la valeur utilisateur si elle existe
        final userSetting =
            await supabase
                .from('user_settings')
                .select('setting_value')
                .eq('user_id', _currentUser!.id)
                .eq('setting_id', setting['id'])
                .maybeSingle();

        final settingValue =
            userSetting?['setting_value'] ?? setting['default_value'];

        userSettingsResult.add({
          'setting_key': setting['setting_key'],
          'setting_name': setting['setting_name'],
          'setting_description': setting['setting_description'],
          'setting_type': setting['setting_type'],
          'setting_value': settingValue?.toString() ?? '',
          'default_value': setting['default_value']?.toString() ?? '',
          'possible_values': setting['possible_values'],
          'min_value': setting['min_value'],
          'max_value': setting['max_value'],
        });
      }

      setState(() {
        _userSettings = userSettingsResult;
      });

      print(
        '✅ Paramètres chargés manuellement: ${_userSettings.length}',
      ); // Debug
      _userSettings.forEach(
        (s) => print('   - ${s['setting_key']}: ${s['setting_value']}'),
      ); // Debug
    } catch (e) {
      print('❌ Erreur lors du chargement des paramètres: $e');

      // En cas d'erreur totale, créer des paramètres par défaut
      setState(() {
        _userSettings = [
          {
            'setting_key': 'notifications_enabled',
            'setting_name': 'Notifications',
            'setting_type': 'boolean',
            'setting_value': 'true',
            'default_value': 'true',
            'possible_values': null,
          },
          {
            'setting_key': 'search_radius',
            'setting_name': 'Rayon de recherche (km)',
            'setting_type': 'integer',
            'setting_value': '5',
            'default_value': '5',
            'possible_values': null,
            'min_value': 1,
            'max_value': 50,
          },
          {
            'setting_key': 'theme_mode',
            'setting_name': 'Thème',
            'setting_type': 'select',
            'setting_value': 'auto',
            'default_value': 'auto',
            'possible_values': ['auto', 'light', 'dark'],
          },
        ];
      });
    }
  }

  Future<void> _loadUserStatistics() async {
    if (_currentUser == null) return;

    try {
      final favoritesResult = await supabase
          .from('user_favorites')
          .select('*')
          .eq('user_id', _currentUser!.id);

      setState(() {
        _favoriteStations = favoritesResult.length;
      });
    } catch (e) {
      print('Erreur lors du chargement des statistiques: $e');
      setState(() {
        _favoriteStations = 0;
      });
    }
  }

  Future<void> _updateUserSetting(String settingKey, String newValue) async {
    if (_currentUser == null) return;

    print('🔧 Mise à jour paramètre: $settingKey = $newValue'); // Debug

    try {
      // D'abord, récupérer l'ID du paramètre depuis setting_key
      final settingRecord =
          await supabase
              .from('settings')
              .select('id')
              .eq('setting_key', settingKey)
              .single();

      final settingId = settingRecord['id'];
      print('✅ Setting ID trouvé: $settingId'); // Debug

      // Vérifier si le paramètre utilisateur existe déjà
      final existingSetting =
          await supabase
              .from('user_settings')
              .select('*')
              .eq('user_id', _currentUser!.id)
              .eq('setting_id', settingId)
              .maybeSingle();

      print('🔍 Paramètre existant: $existingSetting'); // Debug

      if (existingSetting != null) {
        // Mettre à jour le paramètre existant
        print('📝 Mise à jour du paramètre existant...'); // Debug
        await supabase
            .from('user_settings')
            .update({'setting_value': newValue})
            .eq('user_id', _currentUser!.id)
            .eq('setting_id', settingId);
        print('✅ Paramètre mis à jour'); // Debug
      } else {
        // Créer un nouveau paramètre utilisateur
        print('➕ Création d\'un nouveau paramètre...'); // Debug
        await supabase.from('user_settings').insert({
          'user_id': _currentUser!.id,
          'setting_id': settingId,
          'setting_value': newValue,
        });
        print('✅ Nouveau paramètre créé'); // Debug
      }

      // Mettre à jour localement
      setState(() {
        final settingIndex = _userSettings.indexWhere(
          (s) => s['setting_key'] == settingKey,
        );
        if (settingIndex != -1) {
          _userSettings[settingIndex]['setting_value'] = newValue;
        }
      });

      // Recharger les paramètres pour être sûr
      await _loadUserSettings();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Paramètre "$settingKey" mis à jour'),
            backgroundColor: Color(0xFFE55A2B),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      print('❌ Erreur lors de la mise à jour du paramètre: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addVehicle() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _VehicleFormDialog(),
    );

    if (result != null && _currentUser != null) {
      try {
        // Utiliser la fonction sécurisée
        final response = await supabase.rpc(
          'add_user_vehicle',
          params: {
            'vehicle_data': {
              'make': result['make'],
              'model': result['model'],
              'year': result['year'],
              'fuel_type': result['fuel_type'],
              'fuel_capacity': result['fuel_capacity'],
              'license_plate': result['license_plate'],
              'color': result['color'],
              'transmission': result['transmission'],
              'body_type': result['body_type'],
            },
            'user_vehicle_data': {
              'nickname': result['nickname'],
              'is_primary': result['is_primary'] ?? false,
              'relationship_type': 'owner',
            },
          },
        );

        if (response.isNotEmpty && response[0]['success'] == true) {
          await _loadUserVehicles();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Véhicule ajouté avec succès !'),
                backgroundColor: Color(0xFFE55A2B),
              ),
            );
          }
        } else {
          throw Exception(
            response.isNotEmpty ? response[0]['message'] : 'Erreur inconnue',
          );
        }
      } catch (e) {
        print('Erreur lors de l\'ajout du véhicule: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Erreur lors de l\'ajout du véhicule: ${e.toString()}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _editVehicle(Map<String, dynamic> vehicle) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _VehicleFormDialog(vehicle: vehicle),
    );

    if (result != null && _currentUser != null) {
      try {
        // Utiliser la fonction sécurisée pour la mise à jour
        final response = await supabase.rpc(
          'update_user_vehicle',
          params: {
            'p_vehicle_id': vehicle['vehicle_id'],
            'vehicle_data': {
              'make': result['make'],
              'model': result['model'],
              'year': result['year'],
              'fuel_type': result['fuel_type'],
              'fuel_capacity': result['fuel_capacity'],
              'license_plate': result['license_plate'],
              'color': result['color'],
              'transmission': result['transmission'],
              'body_type': result['body_type'],
            },
            'user_vehicle_data': {
              'nickname': result['nickname'],
              'is_primary': result['is_primary'] ?? false,
            },
          },
        );

        if (response.isNotEmpty && response[0]['success'] == true) {
          await _loadUserVehicles();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Véhicule modifié avec succès !'),
                backgroundColor: Color(0xFFE55A2B),
              ),
            );
          }
        } else {
          throw Exception(
            response.isNotEmpty ? response[0]['message'] : 'Erreur inconnue',
          );
        }
      } catch (e) {
        print('Erreur lors de la modification du véhicule: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors de la modification: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteVehicle(Map<String, dynamic> vehicle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Supprimer le véhicule'),
            content: Text(
              'Êtes-vous sûr de vouloir supprimer "${vehicle['nickname'] ?? '${vehicle['make']} ${vehicle['model']}'}" ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text('Supprimer', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
    );

    if (confirmed == true && _currentUser != null) {
      try {
        // Supprimer la relation utilisateur-véhicule
        await supabase
            .from('user_vehicles')
            .delete()
            .eq('user_id', _currentUser!.id)
            .eq('vehicle_id', vehicle['vehicle_id']);

        await _loadUserVehicles();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Véhicule supprimé'),
            backgroundColor: Color(0xFFE55A2B),
          ),
        );
      } catch (e) {
        print('Erreur lors de la suppression: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la suppression'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    try {
      await AuthService.signOut();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la déconnexion: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFFF5F0),
      appBar: AppBar(
        title: Text('Mon Profil'),
        backgroundColor: Color(0xFFE55A2B),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: _loadUserProfile),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(icon: Icon(Icons.person), text: 'Profil'),
            Tab(icon: Icon(Icons.directions_car), text: 'Véhicules'),
            Tab(icon: Icon(Icons.settings), text: 'Paramètres'),
          ],
        ),
      ),
      body:
          _isLoading
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFFE55A2B),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Chargement du profil...',
                      style: TextStyle(color: Color(0xFFD2481A)),
                    ),
                  ],
                ),
              )
              : TabBarView(
                controller: _tabController,
                children: [
                  _buildProfileTab(),
                  _buildVehiclesTab(),
                  _buildSettingsTab(),
                ],
              ),
    );
  }

  Widget _buildProfileTab() {
    return RefreshIndicator(
      onRefresh: _loadUserProfile,
      color: Color(0xFFE55A2B),
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Message d'erreur si présent
            if (_errorMessage != null)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                margin: EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Certaines données n\'ont pas pu être chargées. Tirez pour actualiser.',
                        style: TextStyle(color: Colors.orange.shade800),
                      ),
                    ),
                  ],
                ),
              ),

            // Section profil utilisateur
            Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFE55A2B), Color(0xFFFF6B35)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              spreadRadius: 2,
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.white,
                          child: Text(
                            _userName.isNotEmpty
                                ? _userName[0].toUpperCase()
                                : 'U',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFE55A2B),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      Text(
                        _userName.isNotEmpty ? _userName : 'Utilisateur',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        _userEmail,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      if (_userPhone.isNotEmpty) ...[
                        SizedBox(height: 4),
                        Text(
                          _userPhone,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                      SizedBox(height: 20),
                      ElevatedButton(
                        onPressed:
                            _isUpdating
                                ? null
                                : () {
                                  _showEditProfileDialog();
                                },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Color(0xFFE55A2B),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          elevation: 0,
                          padding: EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child:
                            _isUpdating
                                ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.edit, size: 18),
                                    SizedBox(width: 8),
                                    Text('Modifier le profil'),
                                  ],
                                ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            SizedBox(height: 20),

            // Statistiques
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.analytics,
                          color: Color(0xFFE55A2B),
                          size: 24,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Mes statistiques',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFD2481A),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(
                          'Favoris',
                          '$_favoriteStations',
                          Icons.favorite,
                        ),
                        _buildStatItem(
                          'Véhicules',
                          '$_vehicleCount',
                          Icons.directions_car,
                        ),
                        _buildStatItem(
                          'Carburant',
                          _preferredFuelType,
                          Icons.local_gas_station,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 32),

            // Bouton de déconnexion
            Container(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _showLogoutDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Se déconnecter',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehiclesTab() {
    return RefreshIndicator(
      onRefresh: _loadUserVehicles,
      color: Color(0xFFE55A2B),
      child:
          _userVehicles.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.directions_car_outlined,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Aucun véhicule enregistré',
                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Ajoutez votre premier véhicule pour personnaliser votre expérience',
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _addVehicle,
                      icon: Icon(Icons.add),
                      label: Text('Ajouter un véhicule'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFE55A2B),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                    ),
                  ],
                ),
              )
              : Column(
                children: [
                  // Header avec bouton ajouter
                  Container(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Mes véhicules (${_userVehicles.length})',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFD2481A),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _addVehicle,
                          icon: Icon(Icons.add, size: 18),
                          label: Text('Ajouter'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFFE55A2B),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Liste des véhicules
                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _userVehicles.length,
                      itemBuilder: (context, index) {
                        final vehicle = _userVehicles[index];
                        return Card(
                          margin: EdgeInsets.only(bottom: 12),
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  vehicle['is_primary'] == true
                                      ? Border.all(
                                        color: Color(0xFFE55A2B),
                                        width: 2,
                                      )
                                      : null,
                            ),
                            child: ListTile(
                              contentPadding: EdgeInsets.all(16),
                              leading: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Color(0xFFFFF5F0),
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                child: Icon(
                                  Icons.directions_car,
                                  color: Color(0xFFE55A2B),
                                  size: 28,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      vehicle['nickname']?.isNotEmpty == true
                                          ? vehicle['nickname']
                                          : '${vehicle['make']} ${vehicle['model']}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFD2481A),
                                      ),
                                    ),
                                  ),
                                  if (vehicle['is_primary'] == true)
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Color(0xFFE55A2B),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'Principal',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(height: 4),
                                  Text(
                                    '${vehicle['make']} ${vehicle['model']} (${vehicle['year']})',
                                  ),
                                  SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.local_gas_station,
                                        size: 14,
                                        color: Colors.grey[600],
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        vehicle['fuel_type'] ?? 'Non spécifié',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      SizedBox(width: 16),
                                      if (vehicle['license_plate']
                                              ?.isNotEmpty ==
                                          true) ...[
                                        Icon(
                                          Icons.credit_card,
                                          size: 14,
                                          color: Colors.grey[600],
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          vehicle['license_plate'],
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                              trailing: PopupMenuButton(
                                icon: Icon(
                                  Icons.more_vert,
                                  color: Color(0xFFE55A2B),
                                ),
                                onSelected: (value) {
                                  switch (value) {
                                    case 'edit':
                                      _editVehicle(vehicle);
                                      break;
                                    case 'delete':
                                      _deleteVehicle(vehicle);
                                      break;
                                  }
                                },
                                itemBuilder:
                                    (context) => [
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.edit,
                                              color: Color(0xFFE55A2B),
                                            ),
                                            SizedBox(width: 8),
                                            Text('Modifier'),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.delete,
                                              color: Colors.red,
                                            ),
                                            SizedBox(width: 8),
                                            Text('Supprimer'),
                                          ],
                                        ),
                                      ),
                                    ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _buildSettingsTab() {
    return RefreshIndicator(
      onRefresh: _loadUserSettings,
      color: Color(0xFFE55A2B),
      child:
          _userSettings.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFFE55A2B),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text('Chargement des paramètres...'),
                  ],
                ),
              )
              : ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: _userSettings.length,
                itemBuilder: (context, index) {
                  final setting = _userSettings[index];
                  return Card(
                    margin: EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: _buildSettingItem(setting),
                    ),
                  );
                },
              ),
    );
  }

  Widget _buildSettingItem(Map<String, dynamic> setting) {
    final settingType = setting['setting_type'] as String;
    final settingValue = setting['setting_value'] as String? ?? '';
    final settingKey = setting['setting_key'] as String;

    print(
      '🎛️ Building setting: $settingKey = $settingValue (type: $settingType)',
    ); // Debug

    switch (settingType) {
      case 'boolean':
        final boolValue = settingValue.toLowerCase() == 'true';
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            setting['setting_name'] ?? 'Paramètre',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFFD2481A),
            ),
          ),
          subtitle:
              setting['setting_description'] != null
                  ? Text(setting['setting_description'])
                  : null,
          value: boolValue,
          activeColor: Color(0xFFE55A2B),
          onChanged: (bool value) {
            print('🔄 Switch changed: $settingKey -> $value'); // Debug
            _updateUserSetting(settingKey, value.toString());
          },
        );

      case 'select':
        final possibleValues = setting['possible_values'];
        List<String> options = [];

        if (possibleValues is List) {
          options = possibleValues.map((v) => v.toString()).toList();
        } else if (possibleValues is String) {
          // Si c'est une string JSON, essayer de la parser
          try {
            final parsed = json.decode(possibleValues);
            if (parsed is List) {
              options = parsed.map((v) => v.toString()).toList();
            }
          } catch (e) {
            print('Erreur parsing JSON: $e');
            options = ['Erreur'];
          }
        }

        if (options.isEmpty) {
          options = ['Auto', 'Manuel']; // Valeurs par défaut
        }

        // S'assurer que la valeur actuelle est dans les options
        String currentValue = settingValue;
        if (!options.contains(currentValue) && options.isNotEmpty) {
          currentValue = options.first;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              setting['setting_name'] ?? 'Paramètre',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFFD2481A),
              ),
            ),
            if (setting['setting_description'] != null) ...[
              SizedBox(height: 4),
              Text(
                setting['setting_description'],
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
            SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Color(0xFFE55A2B)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<String>(
                value: currentValue,
                isExpanded: true,
                underline: Container(),
                style: TextStyle(
                  color: Color(0xFFE55A2B),
                  fontWeight: FontWeight.w500,
                ),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    print(
                      '🔄 Dropdown changed: $settingKey -> $newValue',
                    ); // Debug
                    _updateUserSetting(settingKey, newValue);
                  }
                },
                items:
                    options.map<DropdownMenuItem<String>>((value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
              ),
            ),
          ],
        );

      case 'integer':
        final minValue = (setting['min_value'] as num?)?.toDouble() ?? 0.0;
        final maxValue = (setting['max_value'] as num?)?.toDouble() ?? 100.0;
        final currentValue = double.tryParse(settingValue) ?? minValue;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        setting['setting_name'] ?? 'Paramètre',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFD2481A),
                        ),
                      ),
                      if (setting['setting_description'] != null)
                        Text(
                          setting['setting_description'],
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Color(0xFFE55A2B),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${currentValue.toInt()}',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Color(0xFFE55A2B),
                inactiveTrackColor: Color(0xFFE55A2B).withOpacity(0.3),
                thumbColor: Color(0xFFE55A2B),
              ),
              child: Slider(
                value: currentValue.clamp(minValue, maxValue),
                min: minValue,
                max: maxValue,
                divisions: (maxValue - minValue).toInt(),
                onChanged: (double value) {
                  print(
                    '🔄 Slider changed: $settingKey -> ${value.toInt()}',
                  ); // Debug
                  _updateUserSetting(settingKey, value.toInt().toString());
                },
              ),
            ),
          ],
        );

      case 'text':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              setting['setting_name'] ?? 'Paramètre',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFFD2481A),
              ),
            ),
            if (setting['setting_description'] != null) ...[
              SizedBox(height: 4),
              Text(
                setting['setting_description'],
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
            SizedBox(height: 8),
            TextField(
              controller: TextEditingController(text: settingValue),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Color(0xFFE55A2B)),
                ),
              ),
              onSubmitted: (value) {
                print('🔄 Text field changed: $settingKey -> $value'); // Debug
                _updateUserSetting(settingKey, value);
              },
            ),
          ],
        );

      default:
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(setting['setting_name'] ?? 'Paramètre inconnu'),
          subtitle: Text('Type: $settingType, Valeur: $settingValue'),
          trailing: Icon(Icons.help_outline, color: Colors.grey),
        );
    }
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFFFFF5F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFE55A2B).withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: Color(0xFFE55A2B), size: 24),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFFE55A2B),
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog() {
    final TextEditingController nameController = TextEditingController(
      text: _userName,
    );
    final TextEditingController phoneController = TextEditingController(
      text: _userPhone,
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(Icons.edit, color: Color(0xFFE55A2B)),
                SizedBox(width: 12),
                Text(
                  'Modifier le profil',
                  style: TextStyle(color: Color(0xFFD2481A)),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Nom complet',
                    labelStyle: TextStyle(color: Color(0xFFE55A2B)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Color(0xFFE55A2B)),
                    ),
                    prefixIcon: Icon(Icons.person, color: Color(0xFFE55A2B)),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Téléphone (optionnel)',
                    labelStyle: TextStyle(color: Color(0xFFE55A2B)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Color(0xFFE55A2B)),
                    ),
                    prefixIcon: Icon(Icons.phone, color: Color(0xFFE55A2B)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Annuler',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  setState(() => _isUpdating = true);
                  try {
                    await supabase
                        .from('users')
                        .update({
                          'full_name': nameController.text.trim(),
                          'phone': phoneController.text.trim(),
                        })
                        .eq('id', _currentUser!.id);

                    await _loadUserProfile();

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Profil mis à jour avec succès !'),
                        backgroundColor: Color(0xFFE55A2B),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Erreur lors de la mise à jour'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  } finally {
                    setState(() => _isUpdating = false);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFE55A2B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Sauvegarder',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(Icons.logout, color: Colors.red),
                SizedBox(width: 12),
                Text('Déconnexion'),
              ],
            ),
            content: Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Annuler',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _logout();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Déconnecter',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }
}

// Dialog pour ajouter/modifier un véhicule
class _VehicleFormDialog extends StatefulWidget {
  final Map<String, dynamic>? vehicle;

  const _VehicleFormDialog({this.vehicle});

  @override
  _VehicleFormDialogState createState() => _VehicleFormDialogState();
}

class _VehicleFormDialogState extends State<_VehicleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _makeController;
  late TextEditingController _modelController;
  late TextEditingController _yearController;
  late TextEditingController _licenseController;
  late TextEditingController _colorController;
  late TextEditingController _nicknameController;
  late TextEditingController _capacityController;

  String _selectedFuelType = 'SP95';
  String _selectedTransmission = 'Manuelle';
  String _selectedBodyType = 'Citadine';
  bool _isPrimary = false;

  final List<String> _fuelTypes = [
    'SP95',
    'SP98',
    'Diesel',
    'E85',
    'GPL',
    'Électrique',
    'Hybride',
  ];
  final List<String> _transmissionTypes = [
    'Manuelle',
    'Automatique',
    'Semi-automatique',
  ];
  final List<String> _bodyTypes = [
    'Citadine',
    'Berline',
    'SUV',
    'Break',
    'Coupé',
    'Cabriolet',
    'Monospace',
  ];

  @override
  void initState() {
    super.initState();

    final vehicle = widget.vehicle;
    _makeController = TextEditingController(text: vehicle?['make'] ?? '');
    _modelController = TextEditingController(text: vehicle?['model'] ?? '');
    _yearController = TextEditingController(
      text: vehicle?['year']?.toString() ?? '',
    );
    _licenseController = TextEditingController(
      text: vehicle?['license_plate'] ?? '',
    );
    _colorController = TextEditingController(text: vehicle?['color'] ?? '');
    _nicknameController = TextEditingController(
      text: vehicle?['nickname'] ?? '',
    );
    _capacityController = TextEditingController(
      text: vehicle?['fuel_capacity']?.toString() ?? '',
    );

    if (vehicle != null) {
      _selectedFuelType = vehicle['fuel_type'] ?? 'SP95';
      _selectedTransmission = vehicle['transmission'] ?? 'Manuelle';
      _selectedBodyType = vehicle['body_type'] ?? 'Citadine';
      _isPrimary = vehicle['is_primary'] ?? false;
    }
  }

  @override
  void dispose() {
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _licenseController.dispose();
    _colorController.dispose();
    _nicknameController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(
            widget.vehicle == null ? Icons.add_circle : Icons.edit,
            color: Color(0xFFE55A2B),
          ),
          SizedBox(width: 12),
          Text(
            widget.vehicle == null
                ? 'Ajouter un véhicule'
                : 'Modifier le véhicule',
            style: TextStyle(color: Color(0xFFD2481A)),
          ),
        ],
      ),
      content: Container(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Surnom
                TextFormField(
                  controller: _nicknameController,
                  decoration: InputDecoration(
                    labelText: 'Surnom (optionnel)',
                    hintText: 'Ma voiture, Mon SUV...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: Icon(Icons.label, color: Color(0xFFE55A2B)),
                  ),
                ),
                SizedBox(height: 16),

                // Marque et Modèle
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _makeController,
                        decoration: InputDecoration(
                          labelText: 'Marque*',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator:
                            (value) =>
                                value?.isEmpty == true ? 'Obligatoire' : null,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _modelController,
                        decoration: InputDecoration(
                          labelText: 'Modèle*',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator:
                            (value) =>
                                value?.isEmpty == true ? 'Obligatoire' : null,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),

                // Année et Plaque
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _yearController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Année',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _licenseController,
                        decoration: InputDecoration(
                          labelText: 'Plaque',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),

                // Type de carburant
                DropdownButtonFormField<String>(
                  value: _selectedFuelType,
                  decoration: InputDecoration(
                    labelText: 'Type de carburant*',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: Icon(
                      Icons.local_gas_station,
                      color: Color(0xFFE55A2B),
                    ),
                  ),
                  items:
                      _fuelTypes.map((fuel) {
                        return DropdownMenuItem(value: fuel, child: Text(fuel));
                      }).toList(),
                  onChanged:
                      (value) => setState(() => _selectedFuelType = value!),
                ),
                SizedBox(height: 16),

                // Capacité et Couleur
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _capacityController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Capacité (L)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _colorController,
                        decoration: InputDecoration(
                          labelText: 'Couleur',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),

                // Transmission
                DropdownButtonFormField<String>(
                  value: _selectedTransmission,
                  decoration: InputDecoration(
                    labelText: 'Transmission',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items:
                      _transmissionTypes.map((trans) {
                        return DropdownMenuItem(
                          value: trans,
                          child: Text(trans),
                        );
                      }).toList(),
                  onChanged:
                      (value) => setState(() => _selectedTransmission = value!),
                ),
                SizedBox(height: 16),

                // Type de carrosserie
                DropdownButtonFormField<String>(
                  value: _selectedBodyType,
                  decoration: InputDecoration(
                    labelText: 'Type de carrosserie',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items:
                      _bodyTypes.map((body) {
                        return DropdownMenuItem(value: body, child: Text(body));
                      }).toList(),
                  onChanged:
                      (value) => setState(() => _selectedBodyType = value!),
                ),
                SizedBox(height: 16),

                // Véhicule principal
                SwitchListTile(
                  title: Text('Véhicule principal'),
                  subtitle: Text('Utilisé par défaut pour les recherches'),
                  value: _isPrimary,
                  activeColor: Color(0xFFE55A2B),
                  onChanged: (value) => setState(() => _isPrimary = value),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Annuler', style: TextStyle(color: Colors.grey[600])),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final result = {
                'make': _makeController.text.trim(),
                'model': _modelController.text.trim(),
                'year': int.tryParse(_yearController.text.trim()),
                'fuel_type': _selectedFuelType,
                'fuel_capacity': double.tryParse(
                  _capacityController.text.trim(),
                ),
                'license_plate': _licenseController.text.trim(),
                'color': _colorController.text.trim(),
                'transmission': _selectedTransmission,
                'body_type': _selectedBodyType,
                'nickname': _nicknameController.text.trim(),
                'is_primary': _isPrimary,
              };
              Navigator.pop(context, result);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFFE55A2B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            widget.vehicle == null ? 'Ajouter' : 'Modifier',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}
