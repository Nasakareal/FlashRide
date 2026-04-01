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

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void register() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim().toLowerCase();
    final phone = phoneController.text.replaceAll(RegExp(r'\D'), '');
    final pwd = passwordController.text.trim();
    final pwdConfirm = confirmPasswordController.text.trim();

    if (name.isEmpty ||
        email.isEmpty ||
        phone.isEmpty ||
        pwd.isEmpty ||
        pwdConfirm.isEmpty) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Error'),
          content: const Text('Todos los campos son obligatorios.'),
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

    final result = await AuthService.register(
      name: name,
      email: email,
      phone: phone,
      password: pwd,
      passwordConfirmation: pwdConfirm,
    );

    if (mounted) {
      setState(() => isLoading = false);
    }

    debugPrint('🔥 Resultado de register(): $result');

    if (!mounted) return;

    if (result['ok'] == true) {
      Navigator.pushReplacementNamed(context, '/ride/request');
    } else {
      final rawErrors = result['errors'];
      String firstError = 'Ocurrió un error al registrarse.';

      if (rawErrors is Map) {
        for (final value in rawErrors.values) {
          if (value is List && value.isNotEmpty) {
            firstError = value.first.toString();
            break;
          }
        }
      }

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
              textInputAction: TextInputAction.next,
            ),
            TextField(
              controller: emailController,
              decoration:
                  const InputDecoration(labelText: 'Correo electrónico'),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
            ),
            TextField(
              controller: phoneController,
              decoration:
                  const InputDecoration(labelText: 'Número de teléfono'),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
            ),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Contraseña'),
              textInputAction: TextInputAction.next,
            ),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              decoration:
                  const InputDecoration(labelText: 'Confirmar contraseña'),
              onSubmitted: (_) => register(),
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
