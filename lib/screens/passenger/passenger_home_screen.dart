import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../../services/google_places_service.dart';
import '../../services/transit_service.dart';
import 'ride_awaiting_screen.dart';
import 'ride_pickup_screen.dart';
import 'ride_inprogress_screen.dart';
import 'ride_completed_screen.dart';
import 'ride_details_screen.dart';
import 'transit/route_list_screen.dart';
import 'transit/route_map_screen.dart';
import 'widgets/passenger_drawer.dart';
import 'widgets/passenger_osm_map.dart';
import 'widgets/passenger_search_bar.dart';
import 'widgets/request_ride_button.dart';
import 'widgets/transit_suggestions_panel.dart';

const _apiKey = 'AIzaSyAunhRNSucPlDvMPIAdah7pERRg-pJfKZw';
const _fallback = LatLng(19.7050, -101.1927);

class PassengerHomeScreen extends StatefulWidget {
  const PassengerHomeScreen({super.key});

  @override
  State<PassengerHomeScreen> createState() => _PassengerHomeScreenState();
}

class _PassengerHomeScreenState extends State<PassengerHomeScreen> {
  final MapController _mapController = MapController();

  LatLng? _me;
  LatLng? _dest;

  final List<Marker> _markers = <Marker>[];
  final List<Marker> _driverMarkers = <Marker>[];
  final Map<String, LatLng> _lastDriverPositions = <String, LatLng>{};
  final Map<String, double> _driverBearings = <String, double>{};

  final _searchCtl = TextEditingController();
  List<PlaceSug> _sugs = const [];
  bool _loadingSugs = false;

  String _nombre = 'Pasajero';

  Timer? _timerConductores;
  Timer? _timerRideWatcher;
  Timer? _debounceSug;

  static final _base = AuthService.baseUrl;

  bool _alive = true;
  int _runId = 0;
  String _token = '';
  bool _navigatingRide = false;

  bool _hasAutoCentered = false;
  bool _userMovedMap = false;
  bool _allowAutoFit = true;

  late final GooglePlacesService _places =
      const GooglePlacesService(apiKey: _apiKey);
  late final TransitService _transitService = TransitService();

  List<TransitRouteSuggestion> _transitSuggestions = const [];
  List<Polyline> _transitPolylines = const [];
  bool _loadingTransitSuggestions = false;
  bool _checkedTransitSuggestions = false;
  String _selectedDestinationLabel = '';
  int _transitSearchId = 0;

  bool get _canRequestRide {
    return _me != null && _dest != null;
  }

