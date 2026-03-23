import 'package:flutter/material.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Logo superior
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Image.asset(
                'assets/images/michoacan.png',
                height: 50,
                fit: BoxFit.contain,
              ),
            ),

            // Contenido principal
            Column(
              children: [
                const SizedBox(height: 10),
                Image.asset(
                  'assets/images/logo_taxi.png',
                  height: 120, // equivalente a size: 70
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Taxi Seguro',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF1B8F),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'La forma más rápida y segura de moverte',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 40),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Column(
                    children: [
                      ElevatedButton(
                        onPressed: () => Navigator.pushNamed(context, '/login'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF1B8F),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 8,
                          // CAMBIO: sombra basada en el mismo rosa
                          shadowColor: const Color(0xFFFF1B8F).withOpacity(0.3),
                        ),
                        child: const Text('Iniciar sesión'),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () =>
                            Navigator.pushNamed(context, '/register'),
                        child: const Text(
                          'Crear cuenta',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFFFF1B8F),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Logo inferior
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Image.asset(
                'assets/images/transporte.jpg',
                height: 55,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
