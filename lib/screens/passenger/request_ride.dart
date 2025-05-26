import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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

  void requestRide() async {
    setState(() => isLoading = true);

    final token = await AuthService.getToken();

    final response = await http.post(
      Uri.parse('http://localhost/FlashRide/public/api/rides'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'start_lat': double.parse(startLatController.text),
        'start_lng': double.parse(startLngController.text),
        'end_lat': double.parse(endLatController.text),
        'end_lng': double.parse(endLngController.text),
      }),
    );

    if (!mounted) return;

    setState(() => isLoading = false);

    if (!mounted) return;

    if (response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Viaje solicitado con éxito')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al solicitar viaje')),
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
              decoration: const InputDecoration(labelText: 'Latitud de origen'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: startLngController,
              decoration: const InputDecoration(labelText: 'Longitud de origen'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: endLatController,
              decoration: const InputDecoration(labelText: 'Latitud destino'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: endLngController,
              decoration: const InputDecoration(labelText: 'Longitud destino'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: requestRide,
                    child: const Text('Solicitar viaje'),
                  ),
          ],
        ),
      ),
    );
  }
}
