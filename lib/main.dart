// main.dart (Version adaptée avec SQLite)
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite/sqflite.dart';
import 'config/supabase_config.dart';
import 'pages/auth/login_page.dart';
import 'geo.dart';
import 'station_list_page.dart';
import 'profile_page.dart';
import 'services/station_visit_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // ✅ Initialiser la base de données SQLite AVANT Supabase
    print('🔄 Initialisation de la base de données locale...');
    await _initializeDatabase();
    print('✅ Base de données locale initialisée');

    // Initialiser Supabase
    print('🔄 Initialisation de Supabase...');
    await SupabaseConfig.initialize();
    print('✅ Supabase initialisé');

    print('🎉 Application prête à démarrer');
  } catch (e) {
    print('❌ Erreur lors de l\'initialisation: $e');
    // L'application peut continuer même si l'une des initialisations échoue
  }

  runApp(MyApp());
}

/// Fonction pour initialiser la base de données SQLite
Future<void> _initializeDatabase() async {
  try {
    // Vérifier que la base de données est prête
    final isReady = await StationVisitService.isDatabaseReady();
    if (isReady) {
      print('✅ Base de données SQLite prête');

      // Optionnel: Vérifier les statistiques existantes
      final stats = await StationVisitService.getUserStats();
      print('📊 Visites existantes: ${stats['total_visits']}');
    } else {
      print('⚠️ Problème avec la base de données SQLite');
    }
  } catch (e) {
    print('❌ Erreur lors de l\'initialisation SQLite: $e');
    // Ne pas bloquer l'application, juste logger l'erreur
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CarburApp - Stations-service',
      theme: ThemeData(
        primarySwatch: Colors.orange,
        primaryColor: Color(0xFFE55A2B), // Orange principal du logo
        colorScheme: ColorScheme.fromSeed(
          seedColor: Color(0xFFE55A2B),
          brightness: Brightness.light,
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFFE55A2B),
          foregroundColor: Colors.white,
        ),
        // Configuration des polices pour éviter l'avertissement
        fontFamily: 'Roboto',
      ),
      // Désactiver les bannières de debug
      debugShowCheckedModeBanner: false,
      home: AuthWrapper(), // Wrapper pour gérer l'authentification
    );
  }
}

// Wrapper pour gérer l'état d'authentification
class AuthWrapper extends StatefulWidget {
  @override
  _AuthWrapperState createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  User? _user;
  bool _isLoading = true;
  bool _dbReady = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  /// Initialisation complète de l'application
  Future<void> _initializeApp() async {
    try {
      // Vérifier d'abord la base de données locale
      await _checkDatabaseStatus();

      // Puis gérer l'authentification Supabase
      await _getInitialSession();
      _listenToAuthChanges();
    } catch (e) {
      print('❌ Erreur lors de l\'initialisation de l\'app: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _checkDatabaseStatus() async {
    try {
      _dbReady = await StationVisitService.isDatabaseReady();
      print(_dbReady ? '✅ DB locale OK' : '⚠️ DB locale KO');
    } catch (e) {
      print('❌ Erreur vérification DB: $e');
      _dbReady = false;
    }
  }

  Future<void> _getInitialSession() async {
    try {
      final session = supabase.auth.currentSession;
      if (mounted) {
        setState(() {
          _user = session?.user;
        });
      }
    } catch (e) {
      print('❌ Erreur session Supabase: $e');
      // Continuer sans Supabase si erreur
    }
  }

  void _listenToAuthChanges() {
    try {
      supabase.auth.onAuthStateChange.listen((data) {
        final AuthChangeEvent event = data.event;
        final Session? session = data.session;

        if (mounted) {
          setState(() {
            _user = session?.user;
          });
        }
      });
    } catch (e) {
      print('❌ Erreur écoute auth: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFF5F0), Colors.white, Color(0xFFFFF5F0)],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFE55A2B), Color(0xFFFF6B35)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: Icon(
                    Icons.local_gas_station,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 24),
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE55A2B)),
                ),
                SizedBox(height: 16),
                Text(
                  'Initialisation...',
                  style: TextStyle(color: Color(0xFFD2481A), fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  _dbReady
                      ? '✅ Base de données prête'
                      : '🔄 Préparation des données...',
                  style: TextStyle(color: Color(0xFFE55A2B), fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Si l'utilisateur est connecté, montrer la page d'accueil
    if (_user != null) {
      return HomePage();
    }

    // Sinon, montrer la page d'accueil (pas de connexion obligatoire)
    return HomePage();
  }
}

// Page d'accueil avec logo
class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFF5F0), // Orange très clair
              Colors.white,
              Color(0xFFFFF5F0), // Orange très clair
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                SizedBox(height: 60),

                // Logo avec animation
                TweenAnimationBuilder(
                  duration: Duration(milliseconds: 800),
                  tween: Tween<double>(begin: 0, end: 1),
                  builder: (context, double value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFFE55A2B),
                              Color(0xFFFF6B35),
                            ], // Dégradé orange
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(70),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFFE55A2B).withOpacity(0.4),
                              spreadRadius: 8,
                              blurRadius: 20,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(70),
                          child: Image.asset(
                            'assets/images/logo-carburapp.png',
                            width: 100,
                            height: 100,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.local_gas_station,
                                size: 70,
                                color: Colors.white,
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),

