import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../../services/auth_service.dart';

class RideAwaitingScreen extends StatefulWidget {
  final Map<String, dynamic> ride;
  const RideAwaitingScreen({super.key, required this.ride});

  @override
  State<RideAwaitingScreen> createState() => _RideAwaitingScreenState();
}

class _RideAwaitingScreenState extends State<RideAwaitingScreen> {
  GoogleMapController? _mapController;
  LatLng? _myPos;
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _loadRoute();
  }

  Future<void> _loadRoute() async {
    final startLat =
        double.tryParse(widget.ride['start_lat'].toString()) ?? 0.0;
    final startLng =
        double.tryParse(widget.ride['start_lng'].toString()) ?? 0.0;

    final pos = await Geolocator.getCurrentPosition();
    _myPos = LatLng(pos.latitude, pos.longitude);

    final origin = '${pos.latitude},${pos.longitude}';
    final destination = '$startLat,$startLng';

    final url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=$origin&destination=$destination&key=AIzaSyAunhRNSucPlDvMPIAdah7pERRg-pJfKZw';

    try {
      final res = await http.get(Uri.parse(url));

      if (res.statusCode != 200) {
        throw Exception('Error ${res.statusCode}');
      }

      final data = jsonDecode(res.body);

      if (data['status'] != 'OK') {
        throw Exception('Google Maps API error: ${data['status']}');
      }

      final points = data['routes'][0]['overview_polyline']['points'];
      final polyline = _decodePolyline(points);

      setState(() {
        _markers = {
          Marker(
            markerId: const MarkerId('yo'),
            position: _myPos!,
            infoWindow: const InfoWindow(title: 'Tú'),
          ),
          Marker(
            markerId: const MarkerId('origen'),
            position: LatLng(startLat, startLng),
            infoWindow: const InfoWindow(title: 'Pasajero'),
          ),
        };
        _polylines = {
          Polyline(
            polylineId: const PolylineId('ruta'),
            points: polyline,
            width: 5,
          ),
        };
      });
    } catch (e) {
      debugPrint('❌ Falló al cargar ruta: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar ruta: $e')),
        );
      }
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }

  Future<void> _confirmarRecogida() async {
    final rideId = widget.ride['id'];
    final url = Uri.parse('http://158.23.170.129/api/rides/$rideId/fase');

    try {
      final token = await AuthService.getToken(); // ← OBLIGATORIO
      final res = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', // ← AQUÍ estaba el problema
        },
        body: jsonEncode({'fase': 'viajando'}),
      );

      if (res.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pasajero marcado como recogido.')),
        );
        Navigator.pushReplacementNamed(context, '/driver_home');
      } else {
        throw Exception('Error ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      debugPrint('❌ Error al cambiar fase: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('En camino al pasajero')),
      body: _myPos == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _myPos!,
                      zoom: 14,
                    ),
                    onMapCreated: (controller) => _mapController = controller,
                    markers: _markers,
                    polylines: _polylines,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton.icon(
                    onPressed: _confirmarRecogida,
                    icon: const Icon(Icons.directions_car),
                    label: const Text('Pasajero recogido'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
