// lib/screens/admin/vehicle_list_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../services/auth_service.dart';
import 'create_vehicle_screen.dart';
import 'edit_vehicle_screen.dart';

class VehicleListScreen extends StatefulWidget {
  const VehicleListScreen({super.key});

  @override
  State<VehicleListScreen> createState() => _VehicleListScreenState();
}

class _VehicleListScreenState extends State<VehicleListScreen> {
  List<Map<String, dynamic>> _vehicles = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading = true;
  String? _error;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchVehicles();
    _searchCtrl.addListener(_onSearch);
  }

  void _onSearch() {
    final query = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = _vehicles.where((v) {
        final plate = (v['plate'] ?? '').toString().toLowerCase();
        final model = (v['model'] ?? '').toString().toLowerCase();
        return plate.contains(query) || model.contains(query);
      }).toList();
    });
  }

  Future<void> _fetchVehicles() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await AuthService.getToken();

      // Intenta ambos hosts conocidos de tu API
      final uriCandidates = <Uri>[
        Uri.parse('http://158.23.170.129/api/vehicles?per_page=200'),
        Uri.parse(
            'https://158.23.170.129/flashride/public/api/vehicles?per_page=200'),
      ];

      http.Response? res;
      for (final u in uriCandidates) {
        final r = await http.get(
          u,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        );
        if (r.statusCode == 200) {
          res = r;
          break;
        } else {
          // conserva el último intento por si todos fallan
          res = r;
        }
      }

      if (res == null) {
        throw Exception('Sin respuesta del servidor.');
      }
      if (res.statusCode == 401 || res.statusCode == 403) {
        throw Exception('No autorizado (token inválido o sin permisos).');
      }
      if (res.statusCode != 200) {
        throw Exception('Error ${res.statusCode}: ${res.body}');
      }

      final decoded = jsonDecode(res.body);

      // Normaliza a List<Map<String, dynamic>>
      List<dynamic> listDyn;
      if (decoded is List) {
        listDyn = decoded;
      } else if (decoded is Map<String, dynamic>) {
        if (decoded['data'] is List) {
          listDyn = decoded['data'] as List<dynamic>;
        } else if (decoded['data'] is Map && decoded['data']['data'] is List) {
          listDyn = decoded['data']['data'] as List<dynamic>;
        } else if (decoded['items'] is List) {
          listDyn = decoded['items'] as List<dynamic>;
        } else {
          listDyn = const [];
        }
      } else {
        listDyn = const [];
      }

      final list =
          listDyn.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      setState(() {
        _vehicles = list;
        _filtered = List.from(_vehicles);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _vehicles = [];
        _filtered = [];
        _error = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearch);
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No se pudieron cargar los vehículos.\n$_error',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : _filtered.isEmpty
                ? const Center(child: Text('No hay vehículos.'))
                : ListView.separated(
                    separatorBuilder: (_, __) => const Divider(),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final v = _filtered[i];
                      final plate = (v['plate'] ?? 'SN/PLACA').toString();
                      final model = (v['model'] ?? 'SN/MODELO').toString();
                      final color = (v['color'] ?? 'N/A').toString();
                      return ListTile(
                        title: Text('$plate - $model'),
                        subtitle: Text('Color: $color'),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EditVehicleScreen(vehicle: v),
                              ),
                            ).then(
                                (_) => _fetchVehicles()); // refresca al volver
                          },
                        ),
                      );
                    },
                  );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehículos Registrados'),
        backgroundColor: const Color(0xFFFF1B8F),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.directions_car),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateVehicleScreen()),
              ).then((_) => _fetchVehicles());
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Buscar por placa o modelo',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}
