// geo.dart (Version nettoyée sans doublons)
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'services/user_settings_service.dart';
import 'services/station_visit_service.dart';

class GasStationMapPage extends StatefulWidget {
  @override
  _GasStationMapPageState createState() => _GasStationMapPageState();
}

class _GasStationMapPageState extends State<GasStationMapPage> {
  LatLng? _currentLocation;
  List<Map<String, dynamic>> _stations = [];
  List<Map<String, dynamic>> _filteredStations = [];
  bool _isLoading = false;
  String? _errorMessage;
  final MapController _mapController = MapController();

  // Variables pour les fonctionnalités
  double _searchRadius = 5.0;
  String _selectedFilter = 'Toutes';
  bool _showFavoritesOnly = false;
  Set<String> _favoriteStations = {};
  Set<String> _visitedStations = {}; // Nouveau: stations visitées
  String _searchQuery = '';
  bool _isSearchVisible = false;
  int _totalVisitsCount = 0; // Nouveau: compteur total de visites

  // Types de filtres
  final List<String> _filterOptions = [
    'Toutes',
    'Total',
    'Shell',
    'BP',
    'Esso',
    'Carrefour',
    'Leclerc',
    'Autres',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserSettings();
    _loadUserStats(); // Charger les statistiques utilisateur
    UserSettingsService.instance.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    UserSettingsService.instance.removeListener(_onSettingsChanged);
    super.dispose();
  }

  /// Charger les statistiques utilisateur avec gestion d'erreurs robuste
  Future<void> _loadUserStats() async {
    try {
      // Vérifier d'abord que la base de données est prête
      final isDbReady = await StationVisitService.isDatabaseReady();
      if (!isDbReady) {
        print('⚠️ Base de données non prête, initialisation en cours...');
        // Attendre un peu puis réessayer
        await Future.delayed(Duration(milliseconds: 500));
      }

      final stats = await StationVisitService.getUserStats();
      final visitHistory = await StationVisitService.getUserVisitHistory();

      if (mounted) {
        setState(() {
          _totalVisitsCount = stats['total_visits'] ?? 0;
          _visitedStations =
              visitHistory
                  .map((visit) => visit['station_id'] as String)
                  .toSet();
        });

        print('📊 Statistiques chargées: $_totalVisitsCount visites total');
      }
    } catch (e) {
      print('❌ Erreur lors du chargement des statistiques: $e');

      // Initialiser avec des valeurs par défaut en cas d'erreur
      if (mounted) {
        setState(() {
          _totalVisitsCount = 0;
          _visitedStations = {};
        });
      }

      // Réessayer après un délai
      Future.delayed(Duration(seconds: 2), () {
        if (mounted) {
          _loadUserStats();
        }
      });
    }
  }

  /// Callback appelé quand les paramètres changent
  void _onSettingsChanged() async {
    print('🔄 Paramètres modifiés, rechargement du rayon...');
    final newRadius = await UserSettingsService.getSearchRadius();

    if (newRadius != _searchRadius) {
      setState(() {
        _searchRadius = newRadius;
      });

      if (_currentLocation != null) {
        _fetchGasStations(
          _currentLocation!.latitude,
          _currentLocation!.longitude,
        );
      }
    }
  }

  /// Charger les paramètres utilisateur avant de déterminer la position
  Future<void> _loadUserSettings() async {
    try {
      final userRadius = await UserSettingsService.getSearchRadius();

      setState(() {
        _searchRadius = userRadius;
      });

      print('🎯 Rayon de recherche utilisateur: ${_searchRadius}km');
      _determinePosition();
    } catch (e) {
      print('Erreur lors du chargement des paramètres: $e');
      _determinePosition();
    }
  }

