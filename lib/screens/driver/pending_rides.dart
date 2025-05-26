import 'package:flutter/material.dart';

class PendingRidesScreen extends StatelessWidget {
  const PendingRidesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Viajes Pendientes')),
      body: const Center(child: Text('Aquí irían los viajes pendientes')),
    );
  }
}
