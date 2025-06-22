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
                const Icon(Icons.local_taxi, size: 70, color: Colors.amber),
                const SizedBox(height: 20),
                const Text(
                  'FlashRide',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF73003C), // color vino institucional
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'La forma más rápida de moverte',
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
                          backgroundColor: Colors.amber[400],
                          foregroundColor: Colors.black,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 8,
                          shadowColor:
                              Colors.amber.withAlpha((255 * 0.3).toInt()),
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
                            color: Color(0xFF73003C),
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
