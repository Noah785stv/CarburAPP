// main.dart (Version UNIQUEMENT Supabase)
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'config/supabase_config.dart';
import 'geo.dart';
import 'station_list_page.dart';
import 'profile_page.dart';
import 'services/station_visit_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('🚀 Démarrage CarburApp...');
  print('📱 Plateforme: ${kIsWeb ? "Web" : "Mobile"}');

  // Initialisation Supabase OBLIGATOIRE
  bool supabaseOk = false;
  try {
    print('🔄 Initialisation Supabase...');
    await SupabaseConfig.initialize();

    // Test du service
    await StationVisitService.initialize();
    supabaseOk = await StationVisitService.isDatabaseReady();

    if (supabaseOk) {
      print('✅ Supabase opérationnel');
    } else {
      print('⚠️ Supabase non opérationnel');
    }
  } catch (e) {
    print('❌ Erreur Supabase: $e');
  }

  print(
    supabaseOk
        ? '🎉 Application prête avec Supabase'
        : '⚠️ Application en mode dégradé - Supabase requis',
  );

  runApp(MyApp(supabaseReady: supabaseOk));
}

class MyApp extends StatelessWidget {
  final bool supabaseReady;

  const MyApp({Key? key, required this.supabaseReady}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CarburApp',
      theme: ThemeData(
        primarySwatch: Colors.orange,
        primaryColor: Color(0xFFE55A2B),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Color(0xFFE55A2B),
          brightness: Brightness.light,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFFE55A2B),
          foregroundColor: Colors.white,
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: HomePage(supabaseReady: supabaseReady),
    );
  }
}

class HomePage extends StatelessWidget {
  final bool supabaseReady;

  const HomePage({Key? key, required this.supabaseReady}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF5F0), Colors.white, Color(0xFFFFF5F0)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                SizedBox(height: 60),

                // Logo
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFE55A2B), Color(0xFFFF6B35)],
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
                  child: Icon(
                    Icons.local_gas_station,
                    size: 70,
                    color: Colors.white,
                  ),
                ),

                SizedBox(height: 40),

                // Titre
                Text(
                  'CarburApp',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFE55A2B),
                    letterSpacing: -0.5,
                  ),
                ),

                SizedBox(height: 12),

                Text(
                  'Powered by Supabase',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFD2481A),
                  ),
                ),

                SizedBox(height: 40),

                // Statut Supabase
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color:
                        supabaseReady
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: supabaseReady ? Colors.green : Colors.red,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        supabaseReady ? Icons.cloud_done : Icons.cloud_off,
                        color: supabaseReady ? Colors.green : Colors.red,
                        size: 24,
                      ),
                      SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          supabaseReady
                              ? 'Supabase connecté'
                              : 'Connexion Supabase requise',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color:
                                supabaseReady
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 30),

                // Bouton principal
                Container(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed:
                        supabaseReady
                            ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => MainNavigationPage(),
                                ),
                              );
                            }
                            : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          supabaseReady ? Color(0xFFE55A2B) : Colors.grey,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: supabaseReady ? 8 : 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          supabaseReady ? Icons.explore : Icons.warning,
                          size: 24,
                        ),
                        SizedBox(width: 12),
                        Text(
                          supabaseReady
                              ? 'Explorer maintenant'
                              : 'Supabase requis',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 20),

                // Bouton diagnostic
                Container(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DiagnosticPage(),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Color(0xFFE55A2B),
                      side: BorderSide(color: Color(0xFFE55A2B)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.settings, size: 20),
                        SizedBox(width: 8),
                        Text('Diagnostic Supabase'),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 40),

                // Information Supabase
                if (!supabaseReady) ...[
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '☁️ Connexion Supabase requise',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Cette application utilise Supabase pour sauvegarder vos visites de stations. Vérifiez votre connexion internet.',
                          style: TextStyle(color: Colors.orange.shade600),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                ],

                // Footer
                Text(
                  'Version 1.0.0 • CarburApp • Supabase',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),

                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Navigation principale
class MainNavigationPage extends StatefulWidget {
  @override
  _MainNavigationPageState createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    HomeTab(),
    GasStationMapPage(),
    StationsListPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Color(0xFFE55A2B),
        unselectedItemColor: Colors.grey.shade500,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Carte'),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_gas_station),
            label: 'Stations',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}

