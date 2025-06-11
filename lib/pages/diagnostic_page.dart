// pages/diagnostic_page.dart
// Créez cette page pour diagnostiquer les problèmes

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../services/station_visit_service.dart';

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
      _addResult('✅ Chemin de base de données: $dbPath');
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
        stationName: 'Station Test',
        stationBrand: 'Test Brand',
        latitude: 48.8566,
        longitude: 2.3522,
        notes: 'Test de diagnostic',
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
    } catch (e) {
      _addResult('❌ Erreur historique: $e');
    }

    setState(() {
      _isRunning = false;
    });

    _addResult('🏁 Diagnostics terminés');
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
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE55A2B)),
                ),
              ),

            Expanded(
              child: ListView.builder(
                itemCount: _diagnosticResults.length,
                itemBuilder: (context, index) {
                  final result = _diagnosticResults[index];
                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 4),
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        result,
                        style: TextStyle(fontFamily: 'monospace', fontSize: 14),
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
                              } catch (e) {
                                _addResult('❌ Erreur reset: $e');
                              }
                            },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: Text('Réinitialiser les données'),
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
