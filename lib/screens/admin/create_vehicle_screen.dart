import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'package:http/http.dart' as http;

class CreateVehicleScreen extends StatefulWidget {
  const CreateVehicleScreen({super.key});
  @override
  State<CreateVehicleScreen> createState() => _CreateVehicleScreenState();
}

class _CreateVehicleScreenState extends State<CreateVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  final plateCtrl = TextEditingController();
  final brandCtrl = TextEditingController();
  final modelCtrl = TextEditingController();
  final colorCtrl = TextEditingController();
  bool isLoading = false;

  @override
  void dispose() {
    plateCtrl.dispose();
    brandCtrl.dispose();
    modelCtrl.dispose();
    colorCtrl.dispose();
    super.dispose();
  }

  Future<void> _createVehicle() async {
    if (!_formKey.currentState!.validate()) return;

    final plate = plateCtrl.text.trim();
    final brand = brandCtrl.text.trim();
    final model = modelCtrl.text.trim();
    final color = colorCtrl.text.trim();

    setState(() => isLoading = true);
    try {
      final token = await AuthService.getToken();
      final uri = Uri.parse('${AuthService.baseUrl}/vehicles');
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
      final body = jsonEncode({
        'plate_number': plate,
        'brand': brand,
        'model': model,
        'color': color,
      });

      debugPrint('➡️ POST $uri');
      debugPrint('➡️ Headers: $headers');
      debugPrint('➡️ Body: $body');

      final res = await http.post(uri, headers: headers, body: body);

      debugPrint('⬅️ Status: ${res.statusCode}');
      debugPrint('⬅️ Body: ${res.body}');

      if (res.statusCode == 201) {
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (_) => const AlertDialog(
            title: Text('¡Éxito!'),
            content: Text('Vehículo registrado con éxito.'),
          ),
        );
        if (mounted) Navigator.pop(context);
        return;
      }

      String parsed = '';
      try {
        final js = jsonDecode(res.body);
        if (js is Map && js['errors'] is Map) {
          parsed = (js['errors'] as Map)
              .values
              .expand((e) => (e as List).map((x) => x.toString()))
              .join('\n');
        } else if (js is Map && js['message'] != null) {
          parsed = js['message'].toString();
        } else {
          parsed = js.toString();
        }
      } catch (_) {
        parsed = '';
      }

      final msg =
          'Status: ${res.statusCode}\n\nRAW:\n${res.body}\n\nPARSED:\n${parsed.isEmpty ? '(sin parseo JSON)' : parsed}';
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Fallo al guardar'),
          content: SingleChildScrollView(child: Text(msg)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Error de Conexión'),
          content: Text(e.toString()),
        ),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Requerido' : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
          title: const Text('Registrar Vehículo'),
          backgroundColor: const Color(0xFFFF1B8F),
          foregroundColor: Colors.white),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(children: [
              TextFormField(
                  controller: plateCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Placa', border: OutlineInputBorder()),
                  textInputAction: TextInputAction.next,
                  validator: _required),
              const SizedBox(height: 16),
              TextFormField(
                  controller: brandCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Marca', border: OutlineInputBorder()),
                  textInputAction: TextInputAction.next,
                  validator: _required),
              const SizedBox(height: 16),
              TextFormField(
                  controller: modelCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Modelo', border: OutlineInputBorder()),
                  textInputAction: TextInputAction.next,
                  validator: _required),
              const SizedBox(height: 16),
              TextFormField(
                  controller: colorCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Color', border: OutlineInputBorder()),
                  textInputAction: TextInputAction.done,
                  validator: _required),
              const SizedBox(height: 24),
              isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _createVehicle,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                          minimumSize: const Size(double.infinity, 50)),
                      child: const Text('Guardar Vehículo',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
            ]),
          ),
        ),
      ),
    );
  }
}
