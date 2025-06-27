import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RideCompletedScreen extends StatelessWidget {
  final Map<String, dynamic> ride;
  const RideCompletedScreen({super.key, required this.ride});

  @override
  Widget build(BuildContext context) {
    final startLat = double.tryParse(ride['start_lat'].toString()) ?? 0.0;
    final startLng = double.tryParse(ride['start_lng'].toString()) ?? 0.0;
    final endLat = double.tryParse(ride['end_lat'].toString()) ?? 0.0;
    final endLng = double.tryParse(ride['end_lng'].toString()) ?? 0.0;

    final origen = LatLng(startLat, startLng);
    final destino = LatLng(endLat, endLng);

    final Set<Marker> markers = {
      Marker(
        markerId: const MarkerId('origen'),
        position: origen,
        infoWindow: const InfoWindow(title: 'Origen'),
      ),
      Marker(
        markerId: const MarkerId('destino'),
        position: destino,
        infoWindow: const InfoWindow(title: 'Destino'),
      ),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Viaje completado')),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: destino, zoom: 14),
              markers: markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Tu viaje ha finalizado exitosamente.\nGracias por usar FlashRide.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/passenger_home',
                  (_) => false,
                );
              },
              icon: const Icon(Icons.home),
              label: const Text('Volver al inicio'),
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
