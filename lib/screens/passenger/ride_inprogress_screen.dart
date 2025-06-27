import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:geolocator/geolocator.dart';

class RideInProgressScreen extends StatefulWidget {
  final Map<String, dynamic> ride;
  const RideInProgressScreen({super.key, required this.ride});

  @override
  State<RideInProgressScreen> createState() => _RideInProgressScreenState();
}

class _RideInProgressScreenState extends State<RideInProgressScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  LatLng? _myLocation;
  late final Timer _posTimer;

  @override
  void initState() {
    super.initState();
    _loadRoute();
    _startTracking();
    _checkRideCompletion();
  }

  Future<void> _loadRoute() async {
    final startLat =
        double.tryParse(widget.ride['start_lat'].toString()) ?? 0.0;
    final startLng =
        double.tryParse(widget.ride['start_lng'].toString()) ?? 0.0;
    final endLat = double.tryParse(widget.ride['end_lat'].toString()) ?? 0.0;
    final endLng = double.tryParse(widget.ride['end_lng'].toString()) ?? 0.0;

    final origin = '$startLat,$startLng';
    final destination = '$endLat,$endLng';

    final url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=$origin&destination=$destination&key=AIzaSyAunhRNSucPlDvMPIAdah7pERRg-pJfKZw';

    try {
      final res = await http.get(Uri.parse(url));

      if (res.statusCode != 200) throw Exception('Error ${res.statusCode}');

      final data = jsonDecode(res.body);
      if (data['status'] != 'OK')
        throw Exception('Google Maps error: ${data['status']}');

      final points = data['routes'][0]['overview_polyline']['points'];
      final polyline = _decodePolyline(points);

      setState(() {
        _markers = {
          Marker(
            markerId: const MarkerId('origen'),
            position: LatLng(startLat, startLng),
            infoWindow: const InfoWindow(title: 'Origen'),
          ),
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
            color: Colors.green,
          ),
        };
      });
    } catch (e) {
      debugPrint('❌ Error cargando ruta: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar ruta: $e')),
      );
    }
  }

  void _startTracking() {
    _posTimer = Timer.periodic(Duration(seconds: 5), (_) async {
      try {
        final pos = await Geolocator.getCurrentPosition();
        final me = LatLng(pos.latitude, pos.longitude);
        _myLocation = me;

        _mapController?.animateCamera(CameraUpdate.newLatLng(me));

        if (_myLocation != null) {
          _loadRouteFromCurrent();
        }
      } catch (e) {
        debugPrint('❌ Error obteniendo ubicación: $e');
      }
    });
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

  Future<void> _loadRouteFromCurrent() async {
    final endLat = double.tryParse(widget.ride['end_lat'].toString()) ?? 0.0;
    final endLng = double.tryParse(widget.ride['end_lng'].toString()) ?? 0.0;

    final origin = '${_myLocation!.latitude},${_myLocation!.longitude}';
    final destination = '$endLat,$endLng';

    final url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=$origin&destination=$destination&key=AIzaSyAunhRNSucPlDvMPIAdah7pERRg-pJfKZw';

    try {
      final res = await http.get(Uri.parse(url));

      if (res.statusCode != 200) throw Exception('Error ${res.statusCode}');
      final data = jsonDecode(res.body);
      if (data['status'] != 'OK') throw Exception(data['status']);

      final points = data['routes'][0]['overview_polyline']['points'];
      final polyline = _decodePolyline(points);

      setState(() {
        _polylines = {
          Polyline(
            polylineId: const PolylineId('viaje'),
            points: polyline,
            width: 5,
            color: Colors.green,
          ),
        };
      });
    } catch (e) {
      debugPrint('❌ Error recalculando ruta: $e');
    }
  }

  // ⬇️ AQUÍ PEGA ESTO ABAJO DEL ANTERIOR

  void _checkRideCompletion() {
    Timer.periodic(Duration(seconds: 10), (timer) async {
      try {
        final rideId = widget.ride['id'];
        final url = Uri.parse('http://158.23.170.129/api/rides/$rideId');
        final res = await http.get(url);

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data['status'] == 'completed') {
            timer.cancel(); // Detenemos el temporizador
            if (!mounted) return;

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✅ ¡Viaje finalizado!')),
            );

            await Future.delayed(const Duration(seconds: 1));
            Navigator.pushReplacementNamed(context, '/passenger_home');
          }
        } else {
          debugPrint('❌ Error verificando viaje: ${res.statusCode}');
        }
      } catch (e) {
        debugPrint('❌ Error en _checkRideCompletion: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Viaje en curso')),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(
                  double.tryParse(widget.ride['start_lat'].toString()) ??
                      19.7050,
                  double.tryParse(widget.ride['start_lng'].toString()) ??
                      -101.1927,
                ),
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
              'Estás en camino a tu destino.\nDisfruta tu viaje.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FloatingActionButton.extended(
                heroTag: 'btn1',
                icon: Icon(Icons.share),
                label: Text('Compartir'),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Compartir viaje (simbólico)')),
                  );
                },
              ),
              FloatingActionButton.extended(
                heroTag: 'btn2',
                backgroundColor: Colors.red,
                icon: Icon(Icons.warning_amber),
                label: Text('Pánico'),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('⚠️ Alerta enviada al C5i (simbólica)')),
                  );
                },
              ),
            ],
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _posTimer.cancel();
    super.dispose();
  }
}
