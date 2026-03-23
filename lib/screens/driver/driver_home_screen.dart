import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/auth_service.dart';
import '../shared/welcome_screen.dart';
import 'ride_details_screen.dart';
import 'ride_awaiting_screen.dart';
import 'ride_pickup_screen.dart';
import 'ride_inprogress_screen.dart';
import 'ride_completed_screen.dart';
import 'widgets/driver_drawer.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});
  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  static const String _api = 'https://158.23.170.129/flashride/public/api';
  static const _brand = Color(0xFFFF1B8F);
  static const LatLng _fallback = LatLng(19.7050, -101.1927);
  static const String _googleKey = 'AIzaSyAunhRNSucPlDvMPIAdah7pERRg-pJfKZw';
  static const double _alertRadiusKm = 3.0;
  static const double _markersRadiusKm = 10.0;

  bool _isLoading = true;
  int? _userId;
  Map<String, dynamic>? _profileData;
  List<Map<String, dynamic>> _assignedRides = [];

  GoogleMapController? _map;
  LatLng? _me;
  final Set<Marker> _markers = {};
  bool _hasAutoCentered = false;

  Timer? _locationTimer;
  Timer? _nearbyTimer;
  Timer? _activeWatcher;
  bool _alertOpen = false;

  final Map<String, String> _addrCache = {};
  final Map<String, double> _distCache = {};

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _map?.dispose();
    _locationTimer?.cancel();
    _nearbyTimer?.cancel();
    _activeWatcher?.cancel();
    super.dispose();
  }

  double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse('$v');
  }

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toInt();
    return int.tryParse('$v');
  }

  String _statusOrFase(Map<String, dynamic> r) {
    final status = (r['status'] ?? '').toString().toLowerCase().trim();
    final fase = (r['fase'] ?? '').toString().toLowerCase().trim();
    return status.isNotEmpty ? status : fase;
  }

  bool _isPending(Map<String, dynamic> r) {
    final st = _statusOrFase(r);
    return st.isEmpty || st == 'pending' || st == 'esperando';
  }

  bool _isActiveRide(Map<String, dynamic> r) {
    final st = _statusOrFase(r);
    return st == 'accepted' ||
        st == 'in_progress' ||
        st == 'recogiendo' ||
        st == 'viajando' ||
        st == 'esperando';
  }

  Future<void> _bootstrap() async {
    await _ensureLocationPermission();
    await _locate();
    await _loadDriverData();
    await _goToActiveRide();

    _locationTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      try {
        if (_assignedRides.isNotEmpty) {
          final rid = _asInt(_assignedRides[0]['id']);
          if (rid != null) await _enviarUbicacion(rid);
        }
        await _enviarUbicacionGlobal();
        await _locate();
      } catch (_) {}
    });

    _nearbyTimer =
        Timer.periodic(const Duration(seconds: 8), (_) => _watchNearby());

    _activeWatcher =
        Timer.periodic(const Duration(seconds: 5), (_) => _goToActiveRide());
  }

  Future<void> _ensureLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return;
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
  }

  Future<void> _locate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (!mounted) return;
        setState(() => _me = _fallback);
        return;
      }
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
      if (p == LocationPermission.denied ||
          p == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() => _me = _fallback);
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      final here = LatLng(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() {
        _me = here;
      });
      if (_map != null && _me != null && !_hasAutoCentered) {
        await _map!.animateCamera(CameraUpdate.newLatLngZoom(_me!, 15));
        _hasAutoCentered = true;
      }
      _paintMarkers();
    } catch (_) {
      if (!mounted) return;
      setState(() => _me = _fallback);
    }
  }

  void _paintMarkers({List<Map<String, dynamic>> nearby = const []}) {
    final mks = <Marker>{};

    for (final r in nearby) {
      final lat = _asDouble(r['start_lat']);
      final lng = _asDouble(r['start_lng']);
      if (lat == null || lng == null) continue;

      mks.add(Marker(
        markerId: MarkerId('ride_${r['id']}'),
        position: LatLng(lat, lng),
        infoWindow: InfoWindow(
          title: 'Solicitud #${r['id']}',
          snippet: 'Toca para ver',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        onTap: () => _showIncomingRideSheet(r),
      ));
    }

    if (!mounted) return;
    setState(() {
      _markers
        ..clear()
        ..addAll(mks);
    });
  }

  Widget _getRideScreen(Map<String, dynamic> ride) {
    final s = _statusOrFase(ride);
    switch (s) {
      case 'pending':
      case 'esperando':
        return RideAwaitingScreen(ride: ride);
      case 'accepted':
      case 'recogiendo':
        return RidePickupScreen(ride: ride);
      case 'in_progress':
      case 'viajando':
        return DriverRideInProgressScreen(ride: ride);
      case 'completed':
      case 'completado':
        return RideCompletedScreen(ride: ride);
      default:
        return RideDetailsScreen(ride: ride);
    }
  }

  Future<void> _goToActiveRide() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return;

      final res = await http.get(
        Uri.parse('$_api/rides/active'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json'
        },
      );
      if (res.statusCode != 200) return;

      final data = jsonDecode(res.body);
      if (data is Map<String, dynamic>) {
        final has = (data['status']?.toString().isNotEmpty ?? false) ||
            (data['fase']?.toString().isNotEmpty ?? false);
        if (has && mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => _getRideScreen(data)),
          );
        }
      }
    } catch (_) {}
  }

  Future<void> _enviarUbicacionGlobal() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return;

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );

      final heading = (pos.heading.isNaN) ? 0.0 : pos.heading;

      await http.post(
        Uri.parse('$_api/location/global'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'lat': pos.latitude,
          'lng': pos.longitude,
          'heading': heading,
          'bearing': heading.round(),
        }),
      );
    } catch (_) {}
  }

  Future<void> _enviarUbicacion(int rideId) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return;

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );

      final heading = (pos.heading.isNaN) ? 0.0 : pos.heading;

      await http.post(
        Uri.parse('$_api/location/update'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'ride_id': rideId,
          'driver_lat': pos.latitude,
          'driver_lng': pos.longitude,
          'heading': heading,
        }),
      );
    } catch (_) {}
  }

  Future<void> _loadDriverData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        _logout();
        return;
      }

      final profileRes = await http.get(
        Uri.parse('$_api/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json'
        },
      );

      if (profileRes.statusCode == 200) {
        final perfilJson = jsonDecode(profileRes.body) as Map<String, dynamic>;
        _userId = _asInt(perfilJson['id']);
        _profileData = perfilJson;
      } else if (profileRes.statusCode == 401) {
        _logout();
        return;
      }

      final ridesRes = await http.get(
        Uri.parse('$_api/rides'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json'
        },
      );

      List<Map<String, dynamic>> list = [];
      if (ridesRes.statusCode == 200) {
        final body = jsonDecode(ridesRes.body);
        if (body is List) {
          list = body.cast<Map<String, dynamic>>();
        } else if (body is Map<String, dynamic>) {
          list = [body];
        }
      }

      _assignedRides = list.where((r) {
        final driverId = _asInt(r['driver_id']);
        return driverId == _userId && _isActiveRide(r);
      }).toList();
    } catch (_) {
      _assignedRides = [];
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (_) => false,
    );
  }

  Future<void> _watchNearby() async {
    if (_alertOpen) return;
    try {
      final token = await AuthService.getToken();
      if (token == null) return;

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition();

      final res = await http.get(
        Uri.parse('$_api/rides/pending'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json'
        },
      );
      if (res.statusCode != 200) return;

      final decoded = jsonDecode(res.body);
      final list = decoded is List
          ? decoded
          : (decoded is Map<String, dynamic> && decoded['data'] is List)
              ? decoded['data']
              : <dynamic>[];

      Map<String, dynamic>? candidato;
      double bestDist = double.infinity;
      final nearbyMarkers = <Map<String, dynamic>>[];

      for (final raw in list) {
        if (raw is! Map) continue;
        final r = raw.cast<String, dynamic>();

        final driverId = _asInt(r['driver_id']);
        if (driverId != null) continue;

        if (!_isPending(r)) continue;

        final lat = _asDouble(r['start_lat']);
        final lng = _asDouble(r['start_lng']);
        if (lat == null || lng == null) continue;

        final d = _haversineKm(pos.latitude, pos.longitude, lat, lng);

        if (d <= _markersRadiusKm) {
          nearbyMarkers.add(r);
        }

        if (d < bestDist && d <= _alertRadiusKm) {
          bestDist = d;
          candidato = r;
        }
      }

      _paintMarkers(nearby: nearbyMarkers);

      if (candidato != null) {
        _showIncomingRideSheet(candidato);
      }
    } catch (_) {}
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = (lat2 - lat1) * (pi / 180.0);
    final dLon = (lon2 - lon1) * (pi / 180.0);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (pi / 180.0)) *
            cos(lat2 * (pi / 180.0)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  String _kLatLng(LatLng p) =>
      '${p.latitude.toStringAsFixed(5)},${p.longitude.toStringAsFixed(5)}';

  Future<String> _reverseGeocode(LatLng p) async {
    final key = _kLatLng(p);
    final cached = _addrCache[key];
    if (cached != null) return cached;

    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?latlng=${p.latitude},${p.longitude}'
        '&key=$_googleKey'
        '&language=es'
        '&region=mx',
      );

      final res = await http.get(uri);
      if (res.statusCode != 200) {
        final fallback = '${p.latitude}, ${p.longitude}';
        _addrCache[key] = fallback;
        return fallback;
      }

      final j = jsonDecode(res.body);
      final results = j['results'];
      if (results is! List || results.isEmpty) {
        final fallback = '${p.latitude}, ${p.longitude}';
        _addrCache[key] = fallback;
        return fallback;
      }

      final first = results.first;
      final comps = first['address_components'];

      String route = '';
      String streetNumber = '';
      String neighborhood = '';
      String locality = '';
      String admin1 = '';

      if (comps is List) {
        for (final c in comps) {
          if (c is! Map) continue;
          final types = (c['types'] as List?)?.cast<String>() ?? const [];
          final longName = (c['long_name'] ?? '').toString();

          if (types.contains('route')) route = longName;
          if (types.contains('street_number')) streetNumber = longName;

          if (types.contains('sublocality') ||
              types.contains('sublocality_level_1') ||
              types.contains('neighborhood')) {
            if (neighborhood.isEmpty) neighborhood = longName;
          }

          if (types.contains('locality')) locality = longName;
          if (types.contains('administrative_area_level_1')) admin1 = longName;
        }
      }

      final parts = <String>[];
      final street = [
        route.isNotEmpty ? route : null,
        streetNumber.isNotEmpty ? streetNumber : null,
      ].whereType<String>().join(' ');

      if (street.isNotEmpty) parts.add(street);
      if (neighborhood.isNotEmpty) parts.add(neighborhood);
      if (locality.isNotEmpty) parts.add(locality);
      if (admin1.isNotEmpty) parts.add(admin1);

      String out = parts.join(', ');
      if (out.trim().isEmpty) {
        out = (first['formatted_address'] ?? '${p.latitude}, ${p.longitude}')
            .toString();
      }

      _addrCache[key] = out;
      return out;
    } catch (_) {
      final fallback = '${p.latitude}, ${p.longitude}';
      _addrCache[key] = fallback;
      return fallback;
    }
  }

  Future<double?> _drivingDistanceKm(LatLng a, LatLng b) async {
    final key = '${_kLatLng(a)}|${_kLatLng(b)}';
    final cached = _distCache[key];
    if (cached != null) return cached;

    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${a.latitude},${a.longitude}'
        '&destination=${b.latitude},${b.longitude}'
        '&key=$_googleKey'
        '&language=es'
        '&region=mx',
      );

      final res = await http.get(uri);
      if (res.statusCode != 200) return null;

      final j = jsonDecode(res.body);
      if ((j['status'] ?? '') != 'OK') return null;

      final routes = j['routes'];
      if (routes is! List || routes.isEmpty) return null;

      final legs = routes[0]['legs'];
      if (legs is! List || legs.isEmpty) return null;

      final dist = legs[0]['distance'];
      final meters = (dist is Map) ? dist['value'] : null;
      if (meters is! num) return null;

      final km = meters.toDouble() / 1000.0;
      _distCache[key] = km;
      return km;
    } catch (_) {
      return null;
    }
  }

  Future<_RideSheetInfo> _buildRideSheetInfo(Map<String, dynamic> ride) async {
    final slat = _asDouble(ride['start_lat']);
    final slng = _asDouble(ride['start_lng']);
    final elat = _asDouble(ride['end_lat']);
    final elng = _asDouble(ride['end_lng']);

    final startPos = (slat != null && slng != null) ? LatLng(slat, slng) : null;
    final endPos = (elat != null && elng != null) ? LatLng(elat, elng) : null;

    LatLng meNow = _me ?? _fallback;
    try {
      if (_me == null && await Geolocator.isLocationServiceEnabled()) {
        final pos = await Geolocator.getCurrentPosition();
        meNow = LatLng(pos.latitude, pos.longitude);
      }
    } catch (_) {}

    final startAddr = startPos != null ? await _reverseGeocode(startPos) : '—';
    final endAddr = endPos != null ? await _reverseGeocode(endPos) : '—';

    double? kmToPickup;
    double? kmTrip;

    if (startPos != null) {
      kmToPickup = await _drivingDistanceKm(meNow, startPos);
      kmToPickup ??= _haversineKm(
        meNow.latitude,
        meNow.longitude,
        startPos.latitude,
        startPos.longitude,
      );
    }

    if (startPos != null && endPos != null) {
      kmTrip = await _drivingDistanceKm(startPos, endPos);
      kmTrip ??= _haversineKm(
        startPos.latitude,
        startPos.longitude,
        endPos.latitude,
        endPos.longitude,
      );
    }

    return _RideSheetInfo(
      startAddr: startAddr,
      endAddr: endAddr,
      kmToPickup: kmToPickup,
      kmTrip: kmTrip,
    );
  }

  void _showIncomingRideSheet(Map<String, dynamic> ride) {
    _alertOpen = true;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      builder: (_) {
        final est = ride['estimated_cost']?.toString() ?? '—';

        return Padding(
          padding: const EdgeInsets.all(16),
          child: FutureBuilder<_RideSheetInfo>(
            future: _buildRideSheetInfo(ride),
            builder: (context, snap) {
              final loading = snap.connectionState != ConnectionState.done;

              final startAddr = snap.data?.startAddr ?? 'Cargando dirección…';
              final endAddr = snap.data?.endAddr ?? 'Cargando dirección…';

              final kmToPickup = snap.data?.kmToPickup;
              final kmTrip = snap.data?.kmTrip;

              final km1 = loading
                  ? '…'
                  : (kmToPickup == null ? '—' : kmToPickup.toStringAsFixed(2));
              final km2 = loading
                  ? '…'
                  : (kmTrip == null ? '—' : kmTrip.toStringAsFixed(2));

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nueva solicitud cercana',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('Origen: $startAddr'),
                  Text('Destino: $endAddr'),
                  const SizedBox(height: 6),
                  Text('Distancia a pasajero: $km1 km'),
                  Text('Distancia del viaje: $km2 km'),
                  const SizedBox(height: 6),
                  Text('Estimado: \$$est'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _alertOpen = false;
                          },
                          child: const Text('Rechazar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final accepted = await _aceptarRide(ride['id']);
                            if (!mounted) return;
                            Navigator.pop(context);
                            _alertOpen = false;
                            if (accepted) {
                              await _goToActiveRide();
                              if (mounted && _assignedRides.isEmpty) {
                                await _loadDriverData();
                                if (_assignedRides.isNotEmpty) {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          _getRideScreen(_assignedRides[0]),
                                    ),
                                  );
                                }
                              }
                            }
                          },
                          child: const Text('Aceptar'),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    ).whenComplete(() => _alertOpen = false);
  }

  Future<bool> _aceptarRide(dynamic rideIdRaw) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return false;
      final rideId = _asInt(rideIdRaw);
      if (rideId == null) return false;
      final r = await http.post(
        Uri.parse('$_api/rides/$rideId/accept'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json'
        },
      );
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mapWidget = Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.hardEdge,
      child: GoogleMap(
        onMapCreated: (c) {
          _map = c;
          if (_me != null && !_hasAutoCentered) {
            _map!.moveCamera(CameraUpdate.newLatLngZoom(_me!, 15));
            _hasAutoCentered = true;
          }
        },
        initialCameraPosition: CameraPosition(
          target: _me ?? _fallback,
          zoom: 15,
        ),
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        zoomControlsEnabled: false,
        markers: _markers,
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bienvenido, Chofer'),
        backgroundColor: _brand,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: DriverDrawer(
        brandColor: _brand,
        profileData: _profileData,
        onLogout: _logout,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(child: mapWidget),
                  if (_assignedRides.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'No hay viajes activos por atender.',
                        style: TextStyle(fontSize: 16),
                      ),
                    )
                  else
                    FutureBuilder(
                      future: Future.delayed(Duration.zero, () {
                        if (!mounted) return;
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _getRideScreen(_assignedRides[0]),
                          ),
                        );
                      }),
                      builder: (context, snapshot) => const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _RideSheetInfo {
  final String startAddr;
  final String endAddr;
  final double? kmToPickup;
  final double? kmTrip;

  _RideSheetInfo({
    required this.startAddr,
    required this.endAddr,
    required this.kmToPickup,
    required this.kmTrip,
  });
}
