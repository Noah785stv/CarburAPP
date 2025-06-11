// station_list_page.dart
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'services/user_settings_service.dart';

class StationsListPage extends StatefulWidget {
  @override
  _StationsListPageState createState() => _StationsListPageState();
}

class _StationsListPageState extends State<StationsListPage> {
  List<Map<String, dynamic>> _stations = [];
  LatLng? _currentLocation;
  bool _isLoading = false;
  String? _errorMessage;
  double _searchRadius = 5.0; // Sera mise à jour depuis les paramètres

  @override
  void initState() {
    super.initState();
    _loadUserSettingsAndStations();

    // Écouter les changements de paramètres
    UserSettingsService.instance.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    UserSettingsService.instance.removeListener(_onSettingsChanged);
    super.dispose();
  }

  /// Callback appelé quand les paramètres changent
  void _onSettingsChanged() async {
    print('📋 Paramètres modifiés dans la liste, rechargement...');
    final newRadius = await UserSettingsService.getSearchRadius();

    if (newRadius != _searchRadius) {
      setState(() {
        _searchRadius = newRadius;
      });

      // Recharger les stations avec le nouveau rayon
      if (_currentLocation != null) {
        _fetchGasStations(
          _currentLocation!.latitude,
          _currentLocation!.longitude,
        );
      }
    }
  }

  /// Charger les paramètres utilisateur puis les stations
  Future<void> _loadUserSettingsAndStations() async {
    try {
      // Récupérer le rayon de recherche des paramètres utilisateur
      final userRadius = await UserSettingsService.getSearchRadius();

      setState(() {
        _searchRadius = userRadius;
      });

      print(
        '📋 Rayon de recherche utilisateur pour la liste: ${_searchRadius}km',
      );

      // Maintenant charger les stations avec le bon rayon
      _loadStations();
    } catch (e) {
      print('Erreur lors du chargement des paramètres: $e');
      // Utiliser la valeur par défaut et continuer
      _loadStations();
    }
  }

  Future<void> _loadStations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      Position position = await Geolocator.getCurrentPosition();
      _currentLocation = LatLng(position.latitude, position.longitude);

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

  Future<void> _fetchGasStations(double lat, double lon) async {
    try {
      // Utiliser le rayon de recherche des paramètres utilisateur
      final radiusInMeters = (_searchRadius * 1000).toInt();

      final String overpassQuery = '''
        [out:json][timeout:25];
        (
          node["amenity"="fuel"](around:$radiusInMeters,$lat,$lon);
          way["amenity"="fuel"](around:$radiusInMeters,$lat,$lon);
          relation["amenity"="fuel"](around:$radiusInMeters,$lat,$lon);
        );
        out center meta;
      ''';

      print(
        '🔍 Recherche dans un rayon de ${_searchRadius}km (${radiusInMeters}m)',
      );

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
          } else if (element['center'] != null) {
            stationLat = element['center']['lat']?.toDouble() ?? 0.0;
            stationLon = element['center']['lon']?.toDouble() ?? 0.0;
          } else {
            continue;
          }

          final tags = element['tags'] ?? {};
          final String name =
              tags['name'] ??
              tags['brand'] ??
              tags['operator'] ??
              'Station-service';

          stations.add({
            'name': name,
            'position': LatLng(stationLat, stationLon),
            'brand': tags['brand'] ?? '',
            'address':
                tags['addr:full'] ??
                '${tags['addr:housenumber'] ?? ''} ${tags['addr:street'] ?? ''}'
                    .trim(),
            'opening_hours': tags['opening_hours'] ?? '',
            'phone': tags['phone'] ?? '',
          });
        }

        // Trier par distance
        if (_currentLocation != null) {
          const Distance distance = Distance();
          stations.sort((a, b) {
            double distA = distance.as(
              LengthUnit.Kilometer,
              _currentLocation!,
              a['position'],
            );
            double distB = distance.as(
              LengthUnit.Kilometer,
              _currentLocation!,
              b['position'],
            );
            return distA.compareTo(distB);
          });
        }

        setState(() {
          _stations = stations;
        });

        print(
          '✅ ${stations.length} stations trouvées dans un rayon de ${_searchRadius}km',
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors du chargement: $e';
      });
    }
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Kilometer, point1, point2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Stations-service'),
        backgroundColor: Color(0xFFE55A2B), // Cohérence avec la charte
        foregroundColor: Colors.white,
        actions: [
          // Afficher le rayon actuel
          Center(
            child: Container(
              margin: EdgeInsets.only(right: 8),
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_searchRadius.toInt()}km',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadUserSettingsAndStations,
            tooltip: 'Actualiser avec vos paramètres',
          ),
        ],
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
                    Text('Chargement des stations...'),
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
                    Text(_errorMessage!, textAlign: TextAlign.center),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadUserSettingsAndStations,
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
              : ListView.builder(
                itemCount: _stations.length,
                itemBuilder: (context, index) {
                  final station = _stations[index];
                  final distance =
                      _currentLocation != null
                          ? _calculateDistance(
                            _currentLocation!,
                            station['position'],
                          )
                          : 0.0;

                  return Card(
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Color(0xFFE55A2B),
                        child: Icon(
                          Icons.local_gas_station,
                          color: Colors.white,
                        ),
                      ),
                      title: Text(
                        station['name'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFD2481A),
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (station['brand'].isNotEmpty)
                            Text(
                              '${station['brand']}',
                              style: TextStyle(
                                color: Color(0xFFE55A2B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          if (station['address'].isNotEmpty)
                            Text(station['address']),
                          Text(
                            '${distance.toStringAsFixed(2)} km',
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      trailing: Icon(
                        Icons.arrow_forward_ios,
                        color: Color(0xFFE55A2B),
                      ),
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(20),
                            ),
                          ),
                          builder:
                              (context) => Container(
                                padding: EdgeInsets.all(20),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      station['name'],
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFD2481A),
                                      ),
                                    ),
                                    SizedBox(height: 12),
                                    if (station['brand'].isNotEmpty) ...[
                                      _buildDetailRow(
                                        Icons.business,
                                        'Marque',
                                        station['brand'],
                                      ),
                                      SizedBox(height: 8),
                                    ],
                                    if (station['address'].isNotEmpty) ...[
                                      _buildDetailRow(
                                        Icons.location_on,
                                        'Adresse',
                                        station['address'],
                                      ),
                                      SizedBox(height: 8),
                                    ],
                                    if (station['opening_hours']
                                        .isNotEmpty) ...[
                                      _buildDetailRow(
                                        Icons.access_time,
                                        'Horaires',
                                        station['opening_hours'],
                                      ),
                                      SizedBox(height: 8),
                                    ],
                                    if (station['phone'].isNotEmpty) ...[
                                      _buildDetailRow(
                                        Icons.phone,
                                        'Téléphone',
                                        station['phone'],
                                      ),
                                      SizedBox(height: 8),
                                    ],
                                    _buildDetailRow(
                                      Icons.straighten,
                                      'Distance',
                                      '${distance.toStringAsFixed(2)} km',
                                    ),
                                    SizedBox(height: 20),
                                    Container(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: () => Navigator.pop(context),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Color(0xFFE55A2B),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          'Fermer',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                        );
                      },
                    ),
                  );
                },
              ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Color(0xFFE55A2B), size: 20),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFD2481A),
                  fontSize: 14,
                ),
              ),
              Text(
                value,
                style: TextStyle(color: Colors.grey[700], fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
