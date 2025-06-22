import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'package:http/http.dart' as http;

class ShowDriverScreen extends StatefulWidget {
  final int driverId;
  final String driverName;
  const ShowDriverScreen({
    super.key,
    required this.driverId,
    required this.driverName,
  });

  @override
  State<ShowDriverScreen> createState() => _ShowDriverScreenState();
}

class _ShowDriverScreenState extends State<ShowDriverScreen> {
  bool _isLoading = true;
  int _totalTrips = 0;
  double _rating = 0.0;
  bool _everPressedPanic = false;

  @override
  void initState() {
    super.initState();
    _fetchDriverDetails();
  }

  Future<void> _fetchDriverDetails() async {
    final token = await AuthService.getToken();
    final res = await http.get(
      Uri.parse('http://158.23.170.129/api/drivers/${widget.driverId}/details'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      setState(() {
        _totalTrips = data['total_trips'] ?? 0;
        _rating = (data['rating'] ?? 0).toDouble();
        _everPressedPanic = data['ever_pressed_panic'] ?? false;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al cargar detalles')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detalles de ${widget.driverName}'),
        backgroundColor: const Color(0xFF73003C),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total de viajes: $_totalTrips',
                      style: const TextStyle(fontSize: 18)),
                  const SizedBox(height: 8),
                  Text('Calificación: $_rating',
                      style: const TextStyle(fontSize: 18)),
                  const SizedBox(height: 8),
                  Text(
                    'Ha presionado pánico: ${_everPressedPanic ? "Sí" : "No"}',
                    style: const TextStyle(fontSize: 18),
                  ),
                ],
              ),
            ),
    );
  }
}
