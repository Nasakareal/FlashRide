import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'create_driver_screen.dart';
import 'biometric_driver_screen.dart';
import 'edit_driver_screen.dart';
import 'show_driver_screen.dart';
import 'package:http/http.dart' as http;

class DriverListScreen extends StatefulWidget {
  const DriverListScreen({super.key});
  @override
  State<DriverListScreen> createState() => _DriverListScreenState();
}

class _DriverListScreenState extends State<DriverListScreen> {
  // MISMA base que ya te funcionó con curl:
  static const String _api = 'https://158.23.170.129/flashride/public/api';

  // Por si tu backend expone la lista en otra ruta,
  // probamos estas opciones en orden:
  static const List<String> _candidatePaths = <String>[
    '/drivers',
    '/admin/drivers',
    '/drivers/list',
    '/users?role=driver',
  ];

  List<Map<String, dynamic>> _drivers = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchDrivers();
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _drivers.where((d) {
        final name = (d['name'] ?? '').toString().toLowerCase();
        final email = (d['email'] ?? '').toString().toLowerCase();
        return name.contains(q) || email.contains(q);
      }).toList();
    });
  }

  Future<void> _fetchDrivers() async {
    setState(() => _isLoading = true);

    try {
      final token = await AuthService.getToken();

      // headers comunes
      final headers = <String, String>{
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      Map<String, dynamic>?
          firstError; // para mostrar el primer error encontrado
      for (final path in _candidatePaths) {
        final uri = Uri.parse('$_api$path');
        final res = await http.get(uri, headers: headers);

        if (res.statusCode == 200) {
          final decoded = jsonDecode(res.body);

          List list;
          if (decoded is List) {
            list = decoded;
          } else if (decoded is Map && decoded['data'] is List) {
            list = decoded['data'];
          } else if (decoded is Map && decoded['drivers'] is List) {
            list = decoded['drivers'];
          } else {
            list = const [];
          }

          final drivers = list
              .map<Map<String, dynamic>>(
                  (e) => Map<String, dynamic>.from(e as Map))
              .toList();

          if (!mounted) return;
          setState(() {
            _drivers = drivers;
            _filtered = List.from(drivers);
            _isLoading = false;
          });

          // Si encontramos una ruta válida, dejamos de probar.
          if (drivers.isEmpty) {
            // Lista vacía: puede ser válido. Igual paramos porque la ruta existe.
          }
          return;
        } else if (res.statusCode == 401) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sesión expirada')),
          );
          Navigator.pop(context);
          return;
        } else if (res.statusCode == 403) {
          // Probablemente no eres admin para esta ruta.
          firstError ??= {'code': 403, 'path': path, 'body': res.body};
          // Seguimos probando otras rutas (por si hay una pública/alternativa).
          continue;
        } else {
          // 404/500 u otros
          firstError ??= {
            'code': res.statusCode,
            'path': path,
            'body': res.body
          };
          // probamos siguiente candidata
          continue;
        }
      }

      // Si ninguna ruta funcionó:
      if (!mounted) return;
      setState(() {
        _drivers = [];
        _filtered = [];
        _isLoading = false;
      });

      final msg = (firstError == null)
          ? 'No se pudo cargar la lista de choferes.'
          : 'Error ${firstError['code']} en ${firstError['path']}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _drivers = [];
        _filtered = [];
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error de red. Intenta de nuevo.')),
      );
    }
  }

  Future<void> _refresh() async {
    await _fetchDrivers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choferes Registrados'),
        backgroundColor: const Color(0xFF73003C),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateDriverScreen()),
              ).then((_) => _fetchDrivers());
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Buscar por nombre o correo',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filtered.isEmpty
                        ? const Center(child: Text('No hay choferes.'))
                        : ListView.separated(
                            separatorBuilder: (_, __) => const Divider(),
                            itemCount: _filtered.length,
                            itemBuilder: (_, i) {
                              final d = _filtered[i];
                              return ListTile(
                                title: Text((d['name'] ?? '').toString()),
                                subtitle: Text((d['email'] ?? '').toString()),
                                trailing: Wrap(
                                  spacing: 12,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.visibility,
                                          size: 20),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => ShowDriverScreen(
                                              driverId: d['id'],
                                              driverName: d['name'] ?? '',
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 20),
                                      onPressed: () async {
                                        final actualizado =
                                            await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => EditDriverScreen(
                                              driverId: d['id'],
                                              initialName: d['name'] ?? '',
                                              initialEmail: d['email'] ?? '',
                                              initialPhone:
                                                  d['phone']?.toString() ?? '',
                                            ),
                                          ),
                                        );
                                        if (actualizado == true)
                                          _fetchDrivers();
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.fingerprint,
                                          size: 20),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                BiometricDriverScreen(
                                              driverId: d['id'],
                                              driverName: d['name'] ?? '',
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