// Onglet Home avec Supabase
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
          _userStats = {
            'total_visits': 0,
            'unique_stations': 0,
            'top_brand': null,
            'data_source': 'error',
          };
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
              // Header avec statistiques Supabase
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
                    Row(
                      children: [
                        Text(
                          'Bonjour !',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Spacer(),
                        Icon(Icons.cloud_done, color: Colors.white70, size: 20),
                      ],
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Données synchronisées avec Supabase',
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
                            if (_userStats!['data_source'] == 'error')
                              Text(
                                ' (hors ligne)',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ] else if (_isLoadingStats) ...[
                      SizedBox(height: 15),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Chargement des statistiques...',
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
              Row(
                children: [
                  Text(
                    'Actions rapides',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  Spacer(),
                  IconButton(
                    icon: Icon(Icons.refresh, color: Colors.grey.shade600),
                    onPressed: _loadUserStats,
                    tooltip: 'Actualiser les données',
                  ),
                ],
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
                    'Voir la carte',
                    Icons.map,
                    Color(0xFFE55A2B),
                    () => _navigateToTab(1),
                  ),
                  _buildActionCard(
                    'Liste stations',
                    Icons.list,
                    Color(0xFFFF6B35),
                    () => _navigateToTab(2),
                  ),
                  _buildActionCard(
                    'Mes statistiques',
                    Icons.analytics,
                    Color(0xFF4CAF50),
                    _showDetailedStats,
                  ),
                  _buildActionCard(
                    'Mon profil',
                    Icons.person,
                    Color(0xFFD2481A),
                    () => _navigateToTab(3),
                  ),
                ],
              ),

              SizedBox(height: 25),

              // Visites récentes
              FutureBuilder<List<Map<String, dynamic>>>(
                future: StationVisitService.getRecentVisits(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildLoadingSection('Visites récentes');
                  }

                  if (snapshot.hasError ||
                      !snapshot.hasData ||
                      snapshot.data!.isEmpty) {
                    return _buildEmptySection(
                      'Visites récentes',
                      'Aucune visite cette semaine',
                      Icons.history,
                    );
                  }

                  return _buildRecentVisitsSection(snapshot.data!);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard(
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

  Widget _buildLoadingSection(String title) {
    return Container(
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
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          SizedBox(height: 15),
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE55A2B)),
          ),
          SizedBox(height: 10),
          Text(
            'Chargement depuis Supabase...',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySection(String title, String message, IconData icon) {
    return Container(
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
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          SizedBox(height: 15),
          Icon(icon, size: 40, color: Colors.grey.shade400),
          SizedBox(height: 10),
          Text(
            message,
            style: TextStyle(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentVisitsSection(List<Map<String, dynamic>> visits) {
    return Container(
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
              Text(
                'Visites récentes',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              Spacer(),
              Text(
                '${visits.length} cette semaine',
                style: TextStyle(
                  color: Color(0xFFE55A2B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 15),
          ...visits.take(3).map((visit) => _buildVisitItem(visit)).toList(),
          if (visits.length > 3) ...[
            SizedBox(height: 10),
            Center(
              child: TextButton(
                onPressed:
                    () => _navigateToTab(3), // Aller au profil pour voir tout
                child: Text('Voir tout l\'historique'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVisitItem(Map<String, dynamic> visit) {
    final date = DateTime.parse(visit['visit_date'] as String);
    final formattedDate =
        '${date.day}/${date.month} à ${date.hour}h${date.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Color(0xFFE55A2B).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.local_gas_station,
              color: Color(0xFFE55A2B),
              size: 20,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  visit['station_name'] as String,
                  style: TextStyle(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${visit['station_brand']} • $formattedDate',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToTab(int tabIndex) {
    final mainNavState =
        context.findAncestorStateOfType<_MainNavigationPageState>();
    if (mainNavState != null) {
      mainNavState.setState(() {
        mainNavState._currentIndex = tabIndex;
      });
    }
  }

  void _showDetailedStats() async {
    try {
      final stats = await StationVisitService.getUserStats();
      final topStations = await StationVisitService.getTopVisitedStations(1, 5);

      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.analytics, color: Color(0xFFE55A2B)),
                  SizedBox(width: 12),
                  Text('Statistiques détaillées'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    if (stats['last_visit'] != null) ...[
                      SizedBox(height: 10),
                      Text(
                        'Dernière visite:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        DateTime.parse(
                          stats['last_visit'],
                        ).toString().substring(0, 16),
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                    if (topStations.isNotEmpty) ...[
                      SizedBox(height: 15),
                      Text(
                        'Stations favorites:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 5),
                      ...topStations.map(
                        (station) => Padding(
                          padding: EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            '• ${station['station_name']} (${station['visit_count']} visites)',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.cloud_done, size: 16, color: Colors.green),
                        SizedBox(width: 4),
                        Text(
                          'Données Supabase',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Fermer'),
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

// Page de diagnostic Supabase
class DiagnosticPage extends StatefulWidget {
  @override
  _DiagnosticPageState createState() => _DiagnosticPageState();
}

class _DiagnosticPageState extends State<DiagnosticPage> {
  List<String> _diagnosticResults = [];
  bool _isRunning = false;
  Map<String, dynamic>? _diagnosticInfo;

  @override
  void initState() {
    super.initState();
    _runDiagnostics();
  }

  Future<void> _runDiagnostics() async {
    setState(() {
      _isRunning = true;
      _diagnosticResults.clear();
      _diagnosticInfo = null;
    });

    try {
      // Récupérer les infos de diagnostic
      final info = await StationVisitService.getDiagnosticInfo();
      final results = await StationVisitService.runFullTest();

      setState(() {
        _diagnosticResults = results;
        _diagnosticInfo = info;
      });
    } catch (e) {
      setState(() {
        _diagnosticResults = ['🔍 Début des tests...', '❌ Erreur critique: $e'];
      });
    }

    setState(() {
      _isRunning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Diagnostic Supabase'),
        backgroundColor: Color(0xFFE55A2B),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _isRunning ? null : _runDiagnostics,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Informations de diagnostic
            if (_diagnosticInfo != null) ...[
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📊 Informations système',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    SizedBox(height: 10),
                    _buildInfoRow('Plateforme', _diagnosticInfo!['platform']),
                    _buildInfoRow('Stockage', _diagnosticInfo!['storage_type']),
                    _buildInfoRow(
                      'Supabase URL',
                      _diagnosticInfo!['supabase_url'],
                    ),
                    _buildInfoRow('État auth', _diagnosticInfo!['auth_status']),
                    _buildInfoRow(
                      'Initialisé',
                      _diagnosticInfo!['is_initialized'].toString(),
                    ),
                    _buildInfoRow(
                      'Prêt',
                      _diagnosticInfo!['supabase_ready'].toString(),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
            ],

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

            // Résultats des tests
            ...(_diagnosticResults.map((result) {
              final isError = result.contains('❌');
              final isSuccess = result.contains('✅');
              final isWarning = result.contains('⚠️');

              return Card(
                margin: EdgeInsets.symmetric(vertical: 4),
                color:
                    isError
                        ? Colors.red.shade50
                        : isSuccess
                        ? Colors.green.shade50
                        : isWarning
                        ? Colors.orange.shade50
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
                              : isWarning
                              ? Colors.orange.shade700
                              : null,
                    ),
                  ),
                ),
              );
            })),

            SizedBox(height: 20),

            // Boutons d'action
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isRunning ? null : _runDiagnostics,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFE55A2B),
                      foregroundColor: Colors.white,
                    ),
                    child: Text('🔍 Tester'),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isRunning ? null : _resetData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    child: Text('🗑️ Reset'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _resetData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('⚠️ Confirmation'),
            content: Text(
              'Êtes-vous sûr de vouloir supprimer toutes vos données Supabase ?\n\nCette action est irréversible.',
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

    if (confirm == true) {
      try {
        await StationVisitService.resetAllData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Données supprimées avec succès'),
            backgroundColor: Colors.green,
          ),
        );
        _runDiagnostics(); // Relancer les tests
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur lors de la suppression: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
