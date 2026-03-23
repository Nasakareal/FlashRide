import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ride_completed_screen.dart';

class PassengerRideInProgressScreen extends StatefulWidget {
  final Map<String, dynamic> ride;
  const PassengerRideInProgressScreen({super.key, required this.ride});

  @override
  State<PassengerRideInProgressScreen> createState() =>
      _PassengerRideInProgressScreenState();
}

class _PassengerRideInProgressScreenState
    extends State<PassengerRideInProgressScreen> {
  final MapController _mapController = MapController();

  LatLng? _myPos;
  LatLng? _driverPos;

  final List<Marker> _markers = <Marker>[];
  final List<Polyline> _polylines = <Polyline>[];

  Timer? _posTimer;
  Timer? _statusTimer;

  bool _navigating = false;
  bool _canceling = false;

  static const _apiBase = "https://158.23.170.129/flashride/public/api";
  static const _brand = Color(0xFFFF1B8F);

  LatLng? _lastRouteFrom;
  LatLng? _lastRouteTo;
  DateTime _lastRouteAt = DateTime.fromMillisecondsSinceEpoch(0);

  Future<Map<String, String>> _authHeaders() async {
    final sp = await SharedPreferences.getInstance();
    final token = sp.getString('token') ?? '';
    return {
      "Authorization": "Bearer $token",
      "Accept": "application/json",
      "Content-Type": "application/json",
    };
  }

  Map<String, dynamic>? _asJsonMap(dynamic v) {
    if (v is Map) return v.cast<String, dynamic>();
    return null;
  }

  double? _asDouble(dynamic v) =>
      (v is num) ? v.toDouble() : double.tryParse('$v');

  int? _asInt(dynamic v) => (v is int) ? v : int.tryParse('$v');

  String _norm(dynamic v) => (v ?? '').toString().toLowerCase().trim();

  @override
  void initState() {
    super.initState();

    _refreshPositions();

    _posTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _refreshPositions();
    });

    _statusTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _checkRideStatus();
    });
  }

  @override
  void dispose() {
    _posTimer?.cancel();
    _statusTimer?.cancel();
    super.dispose();
  }

  void _stopWatchers() {
    _posTimer?.cancel();
    _statusTimer?.cancel();
  }

  void _goToPassengerHome() {
    if (!mounted || _navigating) return;
    _navigating = true;
    _stopWatchers();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/passenger_home',
        (_) => false,
      );
    });
  }

  void _goToCompleted(Map<String, dynamic>? data) {
    if (!mounted || _navigating) return;
    _navigating = true;
    _stopWatchers();

    final payload = data ?? widget.ride;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => RideCompletedScreen(ride: payload)),
      );
    });
  }

  Future<void> _confirmCancel() async {
    if (_canceling || _navigating) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancelar viaje'),
        content: const Text('¿Seguro que quieres cancelar este viaje?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await _cancelRide();
    }
  }

  Future<void> _cancelRide() async {
    final id = _asInt(widget.ride['id']);
    if (id == null) return;

    setState(() => _canceling = true);

    try {
      final headers = await _authHeaders();

      var res = await http.post(
        Uri.parse("$_apiBase/rides/$id/cancel"),
        headers: headers,
      );

      if (res.statusCode == 404 || res.statusCode == 405) {
        res = await http.delete(
          Uri.parse("$_apiBase/rides/$id"),
          headers: headers,
        );
      }

      if (res.statusCode == 200 ||
          res.statusCode == 204 ||
          res.statusCode == 202) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Viaje cancelado.')),
        );
        _goToPassengerHome();
        return;
      }

      if (res.statusCode == 404) {
        _goToPassengerHome();
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cancelar: ${res.statusCode}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cancelando: $e')),
      );
    } finally {
      if (mounted) setState(() => _canceling = false);
    }
  }

  Future<void> _checkRideStatus() async {
    if (_navigating || _canceling) return;

    final id = _asInt(widget.ride['id']);
    if (id == null) return;

    try {
      final r = await http.get(
        Uri.parse("$_apiBase/rides/$id"),
        headers: await _authHeaders(),
      );

      if (r.statusCode == 404) {
        _goToPassengerHome();
        return;
      }

      if (r.statusCode == 200) {
        final data = _asJsonMap(jsonDecode(r.body));
        if (data != null) {
          final status = _norm(data['status']);
          final fase = _norm(data['fase']);

          if (status == 'completed' || fase == 'completado') {
            _goToCompleted(data);
            return;
          }

          if (status == 'cancelled' ||
              status == 'canceled' ||
              fase == 'cancelado' ||
              fase == 'cancelled') {
            _goToPassengerHome();
            return;
          }
        }
      }

      final a = await http.get(
        Uri.parse("$_apiBase/rides/active"),
        headers: await _authHeaders(),
      );

      if (a.statusCode != 200) return;

      final act = _asJsonMap(jsonDecode(a.body));
      final activeId = _asInt(act?['id']);

      if (activeId == null || activeId != id) {
        _goToPassengerHome();
        return;
      }

      final s2 = _norm(act?['status']);
      final f2 = _norm(act?['fase']);

      if (s2 == 'completed' || f2 == 'completado') {
        _goToCompleted(act);
        return;
      }

      if (s2 == 'cancelled' ||
          s2 == 'canceled' ||
          f2 == 'cancelado' ||
          f2 == 'cancelled') {
        _goToPassengerHome();
        return;
      }
    } catch (_) {}
  }

  Marker _meMarker(LatLng p) {
    return Marker(
      point: p,
      width: 70,
      height: 70,
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFF1A73E8).withOpacity(0.18),
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: const Color(0xFF1A73E8),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Marker _destMarker(LatLng p) {
    return Marker(
      point: p,
      width: 46,
      height: 46,
      child: const Icon(Icons.location_on, color: Colors.green, size: 42),
    );
  }

  Marker _driverMarker(LatLng p) {
    return Marker(
      point: p,
      width: 52,
      height: 52,
      child: Align(
        alignment: Alignment.center,
        child: Image.asset(
          'assets/images/mulitita.png',
          width: 38,
          height: 38,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Future<void> _refreshPositions() async {
    if (_navigating || _canceling) return;

    final id = _asInt(widget.ride['id']);
    if (id == null) return;

    try {
      final pos = await Geolocator.getCurrentPosition();
      _myPos = LatLng(pos.latitude, pos.longitude);

      final res = await http.get(
        Uri.parse("$_apiBase/rides/$id"),
        headers: await _authHeaders(),
      );

      if (res.statusCode == 404) {
        _goToPassengerHome();
        return;
      }

      if (res.statusCode == 200) {
        final data = _asJsonMap(jsonDecode(res.body));
        if (data != null) {
          final dlat = _asDouble(data['driver_lat']);
          final dlng = _asDouble(data['driver_lng']);
          _driverPos =
              (dlat != null && dlng != null) ? LatLng(dlat, dlng) : null;

          final status = _norm(data['status']);
          final fase = _norm(data['fase']);

          if (status == 'completed' || fase == 'completado') {
            _goToCompleted(data);
            return;
          }

          if (status == 'cancelled' ||
              status == 'canceled' ||
              fase == 'cancelado' ||
              fase == 'cancelled') {
            _goToPassengerHome();
            return;
          }
        }
      }

      _syncMarkers();
      await _maybeUpdateRoute();

      if (!mounted || _navigating) return;
      setState(() {});
    } catch (_) {
      if (!mounted || _navigating) return;
      setState(() {});
    }
  }

  void _syncMarkers() {
    final out = <Marker>[];

    final endLat = _asDouble(widget.ride['end_lat']);
    final endLng = _asDouble(widget.ride['end_lng']);
    final dest =
        (endLat != null && endLng != null) ? LatLng(endLat, endLng) : null;

    if (_myPos != null) out.add(_meMarker(_myPos!));
    if (_driverPos != null) out.add(_driverMarker(_driverPos!));
    if (dest != null) out.add(_destMarker(dest));

    if (!mounted) return;
    setState(() {
      _markers
        ..clear()
        ..addAll(out);
    });
  }

  Future<void> _maybeUpdateRoute() async {
    final endLat = _asDouble(widget.ride['end_lat']);
    final endLng = _asDouble(widget.ride['end_lng']);
    if (endLat == null || endLng == null) return;

    final to = LatLng(endLat, endLng);
    final from = _driverPos ?? _myPos;
    if (from == null) return;

    final now = DateTime.now();
    final tooSoon = now.difference(_lastRouteAt) < const Duration(seconds: 12);

    bool sameFrom = false;
    if (_lastRouteFrom != null) {
      final dLat = (from.latitude - _lastRouteFrom!.latitude).abs();
      final dLng = (from.longitude - _lastRouteFrom!.longitude).abs();
      sameFrom = dLat < 0.00025 && dLng < 0.00025;
    }

    final sameTo = _lastRouteTo != null &&
        (to.latitude - _lastRouteTo!.latitude).abs() < 0.000001 &&
        (to.longitude - _lastRouteTo!.longitude).abs() < 0.000001;

    if (tooSoon && sameFrom && sameTo) return;

    _lastRouteFrom = from;
    _lastRouteTo = to;
    _lastRouteAt = now;

    final url =
        "https://router.project-osrm.org/route/v1/driving/${from.longitude},${from.latitude};${to.longitude},${to.latitude}?overview=full&geometries=geojson";

    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200) return;

      final j = jsonDecode(res.body);
      if (j is! Map) return;

      final routes = j['routes'];
      if (routes is! List || routes.isEmpty) return;

      final geom = routes[0]['geometry'];
      if (geom is! Map) return;

      final coords = geom['coordinates'];
      if (coords is! List) return;

      final pts = <LatLng>[];
      for (final c in coords) {
        if (c is! List || c.length < 2) continue;
        final lng = _asDouble(c[0]);
        final lat = _asDouble(c[1]);
        if (lat == null || lng == null) continue;
        pts.add(LatLng(lat, lng));
      }

      if (pts.length < 2 || !mounted) return;

      setState(() {
        _polylines
          ..clear()
          ..add(
            Polyline(
              points: pts,
              strokeWidth: 5,
              color: _brand,
            ),
          );
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final center = _myPos ?? const LatLng(19.7050, -101.1927);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Viaje en curso"),
        actions: [
          TextButton.icon(
            onPressed: _canceling ? null : _confirmCancel,
            icon: _canceling
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cancel, color: Colors.white),
            label:
                const Text('Cancelar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Stack(
        children: [
          (_myPos == null)
              ? const Center(child: CircularProgressIndicator())
              : FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: 14,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                      userAgentPackageName: "com.flashride.app",
                    ),
                    PolylineLayer(polylines: _polylines),
                    MarkerLayer(markers: _markers),
                  ],
                ),
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'compartir',
                  icon: const Icon(Icons.share),
                  label: const Text("Compartir"),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text("🔗 Compartir viaje (demo)")),
                    );
                  },
                ),
                FloatingActionButton.extended(
                  heroTag: 'panico',
                  backgroundColor: Colors.red,
                  icon: const Icon(Icons.warning_amber),
                  label: const Text("Pánico"),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text("⚠️ Botón de pánico (demo)")),
                    );
                  },
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
