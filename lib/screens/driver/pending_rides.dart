import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';
import 'package:logging/logging.dart';

final _log = Logger('PendingRidesScreen');

class PendingRidesScreen extends StatefulWidget {
  const PendingRidesScreen({super.key});

  @override
  State<PendingRidesScreen> createState() => _PendingRidesScreenState();
}

class _PendingRidesScreenState extends State<PendingRidesScreen> {
  // MISMA BASE QUE FUNCIONA EN curl:
  static const String _api = 'https://158.23.170.129/flashride/public/api';

  List<dynamic> _pendingRides = [];
  bool _isLoading = true;

  // ✅ Nuevo: estado de error/aviso visible en pantalla
  String? _screenMessage;
  String? _screenCode;
  int? _lastStatusCode;

  @override
  void initState() {
    super.initState();
    _loadPendingRides();
  }

  Map<String, dynamic>? _tryDecodeMap(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }

  String _humanMessageFromHttp(int statusCode, String body) {
    final j = _tryDecodeMap(body);
    final apiMsg = (j?['message'] ?? '').toString().trim();
    final code = (j?['code'] ?? '').toString().trim();

    if (apiMsg.isNotEmpty) return apiMsg;

    if (statusCode == 401) return 'Tu sesión expiró. Inicia sesión otra vez.';
    if (statusCode == 403) {
      // fallback por si no viene JSON
      if (code.isNotEmpty) return 'Acceso denegado ($code).';
      return 'Acceso denegado (403).';
    }
    if (statusCode == 404) return 'Ruta /rides/pending no encontrada (404).';
    if (statusCode >= 500) return 'Error del servidor. Intenta más tarde.';
    return 'Error $statusCode al cargar pendientes.';
  }

  Future<void> _loadPendingRides() async {
    setState(() {
      _isLoading = true;
      _screenMessage = null;
      _screenCode = null;
      _lastStatusCode = null;
    });

    try {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        setState(() {
          _pendingRides = [];
          _isLoading = false;
          _lastStatusCode = 401;
          _screenMessage = 'Tu sesión expiró. Inicia sesión otra vez.';
          _screenCode = 'NO_TOKEN';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tu sesión expiró.')),
          );
        }
        return;
      }

      final res = await http.get(
        Uri.parse('$_api/rides/pending'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      _log.info('RESPUESTA (${res.statusCode}): ${res.body}');

      _lastStatusCode = res.statusCode;

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);

        setState(() {
          if (decoded is List) {
            _pendingRides = decoded;
          } else if (decoded is Map && decoded['data'] is List) {
            _pendingRides = List.from(decoded['data']);
          } else {
            _pendingRides = [];
          }
          _isLoading = false;

          // ✅ si todo bien, limpia mensajes
          _screenMessage = null;
          _screenCode = null;
        });

        return;
      }

      // ✅ Si no es 200, intenta leer code/message del API
      final j = _tryDecodeMap(res.body);
      final code = (j?['code'] ?? '').toString().trim();
      final msg = _humanMessageFromHttp(res.statusCode, res.body);

      setState(() {
        _pendingRides = [];
        _isLoading = false;
        _screenMessage = msg;
        _screenCode = code.isEmpty ? null : code;
      });

      if (mounted) {
        // ✅ Mostrar el mensaje real del backend si viene
        // (ej: DRIVER_NO_VEHICLE)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } catch (e) {
      _log.severe('Excepción al cargar pendientes: $e');

      setState(() {
        _pendingRides = [];
        _isLoading = false;
        _lastStatusCode = null;
        _screenMessage = 'Error de red. Intenta de nuevo.';
        _screenCode = 'NETWORK_ERROR';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error de red. Intenta de nuevo.')),
        );
      }
    }
  }

  Future<void> _aceptarViaje(int id) async {
    try {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tu sesión expiró.')),
        );
        return;
      }

      final res = await http.post(
        Uri.parse('$_api/rides/$id/accept'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Viaje aceptado')),
        );
        _loadPendingRides();
        return;
      }

      // ✅ Mostrar mensaje real del backend si lo manda
      final j = _tryDecodeMap(res.body);
      final apiMsg = (j?['message'] ?? '').toString().trim();
      final msg = apiMsg.isNotEmpty
          ? apiMsg
          : '❌ Error al aceptar (#$id): ${res.statusCode}';

      _log.warning('Aceptar viaje $id → ${res.statusCode}: ${res.body}');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      _log.severe('Excepción al aceptar viaje $id: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error de red al aceptar viaje')),
      );
    }
  }

  Widget _buildEmptyOrError() {
    // ✅ Si el backend mandó un mensaje (403, 401, etc), muéstralo en pantalla
    if ((_screenMessage ?? '').trim().isNotEmpty) {
      final code = (_screenCode ?? '').trim();

      // Mensaje más “dirigido” si es el caso común
      final isNoVehicle = code == 'DRIVER_NO_VEHICLE';

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isNoVehicle ? Icons.directions_car_filled : Icons.info_outline,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                _screenMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              if (code.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Código: $code',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadPendingRides,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    // ✅ Caso normal: no hay pendientes
    return const Center(child: Text('No hay viajes por aceptar'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Viajes pendientes'),
        actions: [
          IconButton(
            tooltip: 'Refrescar',
            onPressed: _isLoading ? null : _loadPendingRides,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pendingRides.isEmpty
              ? _buildEmptyOrError()
              : ListView.builder(
                  itemCount: _pendingRides.length,
                  itemBuilder: (context, index) {
                    final ride = _pendingRides[index] as Map<String, dynamic>;
                    final id = ride['id'];

                    final origin = (ride['origin'] ??
                        '${ride['start_lat'] ?? '-'}, ${ride['start_lng'] ?? '-'}');
                    final dest = (ride['destination'] ??
                        '${ride['end_lat'] ?? '-'}, ${ride['end_lng'] ?? '-'}');

                    return Card(
                      child: ListTile(
                        title: Text('Viaje #$id'),
                        subtitle: Text('Origen: $origin\nDestino: $dest'),
                        trailing: ElevatedButton(
                          onPressed: () =>
                              _aceptarViaje(id is int ? id : int.parse('$id')),
                          child: const Text('Aceptar'),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
