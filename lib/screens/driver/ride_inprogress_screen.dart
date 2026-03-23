import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../../services/auth_service.dart';

class DriverRideInProgressScreen extends StatefulWidget {
  final Map<String, dynamic> ride;
  const DriverRideInProgressScreen({super.key, required this.ride});

  @override
  State<DriverRideInProgressScreen> createState() =>
      _DriverRideInProgressScreenState();
}

class _DriverRideInProgressScreenState
    extends State<DriverRideInProgressScreen> {
  GoogleMapController? _mapController;
  LatLng? _myPos;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  Timer? _timer;

  static const _api = "https://158.23.170.129/flashride/public/api";

  @override
  void initState() {
    super.initState();
    _loadRoute();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) async {
      await _updateDriverLocation();
      await _loadRoute();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _updateDriverLocation() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return;

      final pos = await Geolocator.getCurrentPosition();
      _myPos = LatLng(pos.latitude, pos.longitude);

      final r = await http.post(
        Uri.parse("$_api/location/update"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode({
          "ride_id": widget.ride['id'],
          "driver_lat": pos.latitude,
          "driver_lng": pos.longitude,
        }),
      );
      if (r.statusCode != 200) {
        debugPrint("❌ Error enviando ubicación: ${r.statusCode}");
      }
    } catch (e) {
      debugPrint("🚨 _updateDriverLocation: $e");
    }
  }

  Future<void> _loadRoute() async {
    if (_myPos == null) return;

    final endLat = double.tryParse(widget.ride['end_lat'].toString()) ?? 0.0;
    final endLng = double.tryParse(widget.ride['end_lng'].toString()) ?? 0.0;

    final origin = "${_myPos!.latitude},${_myPos!.longitude}";
    final destination = "$endLat,$endLng";

    final url =
        "https://maps.googleapis.com/maps/api/directions/json?origin=$origin&destination=$destination&key=AIzaSyAunhRNSucPlDvMPIAdah7pERRg-pJfKZw";

    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200) return;

      final data = jsonDecode(res.body);
      if (data['status'] != 'OK') return;

      final points = data['routes'][0]['overview_polyline']['points'];
      final polyline = _decodePolyline(points);

      // SOLO marcador de destino (rojo por defecto). Nada de marcador del chofer.
      setState(() {
        _markers = {
          Marker(
            markerId: const MarkerId('destino'),
            position: LatLng(endLat, endLng),
            infoWindow: const InfoWindow(title: 'Destino'),
          ),
        };
        _polylines = {
          Polyline(
            polylineId: const PolylineId('viaje'),
            points: polyline,
            width: 5,
            color: Colors.blue,
          ),
        };
      });

      _fitBounds(LatLng(endLat, endLng));
    } catch (e) {
      debugPrint("❌ _loadRoute: $e");
    }
  }

  void _fitBounds(LatLng destino) {
    if (_mapController == null || _myPos == null) return;

    final sw = LatLng(
      (_myPos!.latitude < destino.latitude)
          ? _myPos!.latitude
          : destino.latitude,
      (_myPos!.longitude < destino.longitude)
          ? _myPos!.longitude
          : destino.longitude,
    );
    final ne = LatLng(
      (_myPos!.latitude > destino.latitude)
          ? _myPos!.latitude
          : destino.latitude,
      (_myPos!.longitude > destino.longitude)
          ? _myPos!.longitude
          : destino.longitude,
    );

    final bounds = LatLngBounds(southwest: sw, northeast: ne);
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
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

  Future<void> _finishRide() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return;

      final url = Uri.parse("$_api/rides/${widget.ride['id']}/complete");
      final res = await http.post(url, headers: {
        "Authorization": "Bearer $token",
        "Accept": "application/json",
      });

      if (res.statusCode == 200) {
        _timer?.cancel();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Viaje finalizado')),
        );
        Navigator.pushReplacementNamed(context, '/driver_home');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error al finalizar: ${res.statusCode}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e')),
      );
    }
  }

  Future<void> _panic() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return;

      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition();
      } catch (_) {}

      final res = await http.post(
        Uri.parse("$_api/panic"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode({
          "ride_id": widget.ride['id'],
          if (pos != null) "lat": pos.latitude,
          if (pos != null) "lng": pos.longitude,
        }),
      );

      if (!mounted) return;
      if (res.statusCode == 200 ||
          res.statusCode == 201 ||
          res.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🚨 Alerta enviada')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🚨 Alerta local activada')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🚨 Alerta local activada')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Viaje en progreso (Conductor)")),
      body: _myPos == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition:
                      CameraPosition(target: _myPos!, zoom: 15),
                  onMapCreated: (c) => _mapController = c,
                  markers: _markers, // ← solo destino
                  polylines: _polylines, // ← ruta
                  myLocationEnabled: true, // ← puntito azul del sistema
                  myLocationButtonEnabled: true,
                ),
                Positioned(
                  bottom: 20,
                  left: 16,
                  right: 16,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      FloatingActionButton.extended(
                        heroTag: 'panic',
                        backgroundColor: Colors.red,
                        icon: const Icon(Icons.warning_amber),
                        label: const Text('Pánico'),
                        onPressed: _panic,
                      ),
                      FloatingActionButton.extended(
                        heroTag: 'finish',
                        backgroundColor: Colors.green,
                        icon: const Icon(Icons.flag),
                        label: const Text('Terminar'),
                        onPressed: _finishRide,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
