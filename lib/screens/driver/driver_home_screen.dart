import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';
import '../shared/welcome_screen.dart';
import 'profile_screen.dart';
import 'past_rides_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _loadDriverData();
  }

  Future<void> _loadDriverData() async {
    setState(() => _isLoading = true);

    // 1) Obtener token
    final token = await AuthService.getToken();

    if (token == null) {
      // Si no hay token, forzamos logout
      _logout();
      return;
    }

    // 2) Traer perfil (para conocer el userId)
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
      // Error al obtener perfil: logout
      _logout();
      return;
    }

    // 3) Traer todos los viajes y filtrar los asignados a este conductor
    final ridesRes = await http.get(
      Uri.parse('http://158.23.170.129/api/rides'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (ridesRes.statusCode == 200) {
      final lista = jsonDecode(ridesRes.body) as List<dynamic>;

      // Suponemos que cada ride tiene campos: id, origin, destination, driver_id, status
      // Filtramos solo los que estén asignados a este driver (_userId)
      // y su status sea “assigned” (u otro valor que en tu API signifique “pendiente de ser atendido”)
      _assignedRides = lista.where((ride) {
        final r = ride as Map<String, dynamic>;
        return r['driver_id'] == _userId && r['status'] == 'assigned';
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
            const DrawerHeader(
              decoration: BoxDecoration(color: Color(0xFF73003C)),
              child: Text(
                'Menú Conductor',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),

            // 1) Opción “Mi perfil”
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

            // 2) Opción “Viajes pasados”
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

            // 3) Cerrar sesión
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
                          'No hay viajes asignados en este momento.',
                          style: TextStyle(fontSize: 18),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _assignedRides.length,
                        itemBuilder: (context, index) {
                          final ride =
                              _assignedRides[index] as Map<String, dynamic>;
                          final origin =
                              ride['origin'] as String? ?? 'Origen desconocido';
                          final destination = ride['destination'] as String? ??
                              'Destino desconocido';
                          final rideId = ride['id'];

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
                                ],
                              ),
                              trailing: ElevatedButton(
                                onPressed: () {
                                  // Aquí podrías navegar a una pantalla de detalles de viaje
                                  // por ejemplo: RideDetailScreen(rideId: rideId)
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text('Ir al viaje #$rideId')),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF73003C),
                                ),
                                child: const Text('Ver detalles'),
                              ),
                            ),
                          );
                        },
                      ),
              ),
      ),
    );
  }
}
