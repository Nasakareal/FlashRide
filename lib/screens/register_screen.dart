import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  bool isLoading = false;

  void register() async {
    final pwd = passwordController.text.trim();
    final pwdConfirm = confirmPasswordController.text.trim();

    // 1) Validación local de coincidencia de contraseñas
    if (pwd != pwdConfirm) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Error'),
          content: const Text('Las contraseñas no coinciden.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    // 2) Llamada al servicio
    final result = await AuthService.register(
      name: nameController.text.trim(),
      email: emailController.text.trim(),
      phone: phoneController.text.trim(),
      password: pwd,
      passwordConfirmation: pwdConfirm,
    );
    setState(() => isLoading = false);

    debugPrint('🔥 Resultado de register(): $result');

    if (!mounted) return;

    if (result['ok'] == true) {
      // Éxito: navegamos
      Navigator.pushReplacementNamed(context, '/ride/request');
    } else {
      // Extraemos el primer mensaje de error
      final errors = result['errors'] as Map<String, List<String>>;
      final firstError = errors.values.expand((l) => l).first;

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Registro fallido'),
          content: Text(firstError),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Crear cuenta'),
        backgroundColor: const Color(0xFFFF1B8F),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nombre completo'),
            ),
            TextField(
              controller: emailController,
              decoration:
                  const InputDecoration(labelText: 'Correo electrónico'),
              keyboardType: TextInputType.emailAddress,
            ),
            TextField(
              controller: phoneController,
              decoration:
                  const InputDecoration(labelText: 'Número de teléfono'),
              keyboardType: TextInputType.phone,
            ),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Contraseña'),
            ),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              decoration:
                  const InputDecoration(labelText: 'Confirmar contraseña'),
            ),
            const SizedBox(height: 20),
            isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF1B8F),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text('Registrarse'),
                  ),
            const SizedBox(height: 20),
            const Text(
              'Al continuar, aceptas recibir llamadas, mensajes de WhatsApp o SMS/servicios de comunicación enriquecida (RCS) de FlashRide y sus afiliados al número proporcionado.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
