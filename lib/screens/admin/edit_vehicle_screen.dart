// lib/screens/admin/edit_vehicle_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';

class EditVehicleScreen extends StatefulWidget {
  final Map<String, dynamic> vehicle;
  const EditVehicleScreen({super.key, required this.vehicle});

  @override
  State<EditVehicleScreen> createState() => _EditVehicleScreenState();
}

class _EditVehicleScreenState extends State<EditVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _plateCtrl;
  late final TextEditingController _modelCtrl;
  late final TextEditingController _colorCtrl;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _plateCtrl =
        TextEditingController(text: widget.vehicle['plate']?.toString() ?? '');
    _modelCtrl =
        TextEditingController(text: widget.vehicle['model']?.toString() ?? '');
    _colorCtrl =
        TextEditingController(text: widget.vehicle['color']?.toString() ?? '');
  }

  @override
  void dispose() {
    _plateCtrl.dispose();
    _modelCtrl.dispose();
    _colorCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final token = await AuthService.getToken();
      final id = widget.vehicle['id'] ?? widget.vehicle['vehicle_id'];

      if (id == null) {
        throw Exception('El objeto vehículo no trae id/vehicle_id.');
      }

      final res = await http.put(
        Uri.parse('${AuthService.baseUrl}/vehicles/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'plate': _plateCtrl.text.trim(),
          'model': _modelCtrl.text.trim(),
          'color':
              _colorCtrl.text.trim().isEmpty ? null : _colorCtrl.text.trim(),
        }),
      );

      if (res.statusCode == 401 || res.statusCode == 403) {
        throw Exception('No autorizado (token inválido o sin permisos).');
      }

      if (res.statusCode != 200 && res.statusCode != 204) {
        throw Exception('Error ${res.statusCode}: ${res.body}');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vehículo actualizado.')),
      );
      Navigator.pop(
          context, true); // regresa y dispara el refresh del then(...)
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar vehículo'),
        backgroundColor: const Color(0xFF73003C),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child:
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
              TextFormField(
                controller: _plateCtrl,
                decoration: const InputDecoration(
                  labelText: 'Placa',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'La placa es obligatoria'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _modelCtrl,
                decoration: const InputDecoration(
                  labelText: 'Modelo',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'El modelo es obligatorio'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _colorCtrl,
                decoration: const InputDecoration(
                  labelText: 'Color',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_saving ? 'Guardando...' : 'Guardar cambios'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF1B8F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
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
