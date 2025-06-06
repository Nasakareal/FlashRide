// lib/screens/admin/vehicle_list_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'create_vehicle_screen.dart';
import 'package:http/http.dart' as http;

class VehicleListScreen extends StatefulWidget {
  const VehicleListScreen({super.key});

  @override
  State<VehicleListScreen> createState() => _VehicleListScreenState();
}

class _VehicleListScreenState extends State<VehicleListScreen> {
  List<Map<String, dynamic>> _vehicles = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchVehicles();
    _searchCtrl.addListener(_onSearch);
  }

  void _onSearch() {
    final query = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _vehicles.where((v) {
        final plate = (v['plate'] as String).toLowerCase();
        final model = (v['model'] as String).toLowerCase();
        return plate.contains(query) || model.contains(query);
      }).toList();
    });
  }

  Future<void> _fetchVehicles() async {
    final token = await AuthService.getToken();
    final res = await http.get(
      Uri.parse('http://158.23.170.129/api/vehicles'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    if (res.statusCode == 200) {
      final lista = jsonDecode(res.body) as List<dynamic>;
      _vehicles = lista.map((e) => Map<String, dynamic>.from(e)).toList();
      _filtered = List.from(_vehicles);
    }
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehículos Registrados'),
        backgroundColor: const Color(0xFF73003C),
        foregroundColor: Colors.white,
        actions: [
          // Botón para agregar nuevo vehículo
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
            // Barra de búsqueda
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

            // Lista o indicador de carga
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filtered.isEmpty
                      ? const Center(child: Text('No hay vehículos.'))
                      : ListView.separated(
                          separatorBuilder: (_, __) => const Divider(),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) {
                            final v = _filtered[i];
                            return ListTile(
                              title: Text('${v['plate']} - ${v['model']}'),
                              subtitle: Text('Color: ${v['color'] ?? 'N/A'}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: () {
                                  // TODO: editar vehículo
                                },
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
