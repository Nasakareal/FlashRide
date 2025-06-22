import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';

class PendingRidesScreen extends StatefulWidget {
  const PendingRidesScreen({super.key});

  @override
  State<PendingRidesScreen> createState() => _PendingRidesScreenState();
}

class _PendingRidesScreenState extends State<PendingRidesScreen> {
  List<dynamic> _pendingRides = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPendingRides();
  }

  Future<void> _loadPendingRides() async {
    final token = await AuthService.getToken();
    final response = await http.get(
      Uri.parse('http://158.23.170.129/api/rides/pending'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    print('RESPUESTA (${response.statusCode}): ${response.body}');

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      setState(() {
        _pendingRides = body['data'];
        _isLoading = false;
      });
    } else {
      setState(() {
        _pendingRides = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _aceptarViaje(int id) async {
    final token = await AuthService.getToken();
    final response = await http.post(
      Uri.parse('http://158.23.170.129/api/rides/$id/accept'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Viaje aceptado')),
      );
      _loadPendingRides();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Error al aceptar el viaje')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Viajes pendientes')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pendingRides.isEmpty
              ? const Center(child: Text('No hay viajes por aceptar'))
              : ListView.builder(
                  itemCount: _pendingRides.length,
                  itemBuilder: (context, index) {
                    final ride = _pendingRides[index];
                    return Card(
                      child: ListTile(
                        title: Text('Viaje #${ride['id']}'),
                        subtitle: Text(
                            'Origen: ${ride['start_lat']} / Destino: ${ride['end_lat']}'),
                        trailing: ElevatedButton(
                          onPressed: () => _aceptarViaje(ride['id']),
                          child: const Text('Aceptar'),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
