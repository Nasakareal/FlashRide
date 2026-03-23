import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';

const _brand = Color(0xFFFF1B8F);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameCtl = TextEditingController();
  final _emailCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  static final _BASE = AuthService.baseUrl;

  Future<Map<String, String>> _headers() async {
    final p = await SharedPreferences.getInstance();
    final token = p.getString('token') ?? '';
    return {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await http.get(Uri.parse('$_BASE/profile'),
          headers: await _headers());
      if (r.statusCode == 200) {
        final j = jsonDecode(r.body);
        _nameCtl.text = (j['name'] ?? '').toString();
        _emailCtl.text = (j['email'] ?? '').toString();
        _phoneCtl.text = (j['phone'] ?? '').toString();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final r = await http.put(
        Uri.parse('$_BASE/profile'),
        headers: await _headers(),
        body: jsonEncode({
          'name': _nameCtl.text.trim(),
          'email': _emailCtl.text.trim(),
          'phone': _phoneCtl.text.trim(),
        }),
      );
      if (!mounted) return;
      if (r.statusCode == 200) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Perfil actualizado')));
        final p = await SharedPreferences.getInstance();
        await p.setString('name', _nameCtl.text.trim());
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error ${r.statusCode}: ${r.body}')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePassword() async {
    final currentCtl = TextEditingController();
    final newCtl = TextEditingController();
    final confirmCtl = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (c) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + MediaQuery.of(c).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Cambiar contraseña',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              TextField(
                  controller: currentCtl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Actual')),
              const SizedBox(height: 8),
              TextField(
                  controller: newCtl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Nueva')),
              const SizedBox(height: 8),
              TextField(
                  controller: confirmCtl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Confirmar')),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _brand),
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text('Guardar',
                      style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (ok != true) return;
    if (newCtl.text != confirmCtl.text) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Las contraseñas no coinciden')));
      return;
    }
    final r = await http.post(
      Uri.parse('$_BASE/password/change'),
      headers: await _headers(),
      body: jsonEncode({
        'current_password': currentCtl.text,
        'password': newCtl.text,
        'password_confirmation': confirmCtl.text,
      }),
    );
    if (!mounted) return;
    if (r.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contraseña actualizada')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error ${r.statusCode}: ${r.body}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: _brand, title: const Text('Mi perfil')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  TextField(
                      controller: _nameCtl,
                      decoration: const InputDecoration(labelText: 'Nombre')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: _emailCtl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Correo')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: _phoneCtl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Teléfono')),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _brand,
                          padding: const EdgeInsets.symmetric(vertical: 14)),
                      onPressed: _saving ? null : _save,
                      child: Text(_saving ? 'Guardando…' : 'Guardar',
                          style: const TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _changePassword,
                    icon: const Icon(Icons.lock),
                    label: const Text('Cambiar contraseña'),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _emailCtl.dispose();
    _phoneCtl.dispose();
    super.dispose();
  }
}
