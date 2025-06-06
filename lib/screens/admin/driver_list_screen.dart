// lib/screens/admin/driver_list_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'create_driver_screen.dart';
import 'biometric_driver_screen.dart'; // Pantalla para datos biométricos de un chofer
import 'package:http/http.dart' as http;

class DriverListScreen extends StatefulWidget {
  const DriverListScreen({super.key});

  @override
  State<DriverListScreen> createState() => _DriverListScreenState();
}

class _DriverListScreenState extends State<DriverListScreen> {
  List<Map<String, dynamic>> _drivers = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchDrivers();
    _searchCtrl.addListener(_onSearch);
  }

  void _onSearch() {
    final query = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _drivers.where((d) {
        final name = (d['name'] as String).toLowerCase();
        final email = (d['email'] as String).toLowerCase();
        return name.contains(query) || email.contains(query);
      }).toList();
    });
  }

  Future<void> _fetchDrivers() async {
    final token = await AuthService.getToken();
    final res = await http.get(
      Uri.parse('http://158.23.170.129/api/drivers'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    if (res.statusCode == 200) {
      final lista = jsonDecode(res.body) as List<dynamic>;
      // Cada elemento se asume: { id, name, email, phone, ... }
      _drivers = lista.map((e) => Map<String, dynamic>.from(e)).toList();
      _filtered = List.from(_drivers);
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
        title: const Text('Choferes Registrados'),
        backgroundColor: const Color(0xFF73003C),
        foregroundColor: Colors.white,
        actions: [
          // Botón para agregar nuevo chofer
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateDriverScreen()),
              ).then((_) => _fetchDrivers());
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
                hintText: 'Buscar por nombre o correo',
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
                      ? const Center(child: Text('No hay choferes.'))
                      : ListView.separated(
                          separatorBuilder: (_, __) => const Divider(),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) {
                            final d = _filtered[i];
                            return ListTile(
                              title: Text(d['name'] ?? ''),
                              subtitle: Text(d['email'] ?? ''),
                              trailing: Wrap(
                                spacing: 12,
                                children: [
                                  // Botón editar/actualizar datos del chofer
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 20),
                                    onPressed: () {
                                      // TODO: implementar edición de chofer
                                    },
                                  ),
                                  // Botón para registrar/ver datos biométricos
                                  IconButton(
                                    icon:
                                        const Icon(Icons.fingerprint, size: 20),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => BiometricDriverScreen(
                                            driverId: d['id'],
                                            driverName: d['name'],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
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
