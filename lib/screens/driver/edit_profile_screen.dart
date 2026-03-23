// lib/screens/edit_profile_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../services/auth_service.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> initial;
  const EditProfileScreen({super.key, required this.initial});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const String _api = 'https://158.23.170.129/flashride/public/api';
  static const _brand = Color(0xFFFF1B8F);

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtl;
  late final TextEditingController _emailCtl;
  late final TextEditingController _phoneCtl;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtl =
        TextEditingController(text: (widget.initial['name'] ?? '').toString());
    _emailCtl =
        TextEditingController(text: (widget.initial['email'] ?? '').toString());
    _phoneCtl =
        TextEditingController(text: (widget.initial['phone'] ?? '').toString());
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _emailCtl.dispose();
    _phoneCtl.dispose();
    super.dispose();
  }

  String? _vRequired(String? v) {
    if (v == null) return 'Campo requerido';
    if (v.trim().isEmpty) return 'Campo requerido';
    return null;
  }

  String? _vEmail(String? v) {
    final req = _vRequired(v);
    if (req != null) return req;

    final s = v!.trim();
    // validación simple (suficiente para UI)
    if (!s.contains('@') || !s.contains('.')) return 'Email inválido';
    return null;
  }

  Future<http.Response> _sendUpdate({
    required String token,
    required Map<String, dynamic> payload,
    required String method, // 'PUT' o 'PATCH'
  }) async {
    final uri = Uri.parse('$_api/profile');
    final headers = {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    if (method == 'PATCH') {
      return http.patch(uri, headers: headers, body: jsonEncode(payload));
    }
    return http.put(uri, headers: headers, body: jsonEncode(payload));
  }

  String _extractMessage(http.Response res) {
    try {
      final j = jsonDecode(res.body);
      if (j is Map && j['message'] != null) return j['message'].toString();

      // Laravel validator: { errors: { field: [..] } }
      if (j is Map && j['errors'] is Map) {
        final errors = (j['errors'] as Map).values;
        if (errors.isNotEmpty) {
          final first = errors.first;
          if (first is List && first.isNotEmpty) return first.first.toString();
          return errors.first.toString();
        }
      }
    } catch (_) {}
    return 'No se pudo guardar. (${res.statusCode})';
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final token = await AuthService.getToken();
      if (token == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sesión no válida.')),
        );
        Navigator.pop(context, false);
        return;
      }

      final payload = {
        'name': _nameCtl.text.trim(),
        'email': _emailCtl.text.trim(),
        'phone': _phoneCtl.text.trim(),
      };

      // 1) intenta PUT
      var res =
          await _sendUpdate(token: token, payload: payload, method: 'PUT');

      // si no existe esa ruta/método, prueba PATCH
      if (res.statusCode == 404 || res.statusCode == 405) {
        res =
            await _sendUpdate(token: token, payload: payload, method: 'PATCH');
      }

      if (!mounted) return;

      if (res.statusCode == 200) {
        Navigator.pop(context, true);
        return;
      }

      if (res.statusCode == 401) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tu sesión expiró.')),
        );
        Navigator.pop(context, false);
        return;
      }

      // 422 u otros: muestra mensaje
      final msg = _extractMessage(res);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error de red. Intenta de nuevo.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _dec(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: _brand),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar perfil'),
        backgroundColor: _brand,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _nameCtl,
                  decoration: _dec('Nombre completo', Icons.person),
                  validator: _vRequired,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailCtl,
                  decoration: _dec('Email', Icons.email),
                  validator: _vEmail,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneCtl,
                  decoration: _dec('Teléfono', Icons.phone),
                  validator: _vRequired,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brand,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Guardar cambios'),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed:
                      _saving ? null : () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
