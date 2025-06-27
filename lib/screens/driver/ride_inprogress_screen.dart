import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../../services/auth_service.dart';

class RideInProgressScreen extends StatefulWidget {
  final Map<String, dynamic> ride;
  const RideInProgressScreen({super.key, required this.ride});

  @override
  State<RideInProgressScreen> createState() => _RideInProgressScreenState();
}

class _RideInProgressScreenState extends State<RideInProgressScreen> {
  GoogleMapController? _mapController;
  LatLng? _myPos;
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  late final Timer _recalcTimer;

  @override
  void initState() {
    super.initState();
    _loadRoute();
    _recalcTimer = Timer.periodic(Duration(seconds: 10), (_) => _loadRoute());
  }

  @override
  void dispose() {
    _recalcTimer.cancel();
    super.dispose();
  }

  Future<void> _loadRoute() async {
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
            markerId: const MarkerId('yo'),
            position: _myPos!,
            infoWindow: const InfoWindow(title: 'Tú'),
          ),
          Marker(
            markerId: const MarkerId('destino'),
            position: LatLng(endLat, endLng),
            infoWindow: const InfoWindow(title: 'Destino final'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Viaje en progreso')),
      body: Stack(
        children: [
          _myPos == null
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
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'btn-problema',
                  icon: Icon(Icons.report_problem),
                  label: Text('Problema'),
                  backgroundColor: Colors.orange,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('🛠️ Problema reportado (simbólico)')),
                    );
                  },
                ),
                FloatingActionButton.extended(
                    heroTag: 'btn-finalizar',
                    icon: Icon(Icons.flag),
                    label: Text('Terminar'),
                    backgroundColor: Colors.green,
                    onPressed: () async {
                      final token = await AuthService.getToken();
                      if (token == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  '❌ Sesión expirada. Por favor inicia sesión.')),
                        );
                        return;
                      }

                      final url = Uri.parse(
                          'http://158.23.170.129/api/rides/${widget.ride['id']}/complete');

                      try {
                        final response = await http.post(
                          url,
                          headers: {
                            'Authorization': 'Bearer $token',
                            'Accept': 'application/json',
                          },
                        );

                        if (response.statusCode == 200) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content:
                                    Text('✅ Viaje finalizado exitosamente')),
                          );
                          Navigator.pushReplacementNamed(
                              context, '/driver_home');
                        } else {
                          throw Exception(
                              'Error ${response.statusCode}: ${response.body}');
                        }
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('❌ Error al finalizar: $e')),
                        );
                      }
                    }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
