// lib/screens/admin/biometric_driver_screen.dart

import 'package:flutter/material.dart';

class BiometricDriverScreen extends StatelessWidget {
  final int driverId;
  final String driverName;

  const BiometricDriverScreen({
    super.key,
    required this.driverId,
    required this.driverName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Biométricos: $driverName'),
        backgroundColor: const Color(0xFF73003C),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Text(
          'Aquí vendrá la lógica de registro/visualización biométricos\n(ID: $driverId)',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
