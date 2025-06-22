import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class RideDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> ride;
  const RideDetailsScreen({super.key, required this.ride});

  @override
  State<RideDetailsScreen> createState() => _RideDetailsScreenState();
}

class _RideDetailsScreenState extends State<RideDetailsScreen> {
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
    final endLat = double.tryParse(widget.ride['end_lat'].toString()) ?? 0.0;
    final endLng = double.tryParse(widget.ride['end_lng'].toString()) ?? 0.0;

    final pos = await Geolocator.getCurrentPosition();
    _myPos = LatLng(pos.latitude, pos.longitude);

    final origin = '${pos.latitude},${pos.longitude}';
    final destination = '$endLat,$endLng';

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
            markerId: const MarkerId('origin'),
            position: _myPos!,
            infoWindow: const InfoWindow(title: 'Tú'),
          ),
          Marker(
            markerId: const MarkerId('destination'),
            position: LatLng(endLat, endLng),
            infoWindow: const InfoWindow(title: 'Destino'),
          ),
        };
        _polylines = {
          Polyline(
            polylineId: const PolylineId('route'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ruta del viaje')),
      body: _myPos == null
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
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
    );
  }
}
