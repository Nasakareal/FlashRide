// lib/screens/past_rides_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../shared/welcome_screen.dart';

class PastRidesScreen extends StatefulWidget {
  const PastRidesScreen({super.key});

  @override
  State<PastRidesScreen> createState() => _PastRidesScreenState();
}

class _PastRidesScreenState extends State<PastRidesScreen> {
  bool _isLoading = true;
  int? _userId;
  List<dynamic> _pastRides = [];

  @override
  void initState() {
    super.initState();
    _loadPastRides();
  }

  Future<void> _loadPastRides() async {
    setState(() => _isLoading = true);

    final token = await AuthService.getToken();
    if (token == null) {
      _logout();
      return;
    }

    // 1) Obtener perfil para conocer el userId
    final profileRes = await http.get(
      Uri.parse('http://158.23.170.129/api/profile'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (profileRes.statusCode != 200) {
      _logout();
      return;
    }
    final perfilJson = jsonDecode(profileRes.body) as Map<String, dynamic>;
    _userId = perfilJson['id'] as int;

    // 2) Traer todos los viajes y filtrar para este conductor los completados
    final ridesRes = await http.get(
      Uri.parse('http://158.23.170.129/api/rides'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (ridesRes.statusCode == 200) {
      final lista = jsonDecode(ridesRes.body) as List<dynamic>;
      // Supuesto: status == 'completed' indica viaje terminado
      _pastRides = lista.where((ride) {
        final r = ride as Map<String, dynamic>;
        return r['driver_id'] == _userId && r['status'] == 'completed';
      }).toList();
    } else {
      _pastRides = [];
    }

    setState(() => _isLoading = false);
  }

  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Viajes pasados'),
        backgroundColor: const Color(0xFF73003C),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _pastRides.isEmpty
                ? const Center(
                    child: Text(
                      'No tienes viajes completados aún.',
                      style: TextStyle(fontSize: 18),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _pastRides.length,
                    itemBuilder: (context, index) {
                      final ride = _pastRides[index] as Map<String, dynamic>;
                      final origin = ride['origin'] as String? ?? '-';
                      final destination = ride['destination'] as String? ?? '-';
                      final rideId = ride['id'];
                      final dateTime = ride['ended_at'] as String? ?? '-';

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        elevation: 2,
                        child: ListTile(
                          title: Text('Viaje #$rideId'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text('Origen: $origin'),
                              Text('Destino: $destination'),
                              const SizedBox(height: 4),
                              Text('Fecha de finalización: $dateTime'),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.info_outline),
                            onPressed: () {
                              // Aquí podrías abrir un detalle de viaje ya terminado
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('Detalles viaje #$rideId')),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
