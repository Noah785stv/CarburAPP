// profile_page.dart (Version simplifiée pour votre setup)
import 'package:flutter/material.dart';
import 'services/station_visit_service.dart';

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with TickerProviderStateMixin {
  // Variables pour les statistiques
  Map<String, dynamic>? _userStats;
  List<Map<String, dynamic>> _recentVisits = [];
  List<Map<String, dynamic>> _topStations = [];

  // Variables d'état
  bool _isLoading = true;
  String? _errorMessage;

  // Controller pour tabs
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadProfileData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Charger les statistiques utilisateur
      final stats = await StationVisitService.getUserStats();

      // Charger les visites récentes
      final recentVisits = await StationVisitService.getUserVisitHistory(1, 10);

      // Charger les stations les plus visitées
      final topStations = await StationVisitService.getTopVisitedStations(1, 5);

      setState(() {
        _userStats = stats;
        _recentVisits = recentVisits;
        _topStations = topStations;
        _isLoading = false;
      });
    } catch (e) {
      print('Erreur lors du chargement du profil: $e');
      setState(() {
        _errorMessage = 'Erreur lors du chargement des données';
        _isLoading = false;
        // Données par défaut en cas d'erreur
        _userStats = {
          'total_visits': 0,
          'unique_stations': 0,
          'top_brand': null,
          'data_source': 'error',
        };
        _recentVisits = [];
        _topStations = [];
      });
    }
  }

  Future<void> _testStationVisit() async {
    try {
      await StationVisitService.markStationVisit(
        stationId: 'test_${DateTime.now().millisecondsSinceEpoch}',
        stationName: 'Station Test',
        stationBrand: 'Total',
        latitude: 48.8566,
        longitude: 2.3522,
        notes: 'Test depuis le profil',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Visite test ajoutée !'),
          backgroundColor: Color(0xFFE55A2B),
        ),
      );

      // Recharger les données
      await _loadProfileData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _resetAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('⚠️ Réinitialiser les données'),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer toutes vos visites ?\n\nCette action est irréversible.',
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

    if (confirmed == true) {
      try {
        await StationVisitService.resetAllData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Données supprimées avec succès'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadProfileData(); // Recharger
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
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadProfileData,
            tooltip: 'Actualiser',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(icon: Icon(Icons.analytics), text: 'Statistiques'),
            Tab(icon: Icon(Icons.history), text: 'Historique'),
            Tab(icon: Icon(Icons.settings), text: 'Actions'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFFE55A2B)),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Chargement des données Supabase...',
                    style: TextStyle(color: Color(0xFFD2481A)),
                  ),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildStatisticsTab(),
                _buildHistoryTab(),
                _buildActionsTab(),
              ],
            ),
    );
  }

  Widget _buildStatisticsTab() {
    return RefreshIndicator(
      onRefresh: _loadProfileData,
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
                        _errorMessage!,
                        style: TextStyle(color: Colors.orange.shade800),
                      ),
                    ),
                  ],
                ),
              ),

            // Carte profil principal
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
                          child: Icon(
                            Icons.person,
                            size: 50,
                            color: Color(0xFFE55A2B),
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Utilisateur CarburApp',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Données synchronisées avec Supabase',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      SizedBox(height: 20),
                      Row(
                        children: [
                          Icon(Icons.cloud_done,
                              color: Colors.white70, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'Source: ${_userStats?['data_source'] ?? 'unknown'}',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            SizedBox(height: 20),

            // Statistiques principales
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
                    if (_userStats != null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(
                            'Total visites',
                            '${_userStats!['total_visits']}',
                            Icons.location_on,
                          ),
                          _buildStatItem(
                            'Stations uniques',
                            '${_userStats!['unique_stations']}',
                            Icons.local_gas_station,
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      if (_userStats!['top_brand'] != null)
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Color(0xFFFFF5F0),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Color(0xFFE55A2B).withOpacity(0.2),
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.star,
                                color: Color(0xFFE55A2B),
                                size: 24,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Marque préférée',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '${_userStats!['top_brand']}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFE55A2B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_userStats!['last_visit'] != null) ...[
                        SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Dernière visite',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade600,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                _formatDate(_userStats!['last_visit']),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ] else ...[
                      Center(
                        child: Text(
                          'Aucune donnée disponible',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

            // Stations favorites
            if (_topStations.isNotEmpty) ...[
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
                            Icons.favorite,
                            color: Color(0xFFE55A2B),
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Stations favorites',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFD2481A),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      ..._topStations.map((station) => Container(
                            margin: EdgeInsets.only(bottom: 8),
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        station['station_name'] ??
                                            'Station inconnue',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        '${station['station_brand']} • ${station['visit_count']} visites',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    return RefreshIndicator(
      onRefresh: _loadProfileData,
      color: Color(0xFFE55A2B),
      child: _recentVisits.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Aucune visite enregistrée',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Vos visites de stations apparaîtront ici',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _testStationVisit,
                    icon: Icon(Icons.add),
                    label: Text('Ajouter une visite test'),
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
                // Header
                Container(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Historique (${_recentVisits.length})',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFD2481A),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _testStationVisit,
                        icon: Icon(Icons.add, size: 16),
                        label: Text('Test'),
                        style: TextButton.styleFrom(
                          foregroundColor: Color(0xFFE55A2B),
                        ),
                      ),
                    ],
                  ),
                ),

                // Liste des visites
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _recentVisits.length,
                    itemBuilder: (context, index) {
                      final visit = _recentVisits[index];
                      final date =
                          DateTime.parse(visit['visit_date'] as String);
                      final formattedDate = _formatDate(visit['visit_date']);

                      return Card(
                        margin: EdgeInsets.only(bottom: 8),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
                              Icons.local_gas_station,
                              color: Color(0xFFE55A2B),
                              size: 24,
                            ),
                          ),
                          title: Text(
                            visit['station_name'] ?? 'Station inconnue',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFD2481A),
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 4),
                              Text(
                                '${visit['station_brand'] ?? 'Marque inconnue'} • $formattedDate',
                              ),
                              if (visit['notes']?.isNotEmpty == true) ...[
                                SizedBox(height: 4),
                                Text(
                                  visit['notes'],
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          trailing: Icon(
                            Icons.chevron_right,
                            color: Color(0xFFE55A2B),
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

  Widget _buildActionsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Section diagnostic
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
                        Icons.settings,
                        color: Color(0xFFE55A2B),
                        size: 24,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Actions',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFD2481A),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),

                  // Bouton ajouter visite test
                  Container(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _testStationVisit,
                      icon: Icon(Icons.add_location),
                      label: Text('Ajouter une visite test'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFE55A2B),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),

                  SizedBox(height: 12),

                  // Bouton actualiser
                  Container(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _loadProfileData,
                      icon: Icon(Icons.refresh),
                      label: Text('Actualiser les données'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Color(0xFFE55A2B),
                        side: BorderSide(color: Color(0xFFE55A2B)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),

                  SizedBox(height: 12),

                  // Bouton exporter
                  Container(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _exportData,
                      icon: Icon(Icons.download),
                      label: Text('Exporter mes données'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                        side: BorderSide(color: Colors.blue),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 20),

          // Section dangereuse
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
                        Icons.warning,
                        color: Colors.red,
                        size: 24,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Zone dangereuse',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Ces actions sont irréversibles',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _resetAllData,
                      icon: Icon(Icons.delete_forever),
                      label: Text('Supprimer toutes mes données'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 40),

          // Informations
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.info, color: Colors.grey[600], size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Informations',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Text(
                  '• Vos données sont stockées sur Supabase\n'
                  '• Elles sont automatiquement synchronisées\n'
                  '• Vous pouvez les exporter à tout moment\n'
                  '• Version: CarburApp 1.0.0 (Supabase)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Date inconnue';

    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return 'Aujourd\'hui à ${date.hour}h${date.minute.toString().padLeft(2, '0')}';
      } else if (difference.inDays == 1) {
        return 'Hier à ${date.hour}h${date.minute.toString().padLeft(2, '0')}';
      } else if (difference.inDays < 7) {
        return 'Il y a ${difference.inDays} jours';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return 'Date invalide';
    }
  }

  Future<void> _exportData() async {
    try {
      final userData = await StationVisitService.exportUserData();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.download_done, color: Color(0xFFE55A2B)),
              SizedBox(width: 12),
              Text('Données exportées'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Résumé de vos données :',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 12),
                Text('📊 Total visites: ${userData['total_visits']}'),
                Text('📅 Date export: ${_formatDate(userData['export_date'])}'),
                if (userData['statistics'] != null) ...[
                  Text(
                      '🏢 Stations uniques: ${userData['statistics']['unique_stations']}'),
                  if (userData['statistics']['top_brand'] != null)
                    Text(
                        '⭐ Marque préférée: ${userData['statistics']['top_brand']}'),
                ],
                SizedBox(height: 12),
                Text(
                  'Les données complètes sont disponibles dans les logs de développement.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
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

      // Afficher les données complètes dans la console pour le développement
      print('📊 EXPORT DONNÉES UTILISATEUR:');
      print('=====================================');
      print(userData);
      print('=====================================');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur lors de l\'export: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