  Future<void> _determinePosition() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Les services de localisation sont désactivés.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.deniedForever) {
          throw Exception(
            'Permissions de localisation refusées définitivement.',
          );
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });

      await _fetchGasStations(position.latitude, position.longitude);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Version améliorée de _markStationVisit avec meilleure gestion d'erreurs
  Future<void> _markStationVisit(Map<String, dynamic> station) async {
    try {
      // Vérifier d'abord que la base de données est prête
      final isDbReady = await StationVisitService.isDatabaseReady();
      if (!isDbReady) {
        throw Exception('Base de données non disponible');
      }

      // Vérifier si déjà visitée aujourd'hui
      final alreadyVisitedToday =
          await StationVisitService.hasVisitedStationToday(station['id']);

      if (alreadyVisitedToday) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vous avez déjà visité cette station aujourd\'hui!'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      // Enregistrer la visite
      await StationVisitService.markStationVisit(
        stationId: station['id'],
        stationName: station['name'],
        stationBrand: station['brand'],
        latitude: station['position'].latitude,
        longitude: station['position'].longitude,
        notes: 'Visite marquée depuis la carte',
      );

      // Mettre à jour l'état local
      if (mounted) {
        setState(() {
          _visitedStations.add(station['id']);
          _totalVisitsCount++;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Visite enregistrée! Total: $_totalVisitsCount'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Voir stats',
              textColor: Colors.white,
              onPressed: () => _showUserStats(),
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ Erreur lors de l\'enregistrement de la visite: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Réessayer',
              textColor: Colors.white,
              onPressed: () => _markStationVisit(station),
            ),
          ),
        );
      }
    }
  }

  /// Version améliorée de _showUserStats
  void _showUserStats() async {
    try {
      final stats = await StationVisitService.getUserStats();

      if (mounted) {
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text(
                  '📊 Mes statistiques',
                  style: TextStyle(color: Color(0xFFD2481A)),
                ),
                content: Column(
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
                    SizedBox(height: 16),
                    Text(
                      'Les données sont sauvegardées localement sur votre appareil.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Fermer'),
                  ),
                ],
              ),
        );
      }
    } catch (e) {
      print('❌ Erreur lors de l\'affichage des statistiques: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement des statistiques'),
            backgroundColor: Colors.red,
          ),
        );
      }
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

  Future<void> _fetchGasStations(double lat, double lon) async {
    try {
      final String overpassQuery = '''
        [out:json][timeout:25];
        (
          node["amenity"="fuel"](around:${(_searchRadius * 1000).toInt()},$lat,$lon);
          way["amenity"="fuel"](around:${(_searchRadius * 1000).toInt()},$lat,$lon);
          relation["amenity"="fuel"](around:${(_searchRadius * 1000).toInt()},$lat,$lon);
        );
        out center meta;
      ''';

      final response = await http.post(
        Uri.parse('https://overpass-api.de/api/interpreter'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: overpassQuery,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> elements = data['elements'] ?? [];

        List<Map<String, dynamic>> stations = [];

        for (var element in elements) {
          double stationLat, stationLon;

          if (element['type'] == 'node') {
            stationLat = element['lat']?.toDouble() ?? 0.0;
            stationLon = element['lon']?.toDouble() ?? 0.0;
          } else if (element['type'] == 'way' ||
              element['type'] == 'relation') {
            if (element['center'] != null) {
              stationLat = element['center']['lat']?.toDouble() ?? 0.0;
              stationLon = element['center']['lon']?.toDouble() ?? 0.0;
            } else {
              continue;
            }
          } else {
            continue;
          }

          final tags = element['tags'] ?? {};
          final String name =
              tags['name'] ??
              tags['brand'] ??
              tags['operator'] ??
              'Station-service';

          final String brand = tags['brand'] ?? '';
          final String operator = tags['operator'] ?? '';
          final String id = '${stationLat}_${stationLon}';

          stations.add({
            'id': id,
            'name': name,
            'position': LatLng(stationLat, stationLon),
            'brand': brand,
            'operator': operator,
            'address':
                tags['addr:full'] ??
                '${tags['addr:housenumber'] ?? ''} ${tags['addr:street'] ?? ''}'
                    .trim(),
            'opening_hours': tags['opening_hours'] ?? '',
            'phone': tags['phone'] ?? '',
            'website': tags['website'] ?? '',
            'fuel_types': _extractFuelTypes(tags),
            'amenities': _extractAmenities(tags),
          });
        }

        setState(() {
          _stations = stations;
          _applyFilters();
        });
      } else {
        throw Exception(
          'Erreur lors de la récupération des données: ${response.statusCode}',
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors du chargement des stations: $e';
      });
    }
  }

  List<String> _extractFuelTypes(Map<String, dynamic> tags) {
    List<String> fuelTypes = [];
    if (tags['fuel:diesel'] == 'yes') fuelTypes.add('Diesel');
    if (tags['fuel:octane_95'] == 'yes') fuelTypes.add('SP95');
    if (tags['fuel:octane_98'] == 'yes') fuelTypes.add('SP98');
    if (tags['fuel:e85'] == 'yes') fuelTypes.add('E85');
    if (tags['fuel:lpg'] == 'yes') fuelTypes.add('GPL');
    if (fuelTypes.isEmpty) fuelTypes.add('Carburant disponible');
    return fuelTypes;
  }

  List<String> _extractAmenities(Map<String, dynamic> tags) {
    List<String> amenities = [];
    if (tags['shop'] == 'convenience') amenities.add('Boutique');
    if (tags['amenity'] == 'restaurant') amenities.add('Restaurant');
    if (tags['amenity'] == 'cafe') amenities.add('Café');
    if (tags['car_wash'] == 'yes') amenities.add('Lavage auto');
    if (tags['air_compressor'] == 'yes') amenities.add('Gonflage');
    return amenities;
  }

  void _applyFilters() {
    List<Map<String, dynamic>> filtered = List.from(_stations);

    // Filtre par marque
    if (_selectedFilter != 'Toutes') {
      filtered =
          filtered.where((station) {
            final brand = station['brand'].toString().toLowerCase();
            final operator = station['operator'].toString().toLowerCase();
            final filterLower = _selectedFilter.toLowerCase();

            if (_selectedFilter == 'Autres') {
              return ![
                'total',
                'shell',
                'bp',
                'esso',
                'carrefour',
                'leclerc',
              ].any(
                (knownBrand) =>
                    brand.contains(knownBrand) || operator.contains(knownBrand),
              );
            }

            return brand.contains(filterLower) ||
                operator.contains(filterLower);
          }).toList();
    }

    // Filtre par favoris
    if (_showFavoritesOnly) {
      filtered =
          filtered
              .where((station) => _favoriteStations.contains(station['id']))
              .toList();
    }

    // Filtre par recherche textuelle
    if (_searchQuery.isNotEmpty) {
      filtered =
          filtered.where((station) {
            final name = station['name'].toString().toLowerCase();
            final address = station['address'].toString().toLowerCase();
            final brand = station['brand'].toString().toLowerCase();
            final query = _searchQuery.toLowerCase();

            return name.contains(query) ||
                address.contains(query) ||
                brand.contains(query);
          }).toList();
    }

    // Trier par distance
    if (_currentLocation != null) {
      filtered.sort((a, b) {
        double distA = _calculateDistance(_currentLocation!, a['position']);
        double distB = _calculateDistance(_currentLocation!, b['position']);
        return distA.compareTo(distB);
      });
    }

    setState(() {
      _filteredStations = filtered;
    });
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Kilometer, point1, point2);
  }

  void _centerOnCurrentLocation() {
    if (_currentLocation != null && _mapController.mapEventStream != null) {
      _mapController.move(_currentLocation!, 15.0);
    }
  }

  void _centerOnStation(LatLng position) {
    _mapController.move(position, 16.0);
  }

  void _toggleFavorite(String stationId) {
    setState(() {
      if (_favoriteStations.contains(stationId)) {
        _favoriteStations.remove(stationId);
      } else {
        _favoriteStations.add(stationId);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _favoriteStations.contains(stationId)
              ? 'Station ajoutée aux favoris'
              : 'Station retirée des favoris',
        ),
        backgroundColor: Color(0xFFE55A2B),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showStationDetails(Map<String, dynamic> station) {
    final distance =
        _currentLocation != null
            ? _calculateDistance(_currentLocation!, station['position'])
            : 0.0;
    final isVisited = _visitedStations.contains(station['id']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header avec nom, favori et indicateur de visite
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          station['name'],
                                          style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFFD2481A),
                                          ),
                                        ),
                                      ),
                                      // Badge de visite
                                      if (isVisited)
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            '✓ Visitée',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (station['brand'].isNotEmpty)
                                    Text(
                                      station['brand'],
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Color(0xFFE55A2B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => _toggleFavorite(station['id']),
                              icon: Icon(
                                _favoriteStations.contains(station['id'])
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color:
                                    _favoriteStations.contains(station['id'])
                                        ? Colors.red
                                        : Colors.grey,
                                size: 28,
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 20),

                        // Distance
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Color(0xFFFFF5F0),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Color(0xFFE55A2B).withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.location_on, color: Color(0xFFE55A2B)),
                              SizedBox(width: 8),
                              Text(
                                'Distance: ${distance.toStringAsFixed(2)} km',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFD2481A),
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 16),

                        // Informations détaillées
                        if (station['address'].isNotEmpty) ...[
                          _buildInfoCard(
                            Icons.location_on_outlined,
                            'Adresse',
                            station['address'],
                          ),
                          SizedBox(height: 12),
                        ],

                        if (station['opening_hours'].isNotEmpty) ...[
                          _buildInfoCard(
                            Icons.access_time,
                            'Horaires',
                            station['opening_hours'],
                          ),
                          SizedBox(height: 12),
                        ],

                        if (station['phone'].isNotEmpty) ...[
                          _buildInfoCard(
                            Icons.phone,
                            'Téléphone',
                            station['phone'],
                          ),
                          SizedBox(height: 12),
                        ],

                        // Types de carburant
                        if (station['fuel_types'].isNotEmpty) ...[
                          Text(
                            'Carburants disponibles',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFD2481A),
                            ),
                          ),
                          SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children:
                                station['fuel_types'].map<Widget>((fuel) {
                                  return Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Color(0xFFE55A2B),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      fuel,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  );
                                }).toList(),
                          ),
                          SizedBox(height: 16),
                        ],

                        // Services
                        if (station['amenities'].isNotEmpty) ...[
                          Text(
                            'Services disponibles',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFD2481A),
                            ),
                          ),
                          SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children:
                                station['amenities'].map<Widget>((amenity) {
                                  return Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Color(0xFFFFF5F0),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Color(0xFFE55A2B),
                                      ),
                                    ),
                                    child: Text(
                                      amenity,
                                      style: TextStyle(
                                        color: Color(0xFFE55A2B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  );
                                }).toList(),
                          ),
                          SizedBox(height: 20),
                        ],

                        // Boutons d'action mis à jour
                        Column(
                          children: [
                            // Bouton "Je viens d'y passer"
                            Container(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed:
                                    isVisited
                                        ? null
                                        : () {
                                          Navigator.pop(context);
                                          _markStationVisit(station);
                                        },
                                icon: Icon(
                                  isVisited
                                      ? Icons.check_circle
                                      : Icons.add_location,
                                  color: Colors.white,
                                ),
                                label: Text(
                                  isVisited
                                      ? 'Déjà visitée aujourd\'hui'
                                      : 'Je viens d\'y passer',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      isVisited ? Colors.grey : Colors.green,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),

                            SizedBox(height: 12),

                            // Boutons existants
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _centerOnStation(station['position']);
                                    },
                                    icon: Icon(Icons.map, color: Colors.white),
                                    label: Text('Centrer sur carte'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Color(0xFFE55A2B),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Navigation GPS bientôt disponible',
                                          ),
                                          backgroundColor: Color(0xFFE55A2B),
                                        ),
                                      );
                                    },
                                    icon: Icon(
                                      Icons.navigation,
                                      color: Color(0xFFE55A2B),
                                    ),
                                    label: Text('Naviguer'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Color(0xFFE55A2B),
                                      side: BorderSide(
                                        color: Color(0xFFE55A2B),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
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

  Widget _buildInfoCard(IconData icon, String title, String content) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFFFFF5F0),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Color(0xFFE55A2B), size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFD2481A),
                  ),
                ),
                SizedBox(height: 4),
                Text(content, style: TextStyle(color: Colors.grey[700])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Filtres et options',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFD2481A),
                        ),
                      ),

                      SizedBox(height: 20),

                      // Rayon de recherche
                      Text(
                        'Rayon de recherche: ${_searchRadius.toInt()} km',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFE55A2B),
                        ),
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: Color(0xFFE55A2B),
                          inactiveTrackColor: Color(
                            0xFFE55A2B,
                          ).withOpacity(0.3),
                          thumbColor: Color(0xFFE55A2B),
                        ),
                        child: Slider(
                          value: _searchRadius,
                          min: 1.0,
                          max: 20.0,
                          divisions: 19,
                          onChanged: (value) {
                            setState(() {
                              _searchRadius = value;
                            });
                          },
                          onChangeEnd: (value) {
                            if (_currentLocation != null) {
                              _fetchGasStations(
                                _currentLocation!.latitude,
                                _currentLocation!.longitude,
                              );
                            }
                          },
                        ),
                      ),

                      SizedBox(height: 16),

                      // Filtres par marque
                      Text(
                        'Filtrer par marque',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFE55A2B),
                        ),
                      ),
                      SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            _filterOptions.map((filter) {
                              bool isSelected = _selectedFilter == filter;
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedFilter = filter;
                                  });
                                  _applyFilters();
                                },
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        isSelected
                                            ? Color(0xFFE55A2B)
                                            : Color(0xFFFFF5F0),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Color(0xFFE55A2B),
                                      width: isSelected ? 0 : 1,
                                    ),
                                  ),
                                  child: Text(
                                    filter,
                                    style: TextStyle(
                                      color:
                                          isSelected
                                              ? Colors.white
                                              : Color(0xFFE55A2B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                      ),

                      SizedBox(height: 16),

                      // Toggle favoris
                      SwitchListTile(
                        title: Text(
                          'Afficher seulement les favoris',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFD2481A),
                          ),
                        ),
                        value: _showFavoritesOnly,
                        activeColor: Color(0xFFE55A2B),
                        onChanged: (value) {
                          setState(() {
                            _showFavoritesOnly = value;
                          });
                          _applyFilters();
                        },
                      ),

                      SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFFF5F0),
      appBar: AppBar(
        title: Text("Carte des stations"),
        backgroundColor: Color(0xFFE55A2B),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Bouton statistiques
          IconButton(
            icon: Stack(
              children: [
                Icon(Icons.analytics),
                if (_totalVisitsCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      constraints: BoxConstraints(minWidth: 12, minHeight: 12),
                      child: Text(
                        '$_totalVisitsCount',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: _showUserStats,
          ),
          // Bouton recherche
          IconButton(
            icon: Icon(_isSearchVisible ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearchVisible = !_isSearchVisible;
                if (!_isSearchVisible) {
                  _searchQuery = '';
                  _applyFilters();
                }
              });
            },
          ),
          // Bouton filtres
          IconButton(
            icon: Stack(
              children: [
                Icon(Icons.tune),
                if (_selectedFilter != 'Toutes' || _showFavoritesOnly)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.yellow,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: _showFilterBottomSheet,
          ),
          // Bouton refresh
          IconButton(icon: Icon(Icons.refresh), onPressed: _determinePosition),
        ],
      ),
      body: Column(
        children: [
          // Barre de recherche
          if (_isSearchVisible)
            Container(
              padding: EdgeInsets.all(16),
              color: Color(0xFFE55A2B),
              child: TextField(
                onChanged: (query) {
                  setState(() {
                    _searchQuery = query;
                  });
                  _applyFilters();
                },
                decoration: InputDecoration(
                  hintText: 'Rechercher une station...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: Icon(Icons.search, color: Color(0xFFE55A2B)),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
            ),

          Expanded(
            child:
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
                            'Chargement des stations...',
                            style: TextStyle(color: Color(0xFFD2481A)),
                          ),
                        ],
                      ),
                    )
                    : _errorMessage != null
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error, color: Colors.red, size: 48),
                          SizedBox(height: 16),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.red),
                          ),
                          SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _determinePosition,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFFE55A2B),
                            ),
                            child: Text(
                              'Réessayer',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    )
                    : _currentLocation == null
                    ? Center(
                      child: Text(
                        'Localisation en cours...',
                        style: TextStyle(color: Color(0xFFD2481A)),
                      ),
                    )
                    : Stack(
                      children: [
                        FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: _currentLocation!,
                            initialZoom: 15.0,
                            minZoom: 3.0,
                            maxZoom: 18.0,
                            interactionOptions: InteractionOptions(
                              flags: InteractiveFlag.all,
                            ),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.example.carburapp',
                              maxZoom: 18,
                            ),
                            MarkerLayer(
                              markers: [
                                // Marqueur position actuelle
                                if (_currentLocation != null)
                                  Marker(
                                    width: 50.0,
                                    height: 50.0,
                                    point: _currentLocation!,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.blue,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 3,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.person,
                                        color: Colors.white,
                                        size: 25,
                                      ),
                                    ),
                                  ),
                                // Marqueurs stations avec indicateur de visite
                                ..._filteredStations.map((station) {
                                  bool isFavorite = _favoriteStations.contains(
                                    station['id'],
                                  );
                                  bool isVisited = _visitedStations.contains(
                                    station['id'],
                                  );

                                  return Marker(
                                    width: 50.0,
                                    height: 50.0,
                                    point: station["position"],
                                    child: GestureDetector(
                                      onTap: () => _showStationDetails(station),
                                      child: Stack(
                                        children: [
                                          Container(
                                            decoration: BoxDecoration(
                                              color:
                                                  isFavorite
                                                      ? Colors.red
                                                      : Color(0xFFE55A2B),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 2,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.3),
                                                  spreadRadius: 1,
                                                  blurRadius: 3,
                                                  offset: Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Icon(
                                              isFavorite
                                                  ? Icons.favorite
                                                  : Icons.local_gas_station,
                                              color: Colors.white,
                                              size: 25,
                                            ),
                                          ),
                                          // Badge de visite
                                          if (isVisited)
                                            Positioned(
                                              right: -2,
                                              top: -2,
                                              child: Container(
                                                width: 16,
                                                height: 16,
                                                decoration: BoxDecoration(
                                                  color: Colors.green,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: Colors.white,
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Icon(
                                                  Icons.check,
                                                  color: Colors.white,
                                                  size: 10,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ],
                        ),

                        // Compteur de stations
                        Positioned(
                          top: 16,
                          left: 16,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  spreadRadius: 1,
                                  blurRadius: 5,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.local_gas_station,
                                      color: Color(0xFFE55A2B),
                                      size: 18,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      '${_filteredStations.length}/${_stations.length}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFD2481A),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  'stations trouvées',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                // Afficher le nombre de visites
                                if (_totalVisitsCount > 0)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                        size: 12,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        '$_totalVisitsCount visites',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                if (_selectedFilter != 'Toutes' ||
                                    _showFavoritesOnly)
                                  Text(
                                    'Filtres actifs',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFFE55A2B),
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),

                        // Bouton centrer sur position
                        Positioned(
                          bottom: 100,
                          right: 16,
                          child: FloatingActionButton(
                            mini: true,
                            onPressed: _centerOnCurrentLocation,
                            backgroundColor: Color(0xFFE55A2B),
                            child: Icon(Icons.my_location, color: Colors.white),
                          ),
                        ),

                        // Liste des stations en bas
                        if (_filteredStations.isNotEmpty)
                          DraggableScrollableSheet(
                            initialChildSize: 0.15,
                            minChildSize: 0.15,
                            maxChildSize: 0.6,
                            builder: (context, scrollController) {
                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(20),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      spreadRadius: 1,
                                      blurRadius: 10,
                                      offset: Offset(0, -2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 4,
                                      margin: EdgeInsets.symmetric(vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[300],
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),

                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 8,
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.list,
                                            color: Color(0xFFE55A2B),
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Stations à proximité',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFFD2481A),
                                            ),
                                          ),
                                          Spacer(),
                                          // Compteurs
                                          if (_favoriteStations.isNotEmpty ||
                                              _visitedStations.isNotEmpty)
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (_favoriteStations
                                                    .isNotEmpty)
                                                  Container(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Color(0xFFFFF5F0),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons.favorite,
                                                          color: Colors.red,
                                                          size: 14,
                                                        ),
                                                        SizedBox(width: 2),
                                                        Text(
                                                          '${_favoriteStations.length}',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Color(
                                                              0xFFE55A2B,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                if (_favoriteStations
                                                        .isNotEmpty &&
                                                    _visitedStations.isNotEmpty)
                                                  SizedBox(width: 6),
                                                if (_visitedStations.isNotEmpty)
                                                  Container(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.green
                                                          .withOpacity(0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons.check_circle,
                                                          color: Colors.green,
                                                          size: 14,
                                                        ),
                                                        SizedBox(width: 2),
                                                        Text(
                                                          '${_visitedStations.length}',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Colors.green,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ),

                                    Divider(height: 1, color: Colors.grey[200]),

                                    Expanded(
                                      child: ListView.builder(
                                        controller: scrollController,
                                        itemCount: _filteredStations.length,
                                        itemBuilder: (context, index) {
                                          final station =
                                              _filteredStations[index];
                                          final distance =
                                              _currentLocation != null
                                                  ? _calculateDistance(
                                                    _currentLocation!,
                                                    station['position'],
                                                  )
                                                  : 0.0;
                                          final isFavorite = _favoriteStations
                                              .contains(station['id']);
                                          final isVisited = _visitedStations
                                              .contains(station['id']);

                                          return Card(
                                            margin: EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 4,
                                            ),
                                            elevation: 2,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: ListTile(
                                              contentPadding: EdgeInsets.all(
                                                12,
                                              ),
                                              leading: Stack(
                                                children: [
                                                  Container(
                                                    width: 50,
                                                    height: 50,
                                                    decoration: BoxDecoration(
                                                      color:
                                                          isFavorite
                                                              ? Colors.red
                                                              : Color(
                                                                0xFFE55A2B,
                                                              ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            25,
                                                          ),
                                                    ),
                                                    child: Icon(
                                                      isFavorite
                                                          ? Icons.favorite
                                                          : Icons
                                                              .local_gas_station,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  if (isVisited)
                                                    Positioned(
                                                      right: 0,
                                                      top: 0,
                                                      child: Container(
                                                        width: 16,
                                                        height: 16,
                                                        decoration:
                                                            BoxDecoration(
                                                              color:
                                                                  Colors.green,
                                                              shape:
                                                                  BoxShape
                                                                      .circle,
                                                              border: Border.all(
                                                                color:
                                                                    Colors
                                                                        .white,
                                                                width: 1,
                                                              ),
                                                            ),
                                                        child: Icon(
                                                          Icons.check,
                                                          color: Colors.white,
                                                          size: 10,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              title: Text(
                                                station['name'],
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFFD2481A),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              subtitle: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  if (station['brand']
                                                      .isNotEmpty)
                                                    Text(
                                                      station['brand'],
                                                      style: TextStyle(
                                                        color: Color(
                                                          0xFFE55A2B,
                                                        ),
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons.location_on,
                                                        size: 14,
                                                        color: Colors.grey[600],
                                                      ),
                                                      SizedBox(width: 4),
                                                      Text(
                                                        '${distance.toStringAsFixed(2)} km',
                                                        style: TextStyle(
                                                          color:
                                                              Colors.grey[600],
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                      SizedBox(width: 16),
                                                      if (station['fuel_types']
                                                          .isNotEmpty)
                                                        Expanded(
                                                          child: Text(
                                                            station['fuel_types']
                                                                .take(2)
                                                                .join(', '),
                                                            style: TextStyle(
                                                              color:
                                                                  Colors
                                                                      .grey[600],
                                                              fontSize: 12,
                                                            ),
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                              trailing: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    onPressed:
                                                        () => _toggleFavorite(
                                                          station['id'],
                                                        ),
                                                    icon: Icon(
                                                      isFavorite
                                                          ? Icons.favorite
                                                          : Icons
                                                              .favorite_border,
                                                      color:
                                                          isFavorite
                                                              ? Colors.red
                                                              : Colors.grey,
                                                    ),
                                                  ),
                                                  IconButton(
                                                    onPressed:
                                                        () => _centerOnStation(
                                                          station['position'],
                                                        ),
                                                    icon: Icon(
                                                      Icons.center_focus_strong,
                                                      color: Color(0xFFE55A2B),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              onTap:
                                                  () => _showStationDetails(
                                                    station,
                                                  ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
          ),
        ],
      ),
    );
  }
}
