// lib/screens/admin/show_driver_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';
import 'assign_vehicle_screen.dart';

class ShowDriverScreen extends StatefulWidget {
  final int driverId;
  final String driverName;
  const ShowDriverScreen(
      {super.key, required this.driverId, required this.driverName});

  @override
  State<ShowDriverScreen> createState() => _ShowDriverScreenState();
}

class _ShowDriverScreenState extends State<ShowDriverScreen> {
  bool _loading = true;
  bool _loadingAssign = false;

  // Detalles
  int _totalTrips = 0;
  double _rating = 0.0;
  bool _everPressedPanic = false;

  // Asignación actual
  Map<String, dynamic>? _currentAssignment; // puede ser null

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    await Future.wait([_fetchDriverDetails(), _fetchAssignment()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _fetchDriverDetails() async {
    try {
      final token = await AuthService.getToken();
      final uri = Uri.parse(
          '${AuthService.baseUrl}/drivers/${widget.driverId}/details');
      final res = await http.get(uri, headers: {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      });
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        _totalTrips = data['total_trips'] ?? 0;
        _rating = (data['rating'] ?? 0).toDouble();
        _everPressedPanic = (data['ever_pressed_panic'] ?? false) == true;
      } else {
        _toast('Error ${res.statusCode} al cargar detalles');
      }
    } catch (e) {
      _toast('Error de conexión al cargar detalles: $e');
    }
  }

  Future<void> _fetchAssignment() async {
    try {
      final token = await AuthService.getToken();
      final uri = Uri.parse(
          '${AuthService.baseUrl}/drivers/${widget.driverId}/assignment');
      final res = await http.get(uri, headers: {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      });

      if (res.statusCode == 200) {
        final body = res.body.trim().isEmpty ? 'null' : res.body;
        _currentAssignment = jsonDecode(body) as Map<String, dynamic>?;
      } else {
        _toast('Error ${res.statusCode} al cargar asignación');
      }
    } catch (e) {
      _toast('Error de conexión al cargar asignación: $e');
    }
  }

  Future<void> _openAssign() async {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => AssignVehicleScreen(driverId: widget.driverId)),
    );
    if (changed == true) {
      setState(() => _loadingAssign = true);
      await _fetchAssignment();
      if (mounted) setState(() => _loadingAssign = false);
    }
  }

  Future<void> _unassign() async {
    setState(() => _loadingAssign = true);
    try {
      final token = await AuthService.getToken();
      final uri = Uri.parse(
          '${AuthService.baseUrl}/drivers/${widget.driverId}/unassign');
      final res = await http.post(uri, headers: {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      });
      if (res.statusCode == 200) {
        _currentAssignment = null;
        _toast('Asignación cerrada');
      } else {
        _toast('No se pudo liberar: ${res.statusCode}\n${res.body}');
      }
    } catch (e) {
      _toast('Error de conexión al liberar: $e');
    } finally {
      if (mounted) setState(() => _loadingAssign = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final v = _currentAssignment?['vehicle'] as Map<String, dynamic>?;
    final assignedText = v == null
        ? 'Sin vehículo asignado'
        : 'Vehículo: ${v['plate'] ?? '#${v['id']}'}\nModelo: ${v['model'] ?? '-'}\nColor: ${v['color'] ?? '-'}';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
          title: Text('Detalles de ${widget.driverName}'),
          backgroundColor: const Color(0xFF73003C),
          foregroundColor: Colors.white),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: ListTile(
                      title: const Text('Estadísticas'),
                      subtitle: Text(
                          'Total de viajes: $_totalTrips\nCalificación: $_rating\nPánico: ${_everPressedPanic ? "Sí" : "No"}'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Asignación actual',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Text(assignedText),
                          const SizedBox(height: 12),
                          if (_loadingAssign)
                            const Center(child: CircularProgressIndicator()),
                          if (!_loadingAssign)
                            Row(
                              children: [
                                ElevatedButton(
                                  onPressed: _openAssign,
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.amber,
                                      foregroundColor: Colors.black),
                                  child: Text(v == null
                                      ? 'Asignar vehículo'
                                      : 'Cambiar vehículo'),
                                ),
                                const SizedBox(width: 12),
                                if (v != null)
                                  OutlinedButton(
                                    onPressed: _unassign,
                                    child: const Text('Liberar'),
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
}
