import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailOrPhoneController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;

  void login() async {
    setState(() => isLoading = true);

    final input = emailOrPhoneController.text.trim();
    final isEmail = input.contains('@');

    final success = await AuthService.login(
      email: isEmail ? input : '',
      phone: isEmail ? '' : input,
      password: passwordController.text.trim(),
    );

    if (!mounted) return;

    setState(() => isLoading = false);

    if (success) {
      final role = await AuthService.getUserRole();

      if (!mounted) return;

      debugPrint('✅ Usuario con rol: $role');

      if (role == 'passenger') {
        Navigator.pushReplacementNamed(context, '/passenger_home');
      } else if (role == 'driver') {
        Navigator.pushReplacementNamed(context, '/driver_home');
      } else if (role == 'admin') {
        Navigator.pushReplacementNamed(context, '/admin_home');
      } else {
        // Rol desconocido
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rol no reconocido')),
        );
      }
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Credenciales inválidas')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.local_taxi, size: 60, color: Colors.amber),
              const SizedBox(height: 30),
              const Text(
                'Iniciar Sesión',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF73003C),
                ),
              ),
              const SizedBox(height: 25),
              TextField(
                controller: emailOrPhoneController,
                decoration: const InputDecoration(
                  labelText: 'Correo o número de teléfono',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Contraseña',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 30),
              isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber[400],
                        foregroundColor: Colors.black,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 8,
                        shadowColor: const Color.fromRGBO(255, 191, 0, 0.3),
                      ),
                      child: const Text('Entrar'),
                    ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/register'),
                child: const Text(
                  '¿No tienes cuenta? Regístrate',
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF73003C),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
