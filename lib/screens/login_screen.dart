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
  final _passwordFocusNode = FocusNode();
  bool isLoading = false;

  void login() async {
    final rawInput = emailOrPhoneController.text.trim();
    final password = passwordController.text.trim();

    if (rawInput.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa tu correo o teléfono y tu contraseña'),
        ),
      );
      return;
    }

    final isEmail = rawInput.contains('@');
    final normalizedEmail = isEmail ? rawInput.toLowerCase() : '';
    final normalizedPhone =
        isEmail ? '' : rawInput.replaceAll(RegExp(r'\D'), '');

    setState(() => isLoading = true);

    final result = await AuthService.login(
      email: normalizedEmail,
      phone: normalizedPhone,
      password: password,
    );

    if (!mounted) return;

    setState(() => isLoading = false);

    if (result.success) {
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rol no reconocido')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? 'No se pudo iniciar sesión'),
        ),
      );
    }
  }

  @override
  void dispose() {
    emailOrPhoneController.dispose();
    passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(30),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: AutofillGroup(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/images/logo_taxi.png',
                            height: 120,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 30),
                          const Text(
                            'Iniciar Sesión',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFF1B8F),
                            ),
                          ),
                          const SizedBox(height: 25),
                          TextField(
                            controller: emailOrPhoneController,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [
                              AutofillHints.username,
                              AutofillHints.email,
                              AutofillHints.telephoneNumber,
                            ],
                            onSubmitted: (_) =>
                                _passwordFocusNode.requestFocus(),
                            decoration: const InputDecoration(
                              labelText: 'Correo o número de teléfono',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: passwordController,
                            focusNode: _passwordFocusNode,
                            obscureText: true,
                            autofillHints: const [AutofillHints.password],
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => login(),
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
                                    backgroundColor: const Color(0xFFFF1B8F),
                                    foregroundColor: Colors.white,
                                    minimumSize:
                                        const Size(double.infinity, 50),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 8,
                                    shadowColor:
                                        const Color.fromRGBO(255, 191, 0, 0.3),
                                  ),
                                  child: const Text('Entrar'),
                                ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: () =>
                                Navigator.pushNamed(context, '/register'),
                            child: const Text(
                              '¿No tienes cuenta? Regístrate',
                              style: TextStyle(
                                fontSize: 15,
                                color: Color(0xFFFF1B8F),
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
