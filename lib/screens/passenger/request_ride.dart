import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';

class RequestRideScreen extends StatefulWidget {
  const RequestRideScreen({super.key});
  @override
  State<RequestRideScreen> createState() => _RequestRideScreenState();
}

class _RequestRideScreenState extends State<RequestRideScreen> {
  final startLatController = TextEditingController(text: "19.7023");
  final startLngController = TextEditingController(text: "-101.1921");
  final endLatController = TextEditingController(text: "19.7050");
  final endLngController = TextEditingController(text: "-101.1875");

  bool isLoading = false;
  static final _BASE = AuthService.baseUrl;

  Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sin token (sesión expirada)');
    }
    return {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
  }

  Future<void> estimateCost() async {
    try {
      setState(() => isLoading = true);
      final r = await http.post(
        Uri.parse('$_BASE/rides/estimate'),
        headers: await _headers(),
        body: jsonEncode({
          'start_lat': double.tryParse(startLatController.text) ?? 0,
          'start_lng': double.tryParse(startLngController.text) ?? 0,
          'end_lat': double.tryParse(endLatController.text) ?? 0,
          'end_lng': double.tryParse(endLngController.text) ?? 0,
        }),
      );
      setState(() => isLoading = false);

      debugPrint("📡 Estimate status: ${r.statusCode}");
      debugPrint("📡 Estimate body: ${r.body}");

      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
            'Costo estimado: \$${data['estimated_cost']} (Distancia: ${data['distance_km']} km)',
          )),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al estimar: ${r.statusCode} ${r.body}')),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al estimar: $e')),
      );
    }
  }

  Future<void> requestRide() async {
    try {
      setState(() => isLoading = true);
      final r = await http.post(
        Uri.parse('$_BASE/rides'),
        headers: await _headers(),
        body: jsonEncode({
          'start_lat': double.tryParse(startLatController.text) ?? 0,
          'start_lng': double.tryParse(startLngController.text) ?? 0,
          'end_lat': double.tryParse(endLatController.text) ?? 0,
          'end_lng': double.tryParse(endLngController.text) ?? 0,
        }),
      );
      setState(() => isLoading = false);

      debugPrint("📡 RequestRide status: ${r.statusCode}");
      debugPrint("📡 RequestRide body: ${r.body}");

      if (r.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Viaje solicitado con éxito ✅')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Error al solicitar viaje: ${r.statusCode} ${r.body}')),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al solicitar viaje: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Solicitar viaje')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
                controller: startLatController,
                decoration:
                    const InputDecoration(labelText: 'Latitud de origen'),
                keyboardType: TextInputType.number),
            TextField(
                controller: startLngController,
                decoration:
                    const InputDecoration(labelText: 'Longitud de origen'),
                keyboardType: TextInputType.number),
            TextField(
                controller: endLatController,
                decoration: const InputDecoration(labelText: 'Latitud destino'),
                keyboardType: TextInputType.number),
            TextField(
                controller: endLngController,
                decoration:
                    const InputDecoration(labelText: 'Longitud destino'),
                keyboardType: TextInputType.number),
            const SizedBox(height: 20),
            if (isLoading)
              const CircularProgressIndicator()
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                      onPressed: estimateCost,
                      child: const Text('Estimar costo')),
                  ElevatedButton(
                      onPressed: requestRide,
                      child: const Text('Solicitar viaje')),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