  Future<Map<String, String>> _authHeaders() async {
    return {
      'Authorization': 'Bearer $_token',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final rid = _runId;

    final prefs = await SharedPreferences.getInstance();
    if (!_alive || rid != _runId) return;

    _token = prefs.getString('token') ?? '';
    _nombre = prefs.getString('name') ?? 'Pasajero';

    if (!_alive || !mounted || rid != _runId) return;
    setState(() {});

    await _locate();
    if (!_alive || rid != _runId) return;

    await _cargarConductoresCercanos();
    if (!_alive || rid != _runId) return;

    _timerRideWatcher =
        Timer.periodic(const Duration(seconds: 3), (_) => _checkRide());

    _timerConductores = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!_alive || _navigatingRide) return;

      await _locate();
      if (!_alive || _navigatingRide) return;

      await _cargarConductoresCercanos();
    });
  }

  @override
  void dispose() {
    _alive = false;
    _runId++;

    _debounceSug?.cancel();
    _timerConductores?.cancel();
    _timerRideWatcher?.cancel();
    _searchCtl.dispose();
    super.dispose();
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
                color: const Color(0xFF1A73E8).withValues(alpha: 0.18),
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

  void _syncMarkers() {
    final out = <Marker>[];

    if (_me != null) out.add(_meMarker(_me!));
    out.addAll(_driverMarkers);
    if (_dest != null) out.add(_destMarker(_dest!));

    if (!_alive || !mounted) return;
    setState(() {
      _markers
        ..clear()
        ..addAll(out);
    });
  }

  Future<void> _locate() async {
    final rid = _runId;

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (!_alive || !mounted || rid != _runId) return;
        setState(() => _me = _fallback);
        _syncMarkers();
        return;
      }

      var p = await Geolocator.checkPermission();
      if (!_alive || rid != _runId) return;

      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
        if (!_alive || rid != _runId) return;
      }

      if (p == LocationPermission.denied ||
          p == LocationPermission.deniedForever) {
        if (!_alive || !mounted || rid != _runId) return;
        setState(() => _me = _fallback);
        _syncMarkers();
        return;
      }

      final pos = await Geolocator.getCurrentPosition();
      if (!_alive || !mounted || rid != _runId) return;

      setState(() {
        _me = LatLng(pos.latitude, pos.longitude);
      });

      if (_me != null && !_hasAutoCentered) {
        _mapController.move(_me!, 15);
        if (!_alive || rid != _runId) return;
        _hasAutoCentered = true;
      }

      _syncMarkers();
    } catch (_) {
      if (!_alive || !mounted || rid != _runId) return;
      setState(() => _me = _fallback);
      _syncMarkers();
    }
  }

  double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse('$v');
  }

  String _driverKey(Map<dynamic, dynamic> d, double lat, double lng) {
    final raw = d['id'] ??
        d['driver_id'] ??
        d['user_id'] ??
        d['vehicle_id'] ??
        d['name'];
    if (raw != null && raw.toString().trim().isNotEmpty) {
      return raw.toString();
    }
    return '${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}';
  }

  double _bearingDegrees(LatLng from, LatLng to) {
    final lat1 = from.latitude * (math.pi / 180.0);
    final lat2 = to.latitude * (math.pi / 180.0);
    final dLon = (to.longitude - from.longitude) * (math.pi / 180.0);

    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final brng = math.atan2(y, x) * (180.0 / math.pi);
    return (brng + 360.0) % 360.0;
  }

  Color _colorFromHex(String hex) {
    final normalized = hex.trim().replaceAll('#', '');
    final candidate = normalized.length == 6 ? 'FF$normalized' : normalized;
    try {
      return Color(int.parse(candidate, radix: 16));
    } catch (_) {
      return const Color(0xFF0B57D0);
    }
  }

  List<Polyline> _buildTransitPolylines(
    List<TransitRouteSuggestion> suggestions,
  ) {
    return suggestions
        .asMap()
        .entries
        .where((entry) => entry.value.polylinePoints.length >= 2)
        .map(
          (entry) => Polyline(
            points: entry.value.polylinePoints,
            color: _colorFromHex(entry.value.colorHex).withValues(
              alpha: entry.key == 0 ? 0.85 : 0.65,
            ),
            strokeWidth: entry.key == 0 ? 6 : 5,
          ),
        )
        .toList();
  }

  void _clearTransitSuggestions({bool resetChecked = true}) {
    _transitSearchId++;

    if (!_alive || !mounted) return;
    setState(() {
      _loadingTransitSuggestions = false;
      _transitSuggestions = const [];
      _transitPolylines = const [];
      if (resetChecked) {
        _checkedTransitSuggestions = false;
      }
    });
  }

  Future<void> _loadTransitSuggestions(LatLng destination) async {
    final searchId = ++_transitSearchId;

    if (!_alive || !mounted) return;
    setState(() {
      _loadingTransitSuggestions = true;
      _checkedTransitSuggestions = false;
      _transitSuggestions = const [];
      _transitPolylines = const [];
    });

    try {
      final suggestions = await _transitService.suggestRoutesForDestination(
        destination: destination,
      );

      if (!_alive || !mounted || searchId != _transitSearchId) return;
      setState(() {
        _loadingTransitSuggestions = false;
        _checkedTransitSuggestions = true;
        _transitSuggestions = suggestions;
        _transitPolylines = _buildTransitPolylines(suggestions);
      });
    } catch (_) {
      if (!_alive || !mounted || searchId != _transitSearchId) return;
      setState(() {
        _loadingTransitSuggestions = false;
        _checkedTransitSuggestions = false;
        _transitSuggestions = const [];
        _transitPolylines = const [];
      });
    }
  }

  Future<void> _openTransitSuggestion(TransitRouteSuggestion suggestion) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransitRouteMapScreen(
          routeId: suggestion.routeId,
          title: suggestion.title,
        ),
      ),
    );
  }

  Future<void> _askSug(String txt) async {
    _debounceSug?.cancel();
    final rid = _runId;
    final query = txt.trim();

    if (query != _selectedDestinationLabel.trim()) {
      _clearTransitSuggestions();
    }

    if (query.isEmpty) {
      if (!_alive || !mounted || rid != _runId) return;
      setState(() {
        _loadingSugs = false;
        _sugs = const [];
      });
      return;
    }

    _debounceSug = Timer(const Duration(milliseconds: 350), () async {
      if (!_alive || rid != _runId) return;
      if (!mounted || rid != _runId) return;

      setState(() => _loadingSugs = true);

      try {
        final near = _me ?? _fallback;
        final sugs = await _places.autocomplete(input: query, near: near);

        if (!_alive || !mounted || rid != _runId) return;
        setState(() {
          _loadingSugs = false;
          _sugs = sugs;
        });
      } catch (_) {
        if (!_alive || !mounted || rid != _runId) return;
        setState(() => _loadingSugs = false);
      }
    });
  }

  Future<void> _pickSug(PlaceSug s) async {
    final rid = _runId;

    _searchCtl.text = s.desc;
    _selectedDestinationLabel = s.desc;

    if (!_alive || !mounted || rid != _runId) return;
    setState(() => _sugs = const []);

    try {
      final pos = await _places.placeDetailsLatLng(placeId: s.id);

      if (!_alive || rid != _runId) return;

      setState(() {
        _dest = pos;
      });

      _syncMarkers();
      _mapController.move(pos, 15);
      await _loadTransitSuggestions(pos);
    } catch (_) {}
  }

  LatLngBounds _boundsFrom(Iterable<LatLng> points) {
    final it = points.iterator;
    if (!it.moveNext()) {
      final c = _me ?? _fallback;
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

  void _fitBounds(LatLngBounds b) {
    final cam = CameraFit.bounds(bounds: b, padding: const EdgeInsets.all(60));
    _mapController.fitCamera(cam);
  }

  Future<void> _estimarCosto() async {
    if (_me == null || _dest == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Ubicación actual o destino no definido.')),
      );
      return;
    }

    final response = await http.post(
      Uri.parse('$_base/rides/estimate'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'start_lat': _me!.latitude,
        'start_lng': _me!.longitude,
        'end_lat': _dest!.latitude,
        'end_lng': _dest!.longitude,
      }),
    );

    if (!_alive) return;

    if (response.statusCode != 200) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error al estimar: ${response.statusCode} ${response.body}',
          ),
        ),
      );
      return;
    }

    final data = jsonDecode(response.body);
    final cost = data['estimated_cost'];
    final distance = data['distance_km'];

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Costo estimado'),
        content: Text(
          'El viaje cuesta aprox. \$${cost.toString()} por ${distance.toString()} km. ¿Deseas continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _solicitarViaje();
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  Future<void> _solicitarViaje() async {
    if (_me == null || _dest == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Ubicación actual o destino no definido.')),
      );
      return;
    }

    final response = await http.post(
      Uri.parse('$_base/rides'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'start_lat': _me!.latitude,
        'start_lng': _me!.longitude,
        'end_lat': _dest!.latitude,
        'end_lng': _dest!.longitude,
      }),
    );

    if (!_alive) return;
    if (!mounted) return;

    if (response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Viaje solicitado. Buscando conductor…')),
      );
      await _checkRide(forceNavigate: true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error al solicitar: ${response.statusCode} ${response.body}',
          ),
        ),
      );
    }
  }

  Future<void> _openTransit() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TransitRouteListScreen()),
    );
  }

  Future<Map<String, dynamic>?> _cargarViajeEnCurso() async {
    try {
      final res = await http.get(
        Uri.parse('$_base/rides/active'),
        headers: await _authHeaders(),
      );

      if (res.statusCode == 401) return null;
      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body);
      if (data is Map && data['fase'] != null) {
        return data.cast<String, dynamic>();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _checkRide({bool forceNavigate = false}) async {
    if (_navigatingRide) return;

    final rid = _runId;

    final ride = await _cargarViajeEnCurso();
    if (!_alive || !mounted || rid != _runId) return;

    if (ride != null && ride['fase'] != null) {
      _navigatingRide = true;

      _timerConductores?.cancel();
      _timerRideWatcher?.cancel();
      _debounceSug?.cancel();

      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => _getRideScreen(ride)))
          .then((_) {
        if (!_alive || !mounted) return;
        _navigatingRide = false;

        _timerRideWatcher?.cancel();
        _timerConductores?.cancel();

        _timerRideWatcher =
            Timer.periodic(const Duration(seconds: 3), (_) => _checkRide());
        _timerConductores =
            Timer.periodic(const Duration(seconds: 10), (_) async {
          if (!_alive || _navigatingRide) return;
          await _locate();
          if (!_alive || _navigatingRide) return;
          await _cargarConductoresCercanos();
        });
      });

      return;
    }

    if (forceNavigate) return;
  }

  Widget _getRideScreen(Map<String, dynamic> ride) {
    final fase = (ride['fase'] ?? '').toString().toLowerCase().trim();
    switch (fase) {
      case 'esperando':
        return PassengerAwaitingScreen(ride: ride);
      case 'recogiendo':
        return PassengerPickupScreen(ride: ride);
      case 'viajando':
        return PassengerRideInProgressScreen(ride: ride);
      case 'completado':
        return RideCompletedScreen(ride: ride);
      default:
        return RideDetailsScreen(ride: ride);
    }
  }

  Future<void> _cargarConductoresCercanos() async {
    if (!_alive || _navigatingRide) return;
    final rid = _runId;

    try {
      final res = await http.get(
        Uri.parse('$_base/drivers/nearby'),
        headers: await _authHeaders(),
      );

      if (!_alive || rid != _runId) return;

      if (res.statusCode != 200) {
        if (!mounted) return;
        setState(() {
          _driverMarkers.clear();
        });
        _syncMarkers();
        return;
      }

      final list = jsonDecode(res.body);
      if (list is! List) {
        if (!mounted) return;
        setState(() {
          _driverMarkers.clear();
        });
        _syncMarkers();
        return;
      }

      final next = <Marker>[];
      final nextPositions = <String, LatLng>{};
      final nextBearings = <String, double>{};

      for (final d in list) {
        if (d is! Map) continue;
        if (d['lat'] == null || d['lng'] == null) continue;

        final latVal = d['lat'];
        final lngVal = d['lng'];

        final lat =
            (latVal is num) ? latVal.toDouble() : double.tryParse('$latVal');
        final lng =
            (lngVal is num) ? lngVal.toDouble() : double.tryParse('$lngVal');
        if (lat == null || lng == null) continue;

        final point = LatLng(lat, lng);
        final key = _driverKey(d, lat, lng);
        final explicitBearing = _asDouble(
          d['bearing'] ?? d['heading'] ?? d['last_bearing'],
        );
        final previousPoint = _lastDriverPositions[key];
        final movedEnough = previousPoint != null &&
            Geolocator.distanceBetween(
                  previousPoint.latitude,
                  previousPoint.longitude,
                  point.latitude,
                  point.longitude,
                ) >=
                3;
        final inferredBearing =
            movedEnough ? _bearingDegrees(previousPoint, point) : null;
        final bearing =
            explicitBearing ?? inferredBearing ?? _driverBearings[key] ?? 0.0;
        final bearingRad = bearing * (math.pi / 180.0);

        nextPositions[key] = point;
        nextBearings[key] = bearing;

        next.add(
          Marker(
            point: point,
            width: 52,
            height: 52,
            child: Align(
              alignment: Alignment.center,
              child: Transform.rotate(
                angle: bearingRad,
                child: Image.asset(
                  'assets/images/mulitita.png',
                  width: 38,
                  height: 38,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        );
      }

      if (!_alive || !mounted || rid != _runId) return;

      setState(() {
        _driverMarkers
          ..clear()
          ..addAll(next);
        _lastDriverPositions
          ..clear()
          ..addAll(nextPositions);
        _driverBearings
          ..clear()
          ..addAll(nextBearings);
      });

      _syncMarkers();

      final points = <LatLng>[];
      if (_me != null) points.add(_me!);
      points.addAll(next.map((m) => m.point));

      if (_allowAutoFit && points.length >= 2 && !_userMovedMap) {
        final b = _boundsFrom(points);
        _fitBounds(b);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final center = _me ?? _fallback;

    return Scaffold(
      appBar: AppBar(
        title: Text('Bienvenido, $_nombre'),
        leading: Builder(
          builder: (c) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(c).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.directions_bus),
            onPressed: _openTransit,
            tooltip: 'Rutas de transporte',
          ),
        ],
      ),
      drawer: const PassengerDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            PassengerSearchBar(
              controller: _searchCtl,
              loading: _loadingSugs,
              sugs: _sugs,
              onChanged: _askSug,
              onPick: (s) => _pickSug(s as PlaceSug),
            ),
            TransitSuggestionsPanel(
              loading: _loadingTransitSuggestions,
              hasChecked: _checkedTransitSuggestions,
              suggestions: _transitSuggestions,
              onOpenRoute: _openTransitSuggestion,
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.hardEdge,
                child: PassengerOsmMap(
                  controller: _mapController,
                  center: center,
                  zoom: 15,
                  markers: _markers,
                  polylines: _transitPolylines,
                  onUserGestureStart: () {
                    _userMovedMap = true;
                    _allowAutoFit = false;
                  },
                ),
              ),
            ),
            RequestRideButton(
              visible: _canRequestRide,
              onPressed: _estimarCosto,
            ),
          ],
        ),
      ),
    );
  }
}
