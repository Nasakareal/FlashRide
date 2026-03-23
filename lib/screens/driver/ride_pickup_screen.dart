import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

import '../../services/auth_service.dart';
import 'ride_inprogress_screen.dart';

class RidePickupScreen extends StatefulWidget {
  final Map<String, dynamic> ride;
  const RidePickupScreen({super.key, required this.ride});

  @override
  State<RidePickupScreen> createState() => _RidePickupScreenState();
}

class _RidePickupScreenState extends State<RidePickupScreen> {
  GoogleMapController? _mapController;
  LatLng? _myPos;
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  DateTime _lastCam = DateTime.fromMillisecondsSinceEpoch(0);

  static const _api = 'https://158.23.170.129/flashride/public/api';

  StreamSubscription<Position>? _posSub;
  bool _sending = false;

  int get _rideId => int.tryParse(widget.ride['id']?.toString() ?? '') ?? 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      await _ensureLocationReady();

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _myPos = LatLng(pos.latitude, pos.longitude);

      // pinta ruta inicial a pickup
      await _loadRouteToPickup();

      // ✅ empieza a trackear y ENVIAR ubicación al backend
      _startTrackingAndSend();
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de ubicación: $e')),
      );
    }
  }

  Future<void> _ensureLocationReady() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Activa el GPS del teléfono.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception('Permiso de ubicación denegado.');
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Permiso denegado permanentemente. Actívalo en ajustes.');
    }
  }

  void _startTrackingAndSend() {
    _posSub?.cancel();

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // manda si te moviste ~5m
    );

    _posSub = Geolocator.getPositionStream(locationSettings: settings).listen(
      (pos) async {
        final here = LatLng(pos.latitude, pos.longitude);
        _myPos = here;
        if (mounted) setState(() {});

        // Ajusta cámara suave (sin spam)
        _maybeMoveCamera(here);

        // ✅ manda ubicación del ride
        await _sendRideLocation(here);

        // (opcional) manda ubicación global del driver (users.lat/lng)
        // await _sendGlobalLocation(here);
      },
      onError: (e) {
        debugPrint('Position stream error: $e');
      },
    );
  }

  void _maybeMoveCamera(LatLng here) {
    if (_mapController == null) return;
    if (DateTime.now().difference(_lastCam).inMilliseconds < 900) return;
    _mapController!.animateCamera(CameraUpdate.newLatLng(here));
    _lastCam = DateTime.now();
  }

  Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    if (token == null) {
      throw Exception('Sin token. Vuelve a iniciar sesión.');
    }
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  Future<void> _sendRideLocation(LatLng here) async {
    if (_rideId == 0) return;
    if (_sending) return;

    _sending = true;
    try {
      final res = await http.post(
        Uri.parse('$_api/location/update'),
        headers: await _headers(),
        body: jsonEncode({
          'ride_id': _rideId,
          'driver_lat': here.latitude,
          'driver_lng': here.longitude,
        }),
      );

      if (res.statusCode != 200) {
        debugPrint('❌ location/update ${res.statusCode}: ${res.body}');
      } else {
        debugPrint('✅ ride location updated');
      }
    } catch (e) {
      debugPrint('❌ sendRideLocation error: $e');
    } finally {
      _sending = false;
    }
  }

  Future<void> _sendGlobalLocation(LatLng here) async {
    try {
      final res = await http.post(
        Uri.parse('$_api/location/global'),
        headers: await _headers(),
        body: jsonEncode({
          'lat': here.latitude,
          'lng': here.longitude,
        }),
      );

      if (res.statusCode != 200) {
        debugPrint('❌ location/global ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      debugPrint('❌ sendGlobalLocation error: $e');
    }
  }

  Future<void> _loadRouteToPickup() async {
    // 2) destino = punto de abordaje (NO el destino final)
    final pickupLat =
        double.tryParse(widget.ride['start_lat'].toString()) ?? 0.0;
    final pickupLng =
        double.tryParse(widget.ride['start_lng'].toString()) ?? 0.0;

    if (_myPos == null) return;

    final origin = '${_myPos!.latitude},${_myPos!.longitude}';
    final destination = '$pickupLat,$pickupLng';

    final url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=$origin&destination=$destination&key=AIzaSyAunhRNSucPlDvMPIAdah7pERRg-pJfKZw';

    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');

    final data = jsonDecode(res.body);
    if (data['status'] != 'OK') throw Exception('GMaps: ${data["status"]}');

    final points = data['routes'][0]['overview_polyline']['points'];
    final polyline = _decodePolyline(points);

    if (!mounted) return;
    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('pickup'),
          position: LatLng(pickupLat, pickupLng),
          infoWindow: const InfoWindow(title: 'Punto de abordaje'),
        ),
      };
      _polylines = {
        Polyline(
          polylineId: const PolylineId('a_pickup'),
          points: polyline,
          width: 5,
        ),
      };
    });

    _fitBounds(_myPos!, LatLng(pickupLat, pickupLng));
  }

  void _fitBounds(LatLng a, LatLng b) {
    if (_mapController == null) return;
    if (DateTime.now().difference(_lastCam).inMilliseconds < 900) return;

    final sw = LatLng(
      a.latitude < b.latitude ? a.latitude : b.latitude,
      a.longitude < b.longitude ? a.longitude : b.longitude,
    );
    final ne = LatLng(
      a.latitude > b.latitude ? a.latitude : b.latitude,
      a.longitude > b.longitude ? a.longitude : b.longitude,
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: sw, northeast: ne),
        80,
      ),
    );
    _lastCam = DateTime.now();
  }

  Future<void> _startTrip() async {
    try {
      final rideId = widget.ride['id'];
      final res = await http.post(
        Uri.parse('$_api/rides/$rideId/fase'),
        headers: await _headers(),
        body: jsonEncode({'fase': 'viajando'}),
      );

      if (res.statusCode == 200) {
        final updated = jsonDecode(res.body)['data'] ?? widget.ride;
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DriverRideInProgressScreen(ride: updated),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('No se pudo iniciar el viaje (${res.statusCode})')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0, lat = 0, lng = 0;
    while (index < encoded.length) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;
      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recogiendo al pasajero')),
      body: _myPos == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition:
                      CameraPosition(target: _myPos!, zoom: 14),
                  onMapCreated: (c) => _mapController = c,
                  markers: _markers,
                  polylines: _polylines,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                ),
                Positioned(
                  bottom: 20,
                  left: 16,
                  right: 16,
                  child: ElevatedButton.icon(
                    onPressed: _startTrip,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Iniciar viaje'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
