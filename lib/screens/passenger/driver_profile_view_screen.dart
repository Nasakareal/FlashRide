import 'package:flutter/material.dart';

class DriverProfileViewScreen extends StatelessWidget {
  const DriverProfileViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    final driver = args?['driver'] ?? {};

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil del conductor')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              driver['name'] ?? 'Conductor',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Rating: ${driver['rating'] ?? 'N/A'}'),
            Text('Placas: ${driver['plate'] ?? 'N/A'}'),
          ],
        ),
      ),
    );
  }
}
