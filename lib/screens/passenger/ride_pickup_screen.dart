import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class PassengerPickupScreen extends StatefulWidget {
  final Map<String, dynamic> ride;
  const PassengerPickupScreen({super.key, required this.ride});

  @override
  State<PassengerPickupScreen> createState() => _PassengerPickupScreenState();
}

class _PassengerPickupScreenState extends State<PassengerPickupScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  LatLng? _driverPos;

  @override
  void initState() {
    super.initState();
    _loadDriverLocationAndRoute();
  }

  Future<void> _loadDriverLocationAndRoute() async {
    try {
      final response = await http.get(
        Uri.parse(
            'http://158.23.170.129/api/rides/${widget.ride['id']}/driver'),
        headers: {
          'Authorization':
              'Bearer ${widget.ride['token']}', // token ya debe estar incluido en ride
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Error ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      final driverLat = double.tryParse(data['lat'].toString());
      final driverLng = double.tryParse(data['lng'].toString());

      if (driverLat == null || driverLng == null)
        throw Exception('Coordenadas inválidas');

      _driverPos = LatLng(driverLat, driverLng);
      final origin = '$driverLat,$driverLng';
      final destination =
          '${widget.ride['start_lat']},${widget.ride['start_lng']}';

      final directionsUrl =
          'https://maps.googleapis.com/maps/api/directions/json?origin=$origin&destination=$destination&key=AIzaSyAunhRNSucPlDvMPIAdah7pERRg-pJfKZw';

      final dirRes = await http.get(Uri.parse(directionsUrl));
      final dirData = jsonDecode(dirRes.body);

      if (dirData['status'] != 'OK')
        throw Exception('Dirección fallida: ${dirData['status']}');

      final points = dirData['routes'][0]['overview_polyline']['points'];
      final polyline = _decodePolyline(points);

      setState(() {
        _markers = {
          Marker(
            markerId: const MarkerId('driver'),
            position: _driverPos!,
            infoWindow: const InfoWindow(title: 'Conductor'),
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure),
          ),
          Marker(
            markerId: const MarkerId('pasajero'),
            position: LatLng(
              double.parse(widget.ride['start_lat'].toString()),
              double.parse(widget.ride['start_lng'].toString()),
            ),
            infoWindow: const InfoWindow(title: 'Tú'),
          ),
        };

        _polylines = {
          Polyline(
            polylineId: const PolylineId('ruta'),
            points: polyline,
            width: 5,
            color: Colors.blueAccent,
          ),
        };
      });
    } catch (e) {
      debugPrint('❌ Error cargando ruta: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar ruta del conductor: $e')),
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
      appBar: AppBar(title: const Text('Tu conductor va en camino')),
      body: _driverPos == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _driverPos!,
                      zoom: 14,
                    ),
                    onMapCreated: (controller) => _mapController = controller,
                    markers: _markers,
                    polylines: _polylines,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Tu conductor se dirige a tu ubicación.\nPrepárate para abordarlo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
    );
  }
}
