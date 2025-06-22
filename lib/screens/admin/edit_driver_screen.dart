import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'package:http/http.dart' as http;

class EditDriverScreen extends StatefulWidget {
  final int driverId;
  final String initialName;
  final String initialEmail;
  final String initialPhone;
  const EditDriverScreen({
    super.key,
    required this.driverId,
    required this.initialName,
    required this.initialEmail,
    required this.initialPhone,
  });

  @override
  State<EditDriverScreen> createState() => _EditDriverScreenState();
}

class _EditDriverScreenState extends State<EditDriverScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _emailCtrl = TextEditingController(text: widget.initialEmail);
    _phoneCtrl = TextEditingController(text: widget.initialPhone);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final token = await AuthService.getToken();
    final res = await http.put(
      Uri.parse('http://158.23.170.129/api/drivers/${widget.driverId}'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
      }),
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (res.statusCode == 200) {
      Navigator.pop(context, true);
    } else if (res.statusCode == 422) {
      final err = jsonDecode(res.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Error de validación: ${err['message'] ?? 'Campo inválido'}'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al actualizar el chofer')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Chofer'),
        backgroundColor: const Color(0xFF73003C),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Nombre requerido' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(labelText: 'Email'),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Email requerido';
                        final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                        return emailRegex.hasMatch(v) ? null : 'Email inválido';
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneCtrl,
                      decoration: const InputDecoration(labelText: 'Teléfono'),
                      keyboardType: TextInputType.phone,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Teléfono requerido';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF73003C),
                      ),
                      child: const Text('Guardar cambios'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