                SizedBox(height: 40),

                // Nom de l'application avec style moderne
                Text(
                  'CarburApp',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFE55A2B), // Orange principal
                    letterSpacing: -0.5,
                  ),
                ),

                SizedBox(height: 12),

                // Slogan principal
                Text(
                  'Votre guide intelligent',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFD2481A), // Orange plus foncé
                  ),
                ),

                SizedBox(height: 8),

                // Description détaillée
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Trouvez facilement les stations-service les plus proches, suivez vos visites et découvrez de nouvelles stations.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                SizedBox(height: 50),

                // Fonctionnalités principales avec les nouvelles features
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 2,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildFeatureItem(
                        Icons.location_on,
                        'Géolocalisation précise',
                        'Localisez instantanément les stations autour de vous',
                        Color(0xFFE55A2B), // Orange principal
                      ),
                      SizedBox(height: 16),
                      _buildFeatureItem(
                        Icons.check_circle_outline,
                        'Suivi des visites',
                        'Marquez vos passages et suivez vos statistiques',
                        Color(0xFF4CAF50), // Vert pour les visites
                      ),
                      SizedBox(height: 16),
                      _buildFeatureItem(
                        Icons.analytics_outlined,
                        'Statistiques personnelles',
                        'Découvrez vos habitudes et stations préférées',
                        Color(0xFF2196F3), // Bleu pour les stats
                      ),
                      SizedBox(height: 16),
                      _buildFeatureItem(
                        Icons.navigation,
                        'Navigation intégrée',
                        'Itinéraires optimisés vers votre destination',
                        Color(0xFFD2481A), // Orange plus foncé
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 40),

                // Boutons d'action
                Column(
                  children: [
                    // Bouton principal - Commencer
                    Container(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MainNavigationPage(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(
                            0xFFE55A2B,
                          ), // Orange principal
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          elevation: 8,
                          shadowColor: Color(0xFFE55A2B).withOpacity(0.4),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.explore, size: 24),
                            SizedBox(width: 12),
                            Text(
                              'Explorer maintenant',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 16),

                    // Boutons secondaires
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              // Naviguer directement vers la page de diagnostic
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DiagnosticPage(),
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Color(0xFF4CAF50),
                              side: BorderSide(color: Color(0xFF4CAF50)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.settings_outlined, size: 20),
                                SizedBox(width: 8),
                                Text('Diagnostic'),
                              ],
                            ),
                          ),
                        ),

                        SizedBox(width: 12),

                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              _showAboutDialog(context);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey.shade600,
                              side: BorderSide(color: Colors.grey.shade400),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.info_outline, size: 20),
                                SizedBox(width: 8),
                                Text('À propos'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                SizedBox(height: 30),

                // Footer avec version et statut DB
                FutureBuilder<bool>(
                  future: StationVisitService.isDatabaseReady(),
                  builder: (context, snapshot) {
                    final dbStatus = snapshot.data == true ? '🟢' : '🔴';
                    return Column(
                      children: [
                        Text(
                          'Version 1.0.0 • Made with ❤️',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '$dbStatus Base de données locale',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    );
                  },
                ),

                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(
    IconData icon,
    String title,
    String description,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(Icons.info, color: Color(0xFFE55A2B)), // Orange principal
                SizedBox(width: 12),
                Text('À propos de CarburApp'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CarburApp est votre compagnon de route pour trouver les meilleures stations-service et suivre vos visites.',
                  style: TextStyle(fontSize: 16, height: 1.5),
                ),
                SizedBox(height: 16),
                _buildInfoRow('Version', '1.0.0'),
                _buildInfoRow(
                  'Fonctionnalités',
                  'Géolocalisation, Suivi visites',
                ),
                _buildInfoRow('Stockage', 'Local (SQLite)'),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xFFFFF5F0), // Orange très clair
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '🚀 Nouvelles fonctionnalités :\n• ✅ Marquage des visites\n• ✅ Statistiques personnelles\n• ✅ Historique des passages\n• ✅ Badges de stations visitées',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFFD2481A), // Orange plus foncé
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFE55A2B), // Orange principal
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('Fermer', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: Colors.grey.shade600)),
          ),
        ],
      ),
    );
  }
}

