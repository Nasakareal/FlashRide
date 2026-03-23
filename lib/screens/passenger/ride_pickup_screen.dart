import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../services/auth_service.dart';
import 'ride_inprogress_screen.dart';
import 'ride_completed_screen.dart';
import 'passenger_home_screen.dart';

/// Resultado de ruteo (TOP-LEVEL, no dentro de la clase)
class _RouteResult {
  final List<LatLng> points;
  final String? etaText;
  final String? distText;

  const _RouteResult({
    required this.points,
    this.etaText,
    this.distText,
  });
}

class PassengerPickupScreen extends StatefulWidget {
  final Map<String, dynamic> ride;
  const PassengerPickupScreen({super.key, required this.ride});

  @override
  State<PassengerPickupScreen> createState() => _PassengerPickupScreenState();
}

class _PassengerPickupScreenState extends State<PassengerPickupScreen> {
  static final String _API = AuthService.baseUrl;

  static const String _ROUTE_CHAT = '/chat';
  static const String _ROUTE_DRIVER_PROFILE = '/driver_profile_view';

  final MapController _mapController = MapController();

  List<Marker> _markers = const [];
  List<Polyline> _polylines = const [];

  LatLng? _driverPos;
  LatLng? _lastDriverPos;

  Timer? _pollTimer;

  late final double _startLat;
  late final double _startLng;

  bool _alive = true;
  bool _navigating = false;
  bool _canceling = false;

  Map<String, dynamic> _driverInfo = {};
  String? _etaText;
  String? _distText;

  bool _taxiIconLoaded = false;

  // ---- Anti-parpadeo / anti-spam ----
  bool _didAutoFitOnce = false;

  LatLng? _lastRouteFrom;
  LatLng? _lastRouteTo;
  DateTime _lastRouteAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();

    _startLat =
        double.tryParse(widget.ride['start_lat']?.toString() ?? '') ?? 0.0;
    _startLng =
        double.tryParse(widget.ride['start_lng']?.toString() ?? '') ?? 0.0;

