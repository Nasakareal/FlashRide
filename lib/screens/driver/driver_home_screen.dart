import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../../services/auth_service.dart';
import '../shared/welcome_screen.dart';
import 'profile_screen.dart';
import 'past_rides_screen.dart';
import 'ride_details_screen.dart';
import 'ride_awaiting_screen.dart';
import 'ride_pickup_screen.dart';
import 'ride_inprogress_screen.dart';
import 'ride_completed_screen.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  bool _isLoading = true;
  int? _userId;
  Map<String, dynamic>? _profileData;
  List<dynamic> _assignedRides = [];

  Timer? _locationTimer;

  @override
  void initState() {
    super.initState();
    _loadDriverData();
    _locationTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_assignedRides.isNotEmpty) {
        final rideId = _assignedRides[0]['id'];
        _enviarUbicacion(rideId); // ubicación del viaje
      }
      _enviarUbicacionGlobal(); // ubicación global SIEMPRE
    });
  }

  @override
  void dispose() {
    _locationTimer?.cancel(); // ⬅️ Cancelar al cerrar pantalla
    super.dispose();
  }

  Widget _getRideScreen(Map<String, dynamic> ride) {
    final fase = ride['fase'];
    switch (fase) {
      case 'esperando':
        return RideAwaitingScreen(ride: ride);
      case 'recogiendo':
        return RidePickupScreen(ride: ride);
      case 'viajando':
        return RideInProgressScreen(ride: ride);
      case 'completado':
        return RideCompletedScreen(ride: ride);
      default:
        return RideDetailsScreen(ride: ride);
    }
  }

  Future<void> _enviarUbicacionGlobal() async {
    try {
      final token = await AuthService.getToken();
      final pos = await Geolocator.getCurrentPosition();

      final response = await http.post(
        Uri.parse('http://158.23.170.129/api/location/global'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'lat': pos.latitude,
          'lng': pos.longitude,
        }),
      );

      if (response.statusCode != 200) {
        debugPrint('❌ Error al enviar ubicación global: ${response.body}');
      } else {
        debugPrint('🌍 Ubicación global actualizada');
      }
    } catch (e) {
      debugPrint('🚨 Error global: $e');
    }
  }

  Future<void> _enviarUbicacion(int rideId) async {
    try {
      final token = await AuthService.getToken();
      final pos = await Geolocator.getCurrentPosition();

      final response = await http.post(
        Uri.parse('http://158.23.170.129/api/location/update'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'ride_id': rideId,
          'driver_lat': pos.latitude,
          'driver_lng': pos.longitude,
        }),
      );

      if (response.statusCode != 200) {
        debugPrint('❌ Error al enviar ubicación: ${response.body}');
      } else {
        debugPrint('📍 Ubicación actualizada');
      }
    } catch (e) {
      debugPrint('🚨 Error al obtener ubicación: $e');
    }
  }

  Future<void> _loadDriverData() async {
    setState(() => _isLoading = true);
    final token = await AuthService.getToken();

    if (token == null) {
      _logout();
      return;
    }

    final profileRes = await http.get(
      Uri.parse('http://158.23.170.129/api/profile'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (profileRes.statusCode == 200) {
      final perfilJson = jsonDecode(profileRes.body) as Map<String, dynamic>;
      _userId = perfilJson['id'] as int;
      _profileData = perfilJson;
    } else {
      _logout();
      return;
    }

    final ridesRes = await http.get(
      Uri.parse('http://158.23.170.129/api/rides'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (ridesRes.statusCode == 200) {
      final lista = jsonDecode(ridesRes.body) as List<dynamic>;

      _assignedRides = lista.where((ride) {
        final r = ride as Map<String, dynamic>;
        return r['driver_id'] == _userId &&
            (r['status'] == 'accepted' || r['status'] == 'in_progress');
      }).toList();
    } else {
      _assignedRides = [];
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
        title: const Text('Bienvenido, Chofer'),
        backgroundColor: const Color(0xFF73003C),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF73003C)),
              child: Text(
                _profileData != null
                    ? 'Bienvenido, ${_profileData!['name']}'
                    : 'Menú Conductor',
                style: const TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Mi perfil'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('Viajes pendientes'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/rides/pending');
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Viajes pasados'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PastRidesScreen()),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Cerrar sesión'),
              onTap: _logout,
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(12),
                child: _assignedRides.isEmpty
                    ? const Center(
                        child: Text(
                          'No hay viajes activos por atender.',
                          style: TextStyle(fontSize: 18),
                        ),
                      )
                    : FutureBuilder(
                        future: Future.delayed(Duration.zero, () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => _getRideScreen(_assignedRides[0]),
                            ),
                          );
                        }),
                        builder: (context, snapshot) {
                          return const Center(
                              child: CircularProgressIndicator());
                        },
                      ),
              ),
      ),
    );
  }
}