// Page principale avec navigation
class MainNavigationPage extends StatefulWidget {
  @override
  _MainNavigationPageState createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    HomeTab(), // Nouvel onglet d'accueil
    GasStationMapPage(),
    StationsListPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 1,
              blurRadius: 5,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: Color(0xFFE55A2B), // Orange principal
          unselectedItemColor: Colors.grey.shade500,
          selectedLabelStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.normal,
          ),
          items: [
            BottomNavigationBarItem(
              icon: Container(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.home_outlined, size: 24),
              ),
              activeIcon: Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Color(0xFFFFF5F0), // Orange très clair
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.home,
                  size: 24,
                  color: Color(0xFFE55A2B),
                ), // Orange principal
              ),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.map_outlined, size: 24),
              ),
              activeIcon: Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Color(0xFFFFF5F0), // Orange très clair
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.map,
                  size: 24,
                  color: Color(0xFFE55A2B),
                ), // Orange principal
              ),
              label: 'Carte',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.local_gas_station_outlined, size: 24),
              ),
              activeIcon: Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Color(0xFFFFF5F0), // Orange très clair
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.local_gas_station,
                  size: 24,
                  color: Color(0xFFE55A2B),
                ), // Orange principal
              ),
              label: 'Stations',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.person_outline, size: 24),
              ),
              activeIcon: Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Color(0xFFFFF5F0), // Orange très clair
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.person,
                  size: 24,
                  color: Color(0xFFE55A2B),
                ), // Orange principal
              ),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}

