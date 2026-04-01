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
  static final String _api = AuthService.baseUrl;

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
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        _logout();
        return;
      }

      // 1) Perfil para obtener userId
      final profileRes = await http.get(
        Uri.parse('$_api/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (profileRes.statusCode == 200) {
        final perfilJson = jsonDecode(profileRes.body) as Map<String, dynamic>;
        _userId = (perfilJson['id'] as num?)?.toInt();
      } else if (profileRes.statusCode == 401) {
        _logout();
        return;
      } else {
        // No cierres sesión por 301/404/500, solo muestra aviso
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error de perfil (${profileRes.statusCode})')),
          );
        }
        setState(() {
          _pastRides = [];
          _isLoading = false;
        });
        return;
      }

      // 2) Viajes y filtrar completados del conductor
      final ridesRes = await http.get(
        Uri.parse('$_api/rides'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (ridesRes.statusCode == 200) {
        final lista = jsonDecode(ridesRes.body) as List<dynamic>;

        // Ajusta el status si en tu backend usa 'completado' en lugar de 'completed'
        const completedStatuses = {'completed', 'completado'};

        _pastRides = lista.where((ride) {
          final r = ride as Map<String, dynamic>;
          final driverId = (r['driver_id'] as num?)?.toInt();
          final status = (r['status'] ?? '').toString().toLowerCase();
          return driverId == _userId && completedStatuses.contains(status);
        }).toList();
      } else if (ridesRes.statusCode == 401) {
        _logout();
        return;
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('Error al obtener viajes (${ridesRes.statusCode})')),
          );
        }
        _pastRides = [];
      }
    } catch (e) {
      // Errores de red/SSL/etc: NO cierres sesión por esto
      debugPrint('🚨 _loadPastRides error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error de red. Intenta de nuevo.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
                      final r = _pastRides[index] as Map<String, dynamic>;
                      final origin = (r['origin'] ?? '-') as String;
                      final destination = (r['destination'] ?? '-') as String;
                      final rideId = r['id'];
                      final dateTime = (r['ended_at'] ?? '-') as String;

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
