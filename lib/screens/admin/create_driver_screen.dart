import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/auth_service.dart';

class CreateDriverScreen extends StatefulWidget {
  const CreateDriverScreen({super.key});

  @override
  State<CreateDriverScreen> createState() => _CreateDriverScreenState();
}

class _CreateDriverScreenState extends State<CreateDriverScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  bool isLoading = false;

  Future<void> _createDriver() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final phone = phoneController.text.trim();
    final pwd = passwordController.text.trim();
    final pwdConfirm = confirmPasswordController.text.trim();

    if (pwd != pwdConfirm) {
      await showDialog(
        context: context,
        builder: (_) => const AlertDialog(
          title: Text('Error'),
          content: Text('Las contraseñas no coinciden.'),
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final token = await AuthService.getToken();
      // Usa SIEMPRE la base del AuthService (HTTPS)
      // Ojo: tu AuthService tenía algo como:
      // static const _baseUrl = 'https://158.23.170.129/flashride/public/api';
      final uri = Uri.parse('${AuthService.baseUrl}/drivers');

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': name,
          'email': email,
          'phone': phone,
          'password': pwd,
        }),
      );

      // Logs útiles
      // debugPrint('Status: ${response.statusCode}');
      // debugPrint('Body: ${response.body}');

      if (response.statusCode == 201) {
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (_) => const AlertDialog(
            title: Text('¡Éxito!'),
            content: Text('El chofer se ha registrado correctamente.'),
          ),
        );
        if (mounted) Navigator.pop(context);
        return;
      }

      if (response.statusCode == 401) {
        // Token inválido/expirado
        await showDialog(
          context: context,
          builder: (_) => const AlertDialog(
            title: Text('Sesión expirada'),
            content: Text('Vuelve a iniciar sesión e inténtalo de nuevo.'),
          ),
        );
        return;
      }

      // Intenta mostrar errores del backend
      String message = 'Error desconocido';
      try {
        final body = jsonDecode(response.body);
        if (body is Map<String, dynamic>) {
          if (body['errors'] != null) {
            final errs = (body['errors'] as Map<String, dynamic>)
                .values
                .expand((e) => (e as List).map((x) => x.toString()))
                .join('\n');
            message = errs;
          } else if (body['message'] != null) {
            message = body['message'].toString();
          }
        } else {
          message = response.body.toString();
        }
      } catch (_) {
        // Si vino HTML (p.ej., por redirección), muestra texto plano
        message = response.body;
      }

      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Registro fallido'),
          content: Text(message),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Error de conexión'),
          content: Text('No se pudo conectar al servidor.\n$e'),
        ),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Registrar Chofer'),
        backgroundColor: const Color(0xFF73003C),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre completo',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'Número de teléfono',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Contraseña',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirmar contraseña',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _createDriver,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    child: const Text(
                      'Guardar Chofer',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
