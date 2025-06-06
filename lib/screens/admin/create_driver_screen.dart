// lib/screens/admin/create_driver_screen.dart

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

    // 1) Validación local: contraseñas coinciden
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

    try {
      // 2) Obtengo token guardado
      final token = await AuthService.getToken();
      debugPrint('🔑 Token obtenido: $token');

      // 3) Llamo al endpoint POST /api/drivers
      final response = await http.post(
        Uri.parse('http://158.23.170.129/api/drivers'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json', // <<— Muy importante
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': name,
          'email': email,
          'phone': phone,
          'password': pwd,
        }),
      );

      // 4) Imprimo status y body, antes de decodificar
      debugPrint('🟢 Status Code: ${response.statusCode}');
      debugPrint('🟢 Response Body: ${response.body}');

      // 5) Si fue 201, éxito
      if (response.statusCode == 201) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('¡Éxito!'),
            content: const Text('El chofer se ha registrado correctamente.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // cerrar diálogo
                  Navigator.pop(context); // volver a AdminHome
                },
                child: const Text('Aceptar'),
              ),
            ],
          ),
        );
      } else {
        // 6) Si no es 201, trato de decodificar JSON para extraer errores
        String message = 'Error desconocido';

        try {
          final body = jsonDecode(response.body);
          if (body is Map<String, dynamic>) {
            if (body['errors'] != null) {
              final errs = (body['errors'] as Map<String, dynamic>)
                  .values
                  .expand((list) => list as List<dynamic>)
                  .map((e) => e.toString())
                  .join('\n');
              message = errs;
            } else if (body['message'] != null) {
              message = body['message'];
            }
          }
        } catch (_) {
          // Si no es JSON, muestro la respuesta bruta
          message = response.body;
        }

        if (!mounted) return;
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Registro fallido'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // 7) Error de conexión o parsing
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Error de conexión'),
          content: Text('No se pudo conectar al servidor.\n$e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
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
                      shadowColor: const Color.fromRGBO(0, 0, 0, 0.2),
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
