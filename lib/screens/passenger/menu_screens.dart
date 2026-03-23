import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'support_screen.dart';
import 'settings_screen.dart';

const _brand = Color(0xFFFF1B8F);

Future<Map<String, String>> _authHeaders() async {
  final p = await SharedPreferences.getInstance();
  final token = p.getString('token') ?? '';
  return {
    'Authorization': 'Bearer $token',
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };
}

String get _BASE => AuthService.baseUrl;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = true;
  Map<String, dynamic>? _data;

  final _nameCtl = TextEditingController();
  final _emailCtl = TextEditingController();
  final _phoneCtl = TextEditingController();

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _emailCtl.dispose();
    _phoneCtl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await http.get(
        Uri.parse('$_BASE/profile'),
        headers: await _authHeaders(),
      );

      if (r.statusCode == 200) {
        _data = jsonDecode(r.body) as Map<String, dynamic>;
        _nameCtl.text = '${_data?['name'] ?? ''}';
        _emailCtl.text = '${_data?['email'] ?? ''}';
        _phoneCtl.text = '${_data?['phone'] ?? ''}';
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    final body = jsonEncode({
      'name': _nameCtl.text.trim(),
      'email': _emailCtl.text.trim(),
      'phone': _phoneCtl.text.trim(),
    });

    try {
      final r = await http.put(
        Uri.parse('$_BASE/profile'),
        headers: await _authHeaders(),
        body: body,
      );

      if (!mounted) return;

      if (r.statusCode == 200) {
        _snack('Perfil actualizado');
        await _load();
      } else {
        _snack('Error: ${r.statusCode} ${r.body}');
      }
    } catch (e) {
      if (!mounted) return;
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePassword() async {
    final currentCtl = TextEditingController();
    final newCtl = TextEditingController();
    final confirmCtl = TextEditingController();

    bool sending = false;

    String firstErrorFrom422(dynamic decoded) {
      if (decoded is Map<String, dynamic>) {
        final errors = decoded["errors"];
        if (errors is Map) {
          for (final entry in errors.entries) {
            final v = entry.value;
            if (v is List && v.isNotEmpty) return v.first.toString();
          }
        }
        return decoded["message"]?.toString() ?? "Validación fallida";
      }
      return "Validación fallida";
    }

    Map<String, dynamic>? result;

    try {
      result = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (ctx, setSheetState) {
              bool sheetAlive = true;

              Future<void> submit() async {
                if (sending) return;
                if (!sheetAlive) return;

                final cur = currentCtl.text.trim();
                final n1 = newCtl.text.trim();
                final n2 = confirmCtl.text.trim();

                if (cur.isEmpty || n1.isEmpty || n2.isEmpty) {
                  _snack("Completa todos los campos");
                  return;
                }
                if (n1.length < 6) {
                  _snack("La nueva contraseña debe tener mínimo 6 caracteres");
                  return;
                }
                if (n1 != n2) {
                  _snack("Las contraseñas no coinciden");
                  return;
                }

                // activar loader en el sheet
                if (!sheetAlive) return;
                setSheetState(() => sending = true);

                try {
                  final r = await http.post(
                    Uri.parse('$_BASE/change-password'),
                    headers: await _authHeaders(),
                    body: jsonEncode({
                      'current_password': cur,
                      'new_password': n1,
                      'new_password_confirmation': n2,
                    }),
                  );

                  if (!mounted) return;
                  if (!sheetAlive) return;

                  dynamic decoded;
                  try {
                    decoded = jsonDecode(r.body);
                  } catch (_) {
                    decoded = null;
                  }

                  if (r.statusCode == 200) {
                    final msg = (decoded is Map && decoded["message"] != null)
                        ? decoded["message"].toString()
                        : "Contraseña actualizada ✅";

                    sheetAlive = false;
                    Navigator.pop(ctx, {"ok": true, "message": msg});
                    return;
                  }

                  if (r.statusCode == 403) {
                    final msg = (decoded is Map && decoded["message"] != null)
                        ? decoded["message"].toString()
                        : "La contraseña actual no coincide";
                    _snack(msg);
                    return;
                  }

                  if (r.statusCode == 422) {
                    _snack(firstErrorFrom422(decoded));
                    return;
                  }

                  final msg = (decoded is Map && decoded["message"] != null)
                      ? decoded["message"].toString()
                      : "Error al cambiar contraseña (${r.statusCode})";
                  _snack(msg);
                } catch (_) {
                  if (!mounted) return;
                  if (!sheetAlive) return;
                  _snack(
                      "No se pudo cambiar la contraseña. Revisa tu conexión.");
                } finally {
                  if (!sheetAlive) return;
                  try {
                    setSheetState(() => sending = false);
                  } catch (_) {}
                }
              }

              return WillPopScope(
                onWillPop: () async {
                  sheetAlive = false;
                  return true;
                },
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Cambiar contraseña',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: currentCtl,
                        obscureText: true,
                        enabled: !sending,
                        decoration: const InputDecoration(
                          labelText: 'Contraseña actual',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: newCtl,
                        obscureText: true,
                        enabled: !sending,
                        decoration: const InputDecoration(
                          labelText: 'Nueva contraseña',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: confirmCtl,
                        obscureText: true,
                        enabled: !sending,
                        decoration: const InputDecoration(
                          labelText: 'Confirmar nueva contraseña',
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style:
                              ElevatedButton.styleFrom(backgroundColor: _brand),
                          onPressed: sending ? null : submit,
                          child: sending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text(
                                  'Guardar',
                                  style: TextStyle(color: Colors.white),
                                ),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      currentCtl.dispose();
      newCtl.dispose();
      confirmCtl.dispose();
    }

    if (!mounted) return;
    if (result != null && result['ok'] == true) {
      _snack((result['message'] ?? 'Contraseña actualizada ✅').toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: _brand, title: const Text('Mi perfil')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Datos de la cuenta',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameCtl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailCtl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneCtl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brand,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      _saving ? 'Guardando…' : 'Guardar cambios',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'Más opciones',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.credit_card),
                  title: const Text('Métodos de pago'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PaymentMethodsScreen(),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.lock),
                  title: const Text('Cambiar contraseña'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _changePassword,
                ),
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('Viajes pasados'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PastRidesScreen(),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: const Text('Soporte'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SupportScreen()),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('Ajustes'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                ),
              ],
            ),
    );
  }
}

class PaymentMethodsScreen extends StatelessWidget {
  const PaymentMethodsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _brand,
        title: const Text('Métodos de pago'),
      ),
      body: const Center(child: Text('Tarjetas / efectivo (pendiente)')),
    );
  }
}

class PastRidesScreen extends StatelessWidget {
  const PastRidesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _brand,
        title: const Text('Viajes pasados'),
      ),
      body: const Center(child: Text('Historial de viajes (pendiente)')),
    );
  }
}