    _loadTaxiIcon();
    _refreshRide(immediate: true);
    _pollTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _refreshRide());
  }

  @override
  void dispose() {
    _alive = false;
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTaxiIcon() async {
    if (!_alive) return;
    setState(() {
      _taxiIconLoaded = true;
    });
  }

  Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
  }

  double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  void _goPassengerHome() {
    if (!_alive || !mounted) return;
    _pollTimer?.cancel();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const PassengerHomeScreen()),
      (_) => false,
    );
  }

  LatLng? _extractDriverPos(Map<String, dynamic> data) {
    final dLat = _asDouble(data['driver_lat']);
    final dLng = _asDouble(data['driver_lng']);
    if (dLat != null && dLng != null) return LatLng(dLat, dLng);

    final driver = data['driver'];
    if (driver is Map) {
      final lat = _asDouble(driver['lat'] ?? driver['driver_lat']);
      final lng = _asDouble(driver['lng'] ?? driver['driver_lng']);
      if (lat != null && lng != null) return LatLng(lat, lng);
    }

    final dl = data['driver_location'];
    if (dl is Map) {
      final lat = _asDouble(dl['lat'] ?? dl['driver_lat']);
      final lng = _asDouble(dl['lng'] ?? dl['driver_lng']);
      if (lat != null && lng != null) return LatLng(lat, lng);
    }

    return null;
  }

  LatLng? _extractDriverPosFromAny(dynamic j) {
    if (j is Map) {
      final lat = _asDouble(j['lat'] ?? j['driver_lat'] ?? j['latitude']);
      final lng = _asDouble(j['lng'] ?? j['driver_lng'] ?? j['longitude']);
      if (lat != null && lng != null) return LatLng(lat, lng);

      final nested = j['data'] ?? j['driver_location'] ?? j['location'];
      if (nested is Map) {
        final lat2 = _asDouble(
            nested['lat'] ?? nested['driver_lat'] ?? nested['latitude']);
        final lng2 = _asDouble(
            nested['lng'] ?? nested['driver_lng'] ?? nested['longitude']);
        if (lat2 != null && lng2 != null) return LatLng(lat2, lng2);
      }
    }
    return null;
  }

  Future<LatLng?> _fetchDriverLocation(int rideId) async {
    try {
      final res = await http.get(
        Uri.parse('$_API/rides/$rideId/driver-location'),
        headers: await _headers(),
      );
      if (res.statusCode != 200) return null;

      final j = jsonDecode(res.body);
      return _extractDriverPosFromAny(j);
    } catch (_) {
      return null;
    }
  }

  Future<void> _refreshRide({bool immediate = false}) async {
    if (_navigating || !_alive) return;

    final rideId = _asInt(widget.ride['id']);
    if (rideId == null) return;

    try {
      final res = await http.get(
        Uri.parse('$_API/rides/$rideId'),
        headers: await _headers(),
      );

      if (!_alive) return;

      if (res.statusCode == 404) {
        _pollTimer?.cancel();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El viaje ya no existe.')),
        );
        _goPassengerHome();
        return;
      }

      if (res.statusCode != 200) return;

      final data = jsonDecode(res.body);
      if (data is! Map<String, dynamic>) return;

      final fase = (data['fase'] ?? data['status'] ?? '').toString().trim();

      final newDriverInfo = _extractDriverInfo(data);
      LatLng? pos = _extractDriverPos(data);

      final hasDriverId =
          data['driver_id'] != null || newDriverInfo['driver_id'] != null;

      if (pos == null && hasDriverId) {
        pos = await _fetchDriverLocation(rideId);
      }

      if (!_alive || !mounted) return;

      setState(() {
        _driverInfo = newDriverInfo;
        if (pos != null) _driverPos = pos;
      });

      await _paint(data);

      if (!_alive || !mounted || _navigating) return;

      switch (fase.toLowerCase()) {
        case 'viajando':
        case 'in_progress':
          _navigating = true;
          _pollTimer?.cancel();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => PassengerRideInProgressScreen(ride: data),
            ),
          );
          break;

        case 'completado':
        case 'completed':
          _navigating = true;
          _pollTimer?.cancel();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => RideCompletedScreen(ride: data),
            ),
          );
          break;

        case 'cancelado':
        case 'canceled':
          _pollTimer?.cancel();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('El viaje fue cancelado.')),
          );
          _goPassengerHome();
          break;

        default:
          break;
      }
    } catch (e) {
      debugPrint('Error refrescando pickup: $e');
    }
  }

  Map<String, dynamic> _extractDriverInfo(Map<String, dynamic> data) {
    final out = <String, dynamic>{};

    final driver = data['driver'];
    if (driver is Map) {
      out['driver_id'] = driver['id'] ?? data['driver_id'];
      out['name'] = driver['name'] ?? driver['nombre'] ?? data['driver_name'];
      out['rating'] = driver['rating'] ?? data['driver_rating'];
      out['phone'] =
          driver['phone'] ?? driver['telefono'] ?? data['driver_phone'];
      out['photo_url'] =
          driver['photo_url'] ?? driver['avatar'] ?? data['driver_photo_url'];
    } else {
      out['driver_id'] = data['driver_id'];
      out['name'] = data['driver_name'];
      out['rating'] = data['driver_rating'];
      out['phone'] = data['driver_phone'];
      out['photo_url'] = data['driver_photo_url'];
    }

    final vehicle = data['vehicle'];
    if (vehicle is Map) {
      out['vehicle_model'] = vehicle['model'] ?? vehicle['modelo'];
      out['vehicle_brand'] = vehicle['brand'] ?? vehicle['marca'];
      out['plate'] = vehicle['plate'] ?? vehicle['placas'];
      out['color'] = vehicle['color'];
      out['unit_name'] =
          vehicle['name'] ?? vehicle['unit'] ?? vehicle['unidad'];
    } else {
      out['plate'] = data['plate'] ?? data['vehicle_plate'];
      out['unit_name'] = data['vehicle_name'] ?? data['unit_name'];
    }

    return out;
  }

  Future<void> _cancelRide() async {
    if (_canceling) return;

    final rideId = _asInt(widget.ride['id']);
    if (rideId == null) return;

    if (!_alive || !mounted) return;
    setState(() => _canceling = true);

    try {
      final res = await http.post(
        Uri.parse('$_API/rides/$rideId/cancel'),
        headers: await _headers(),
        body: jsonEncode({'reason': 'Cancelado por el pasajero'}),
      );

      if (!_alive) return;
      if (!mounted) return;

      if (res.statusCode == 200 || res.statusCode == 204) {
        _pollTimer?.cancel();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Viaje cancelado.')),
        );
        _goPassengerHome();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo cancelar: ${res.statusCode}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cancelando: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _canceling = false);
    }
  }

  // ---------- RUTA sin Google: OSRM ----------
  Future<_RouteResult?> _routeOSRM(
      {required LatLng from, required LatLng to}) async {
    // Throttle: no rutees cada 5s si casi no cambió nada o si fue hace poco.
    final now = DateTime.now();
    final tooSoon = now.difference(_lastRouteAt) < const Duration(seconds: 12);

    bool sameFrom = false;
    if (_lastRouteFrom != null) {
      sameFrom = _haversineMeters(_lastRouteFrom!, from) < 10; // <10m
    }
    final sameTo =
        _lastRouteTo != null && _haversineMeters(_lastRouteTo!, to) < 2; // <2m

    if (tooSoon && sameFrom && sameTo) {
      return null; // no actualizamos ruta/eta/dist
    }

    _lastRouteFrom = from;
    _lastRouteTo = to;
    _lastRouteAt = now;

    final url =
        "https://router.project-osrm.org/route/v1/driving/${from.longitude},${from.latitude};${to.longitude},${to.latitude}"
        "?overview=full&geometries=geojson";

    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200) return null;

      final j = jsonDecode(res.body);
      if (j is! Map) return null;

      final routes = j['routes'];
      if (routes is! List || routes.isEmpty) return null;

      final r0 = routes[0];
      if (r0 is! Map) return null;

      final geom = r0['geometry'];
      if (geom is! Map) return null;

      final coords = geom['coordinates'];
      if (coords is! List) return null;

      final pts = <LatLng>[];
      for (final c in coords) {
        if (c is! List || c.length < 2) continue;
        final lng = _asDouble(c[0]);
        final lat = _asDouble(c[1]);
        if (lat == null || lng == null) continue;
        pts.add(LatLng(lat, lng));
      }

      final distM = _asDouble(r0['distance']); // metros
      final durS = _asDouble(r0['duration']); // segundos

      String? distText;
      if (distM != null) {
        final km = distM / 1000.0;
        distText =
            (km < 1) ? "${distM.round()} m" : "${km.toStringAsFixed(1)} km";
      }

      String? etaText;
      if (durS != null) {
        final mins = (durS / 60.0).round();
        if (mins < 60) {
          etaText = "$mins min";
        } else {
          final h = mins ~/ 60;
          final m = mins % 60;
          etaText = (m == 0) ? "${h} h" : "${h} h ${m} min";
        }
      }

      return _RouteResult(points: pts, etaText: etaText, distText: distText);
    } catch (_) {
      return null;
    }
  }

  Future<void> _paint(Map<String, dynamic> data) async {
    if (!_alive || !mounted) return;

    final me = LatLng(_startLat, _startLng);

    if (_driverPos == null) {
      setState(() {
        _markers = [
          Marker(
            point: me,
            width: 46,
            height: 46,
            child: const Icon(Icons.location_on, color: Colors.blue, size: 42),
          ),
        ];
        _polylines = const [];
        _etaText = null;
        _distText = null;
        _didAutoFitOnce = false;
      });

      _fitBounds([me]);
      return;
    }

    final driver = _driverPos!;

    final prev = _lastDriverPos;
    _lastDriverPos = driver;

    final bearing = (prev == null) ? 0.0 : _bearingDegrees(prev, driver);
    final bearingRad = bearing * (pi / 180.0);

    // Solo rutea si realmente cambió el driver un mínimo (o si no hay polyline aún)
    final movedEnough =
        prev == null ? true : _haversineMeters(prev, driver) >= 8;

    _RouteResult? rr;
    if (movedEnough || _polylines.isEmpty) {
      rr = await _routeOSRM(from: driver, to: me);
    }

    final driverName =
        (_driverInfo['name']?.toString().trim().isNotEmpty ?? false)
            ? _driverInfo['name'].toString()
            : 'Conductor';

    final driverMarker = Marker(
      point: driver,
      width: 54,
      height: 54,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.rotate(
            angle: bearingRad,
            child: Image.asset(
              'assets/images/mulitita.png',
              width: 38,
              height: 38,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.local_taxi, size: 34),
            ),
          ),
          const SizedBox(height: 2),
          SizedBox(
            width: 120,
            child: Text(
              driverName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    final meMarker = Marker(
      point: me,
      width: 46,
      height: 46,
      child: const Icon(Icons.location_on, color: Colors.blue, size: 42),
    );

    if (!_alive || !mounted) return;

    setState(() {
      _markers = [driverMarker, meMarker];

      if (rr != null) {
        if (rr.points.isNotEmpty) {
          _polylines = [
            Polyline(
              points: rr.points,
              strokeWidth: 5,
            )
          ];
        } else {
          _polylines = const [];
        }
        _etaText = rr.etaText;
        _distText = rr.distText;
      }
    });

    // IMPORTANTÍSIMO: no fittees cada tick. Solo 1 vez.
    if (!_didAutoFitOnce) {
      final pts = <LatLng>[driver, me];
      if (_polylines.isNotEmpty) {
        pts.addAll(_polylines.first.points);
      }
      _fitBounds(pts);
      _didAutoFitOnce = true;
    }
  }

  void _fitBounds(List<LatLng> pts) {
    if (!_alive || !mounted) return;
    if (pts.isEmpty) return;

    final b = _boundsFrom(pts);
    try {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: b,
          padding: const EdgeInsets.all(80),
        ),
      );
    } catch (_) {}
  }

  double _haversineMeters(LatLng a, LatLng b) {
    const R = 6371000.0;
    final dLat = (b.latitude - a.latitude) * (pi / 180.0);
    final dLon = (b.longitude - a.longitude) * (pi / 180.0);
    final la1 = a.latitude * (pi / 180.0);
    final la2 = b.latitude * (pi / 180.0);
    final x = sin(dLat / 2) * sin(dLat / 2) +
        cos(la1) * cos(la2) * sin(dLon / 2) * sin(dLon / 2);
    return 2 * R * atan2(sqrt(x), sqrt(1 - x));
  }

  double _bearingDegrees(LatLng from, LatLng to) {
    final lat1 = from.latitude * (pi / 180.0);
    final lat2 = to.latitude * (pi / 180.0);
    final dLon = (to.longitude - from.longitude) * (pi / 180.0);

    final y = sin(dLon) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
    var brng = atan2(y, x) * (180.0 / pi);
    brng = (brng + 360.0) % 360.0;
    return brng;
  }

  LatLngBounds _boundsFrom(Iterable<LatLng> points) {
    final it = points.iterator;
    if (!it.moveNext()) {
      final c = LatLng(_startLat, _startLng);
      return LatLngBounds(c, c);
    }
    double minLat = it.current.latitude, maxLat = it.current.latitude;
    double minLng = it.current.longitude, maxLng = it.current.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));
  }

  Future<void> _confirmCancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancelar viaje'),
        content: const Text('¿Seguro que deseas cancelar este viaje?'),
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

  void _openDriverProfile() {
    Navigator.pushNamed(
      context,
      _ROUTE_DRIVER_PROFILE,
      arguments: {
        'ride_id': widget.ride['id'],
        'driver_id': _driverInfo['driver_id'] ?? widget.ride['driver_id'],
        'driver': _driverInfo,
      },
    );
  }

  void _openChat() {
    Navigator.pushNamed(
      context,
      _ROUTE_CHAT,
      arguments: {
        'ride_id': widget.ride['id'],
        'driver_id': _driverInfo['driver_id'] ?? widget.ride['driver_id'],
        'driver': _driverInfo,
      },
    );
  }

  Widget _bottomDriverCard() {
    final name = (_driverInfo['name']?.toString().trim().isNotEmpty ?? false)
        ? _driverInfo['name'].toString()
        : 'Conductor asignado';

    final plate = _driverInfo['plate']?.toString();
    final unit = _driverInfo['unit_name']?.toString();
    final ratingRaw = _driverInfo['rating'];
    final rating = (ratingRaw is num)
        ? ratingRaw.toDouble()
        : double.tryParse(ratingRaw?.toString() ?? '');

    final eta = _etaText;
    final dist = _distText;

    final hasDriver =
        (_driverInfo.isNotEmpty) || (widget.ride['driver_id'] != null);
    final hasDriverAssigned = (_driverInfo['driver_id'] != null) ||
        (widget.ride['driver_id'] != null);

    final statusText = (_driverPos == null)
        ? (hasDriverAssigned
            ? 'Esperando ubicación del conductor…'
            : 'Asignando conductor…')
        : 'Tu conductor va en camino. Prepárate para abordarlo.';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: const [
          BoxShadow(
            blurRadius: 14,
            spreadRadius: 0,
            offset: Offset(0, -3),
            color: Color(0x22000000),
          )
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.grey.shade200,
                child: const Icon(Icons.person, color: Colors.black54),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (rating != null) ...[
                          const Icon(Icons.star, size: 16, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            rating.toStringAsFixed(1),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 10),
                        ],
                        if (unit != null && unit.trim().isNotEmpty) ...[
                          const Icon(Icons.local_taxi, size: 16),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              unit,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (plate != null && plate.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Placas: $plate',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    (_driverPos != null && eta != null && eta.isNotEmpty)
                        ? eta
                        : 'Calculando…',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    (_driverPos != null && dist != null && dist.isNotEmpty)
                        ? dist
                        : '',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: hasDriver ? _openDriverProfile : null,
                  icon: const Icon(Icons.badge),
                  label: const Text('Perfil'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: hasDriver ? _openChat : null,
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Chat'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            statusText,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = LatLng(_startLat, _startLng);
    final center = _driverPos ?? me;

    final tilesReady = _taxiIconLoaded;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tu conductor va en camino'),
        actions: [
          IconButton(
            tooltip: 'Cancelar viaje',
            onPressed: _canceling ? null : _confirmCancel,
            icon: _canceling
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cancel, color: Colors.redAccent),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: 14,
                interactionOptions:
                    const InteractionOptions(flags: InteractiveFlag.all),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'flashride_app',
                ),
                if (_polylines.isNotEmpty) PolylineLayer(polylines: _polylines),
                MarkerLayer(
                  markers: _markers.isNotEmpty
                      ? _markers
                      : [
                          Marker(
                            point: me,
                            width: 46,
                            height: 46,
                            child: const Icon(Icons.location_on,
                                color: Colors.blue, size: 42),
                          ),
                        ],
                ),
                if (!tilesReady) const SizedBox.shrink(),
              ],
            ),
          ),
          _bottomDriverCard(),
        ],
      ),
    );
  }
}
