import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';

class AssignVehicleScreen extends StatefulWidget {
  final int driverId;
  const AssignVehicleScreen({super.key, required this.driverId});

  @override
  State<AssignVehicleScreen> createState() => _AssignVehicleScreenState();
}

class _AssignVehicleScreenState extends State<AssignVehicleScreen> {
  bool loading = true;
  List<dynamic> vehicles = [];
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final token = await AuthService.getToken();
      final uri = Uri.parse('${AuthService.baseUrl}/vehicles/available');
      final res = await http.get(uri, headers: {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      });
      if (res.statusCode == 200) {
        vehicles = jsonDecode(res.body) as List;
      } else {
        error = 'Error ${res.statusCode}: ${res.body}';
      }
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted)
        setState(() {
          loading = false;
        });
    }
  }

  Future<void> _assign(int vehicleId) async {
    final token = await AuthService.getToken();
    final uri =
        Uri.parse('${AuthService.baseUrl}/drivers/${widget.driverId}/assign');
    final res = await http.post(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'vehicle_id': vehicleId}),
    );
    if (res.statusCode == 201) {
      if (!mounted) return;
      Navigator.pop(context, true); // regresar avisando que cambió
    } else {
      showDialog(
          context: context,
          builder: (_) => AlertDialog(
                title: const Text('No se pudo asignar'),
                content: Text('Status ${res.statusCode}\n${res.body}'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'))
                ],
              ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Asignar vehículo'),
          backgroundColor: const Color(0xFF73003C),
          foregroundColor: Colors.white),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text(error!))
              : ListView.separated(
                  itemCount: vehicles.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final v = vehicles[i] as Map<String, dynamic>;
                    final title =
                        '${v['plate'] ?? 'SIN PLACA'} • ${v['model'] ?? ''}'
                            .trim();
                    final subtitle = '#${v['id']}  ${v['color'] ?? ''}';
                    return ListTile(
                      title: Text(title),
                      subtitle: Text(subtitle),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () => _assign(v['id'] as int),
                    );
                  },
                ),
    );
  }
}