// Nouvel onglet Home dans la navigation avec statistiques
class HomeTab extends StatefulWidget {
  @override
  _HomeTabState createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  Map<String, dynamic>? _userStats;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadUserStats();
  }

  Future<void> _loadUserStats() async {
    try {
      final stats = await StationVisitService.getUserStats();
      if (mounted) {
        setState(() {
          _userStats = stats;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      print('Erreur chargement stats: $e');
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header avec salutation et statistiques
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFE55A2B), Color(0xFFFF6B35)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bonjour !',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Trouvez et suivez vos stations préférées',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    if (!_isLoadingStats && _userStats != null) ...[
                      SizedBox(height: 15),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.analytics,
                              color: Colors.white,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              '${_userStats!['total_visits']} visites • ${_userStats!['unique_stations']} stations',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              SizedBox(height: 25),

              // Actions rapides
              Text(
                'Actions rapides',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),

              SizedBox(height: 15),

              // Grille d'actions
              GridView.count(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                childAspectRatio: 1.2,
                children: [
                  _buildActionCard(
                    context,
                    'Voir la carte',
                    Icons.map,
                    Color(0xFFE55A2B),
                    () => _navigateToTab(context, 1),
                  ),
                  _buildActionCard(
                    context,
                    'Liste des stations',
                    Icons.list,
                    Color(0xFFFF6B35),
                    () => _navigateToTab(context, 2),
                  ),
                  _buildActionCard(
                    context,
                    'Mes statistiques',
                    Icons.analytics,
                    Color(0xFF4CAF50),
                    () => _showStatsDialog(),
                  ),
                  _buildActionCard(
                    context,
                    'Mon profil',
                    Icons.person,
                    Color(0xFFD2481A),
                    () => _navigateToTab(context, 3),
                  ),
                ],
              ),

              SizedBox(height: 25),

              // Section informations mise à jour
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Color(0xFFE55A2B)),
                        SizedBox(width: 10),
                        Text(
                          'À propos de CarburApp',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Text(
                      'CarburApp vous aide à localiser facilement les stations-service près de vous. Marquez vos visites, consultez vos statistiques et découvrez de nouvelles stations.',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: 15),
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Suivi des visites activé',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(icon, size: 30, color: color),
            ),
            SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToTab(BuildContext context, int tabIndex) {
    final mainNavState =
        context.findAncestorStateOfType<_MainNavigationPageState>();
    if (mainNavState != null) {
      mainNavState.setState(() {
        mainNavState._currentIndex = tabIndex;
      });
    }
  }

  void _showStatsDialog() async {
    try {
      final stats = await StationVisitService.getUserStats();
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(Icons.analytics, color: Color(0xFFE55A2B)),
                  SizedBox(width: 12),
                  Text('Mes statistiques'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildStatRow(
                    '🎯 Total de visites:',
                    '${stats['total_visits']}',
                  ),
                  _buildStatRow(
                    '🏢 Stations uniques:',
                    '${stats['unique_stations']}',
                  ),
                  if (stats['top_brand'] != null)
                    _buildStatRow(
                      '⭐ Marque préférée:',
                      '${stats['top_brand']}',
                    ),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color(0xFFFFF5F0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Continuez à explorer pour découvrir de nouvelles stations !',
                      style: TextStyle(
                        color: Color(0xFFE55A2B),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Fermer'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _navigateToTab(context, 1); // Aller à la carte
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFE55A2B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Voir la carte',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du chargement des statistiques'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFFE55A2B),
            ),
          ),
        ],
      ),
    );
  }
}

// Ajoutez l'import pour la page de diagnostic
class DiagnosticPage extends StatefulWidget {
  @override
  _DiagnosticPageState createState() => _DiagnosticPageState();
}

class _DiagnosticPageState extends State<DiagnosticPage> {
  List<String> _diagnosticResults = [];
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    _runDiagnostics();
  }

  Future<void> _runDiagnostics() async {
    setState(() {
      _isRunning = true;
      _diagnosticResults.clear();
    });

    _addResult('🔍 Démarrage des diagnostics...');

    // Test 1: Vérifier la disponibilité de SQLite
    try {
      final dbPath = await getDatabasesPath();
      _addResult('✅ Chemin de base de données: ${dbPath.split('/').last}');
    } catch (e) {
      _addResult('❌ Erreur chemin DB: $e');
    }

    // Test 2: Tester l'initialisation de la base de données
    try {
      final isReady = await StationVisitService.isDatabaseReady();
      _addResult(
        isReady ? '✅ Base de données prête' : '❌ Base de données non prête',
      );
    } catch (e) {
      _addResult('❌ Erreur initialisation DB: $e');
    }

    // Test 3: Tester l'écriture
    try {
      await StationVisitService.markStationVisit(
        stationId: 'test_station_${DateTime.now().millisecondsSinceEpoch}',
        stationName: 'Station Test Diagnostic',
        stationBrand: 'Test Brand',
        latitude: 48.8566,
        longitude: 2.3522,
        notes: 'Test de diagnostic automatique',
      );
      _addResult('✅ Écriture en base réussie');
    } catch (e) {
      _addResult('❌ Erreur écriture: $e');
    }

    // Test 4: Tester la lecture
    try {
      final stats = await StationVisitService.getUserStats();
      _addResult('✅ Lecture stats: ${stats['total_visits']} visites');
    } catch (e) {
      _addResult('❌ Erreur lecture: $e');
    }

    // Test 5: Tester l'historique
    try {
      final history = await StationVisitService.getUserVisitHistory();
      _addResult('✅ Historique: ${history.length} entrées');

      if (history.isNotEmpty) {
        final lastVisit = history.first;
        _addResult('📅 Dernière visite: ${lastVisit['station_name']}');
      }
    } catch (e) {
      _addResult('❌ Erreur historique: $e');
    }

    setState(() {
      _isRunning = false;
    });

    _addResult('🏁 Diagnostics terminés - Tout semble fonctionnel !');
  }

  void _addResult(String result) {
    setState(() {
      _diagnosticResults.add(result);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Diagnostic de l\'application'),
        backgroundColor: Color(0xFFE55A2B),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _isRunning ? null : _runDiagnostics,
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tests de fonctionnement',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFFD2481A),
              ),
            ),
            SizedBox(height: 16),

            if (_isRunning)
              Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFFE55A2B),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text('Tests en cours...'),
                  ],
                ),
              ),

            Expanded(
              child: ListView.builder(
                itemCount: _diagnosticResults.length,
                itemBuilder: (context, index) {
                  final result = _diagnosticResults[index];
                  final isError = result.contains('❌');
                  final isSuccess = result.contains('✅');

                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 4),
                    color:
                        isError
                            ? Colors.red.shade50
                            : isSuccess
                            ? Colors.green.shade50
                            : null,
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        result,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                          color:
                              isError
                                  ? Colors.red.shade700
                                  : isSuccess
                                  ? Colors.green.shade700
                                  : null,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        _isRunning
                            ? null
                            : () async {
                              try {
                                await StationVisitService.resetAllData();
                                _addResult('🗑️ Données réinitialisées');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Toutes les données ont été supprimées',
                                    ),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              } catch (e) {
                                _addResult('❌ Erreur reset: $e');
                              }
                            },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: Text('Réinitialiser'),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isRunning ? null : _runDiagnostics,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFE55A2B),
                      foregroundColor: Colors.white,
                    ),
                    child: Text('Relancer les tests'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
