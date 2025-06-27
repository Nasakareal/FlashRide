import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RideDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> ride;
  const RideDetailsScreen({super.key, required this.ride});

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
      appBar: AppBar(title: const Text('Detalles del viaje')),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: origen, zoom: 13),
              markers: markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Este viaje está en estado desconocido.\nRevisa con soporte si esto persiste.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.redAccent),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Volver'),
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
