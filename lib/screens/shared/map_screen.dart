import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  final TextEditingController _searchController = TextEditingController();
  LatLng? _destination;
  final Set<Marker> _markers = {};

  // Posiciones simuladas de “carritos”
  final List<LatLng> _carPositions = [
    LatLng(19.7060, -101.1910),
    LatLng(19.7030, -101.1950),
    LatLng(19.7070, -101.1940),
  ];

  static final LatLng _fallbackPosition = LatLng(19.7050, -101.1927);

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _currentPosition = _fallbackPosition);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _currentPosition = _fallbackPosition);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() => _currentPosition = _fallbackPosition);
        return;
      }

      final pos = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = LatLng(pos.latitude, pos.longitude);
        _setupMarkers();
      });
    } catch (_) {
      setState(() => _currentPosition = _fallbackPosition);
    }
  }

  Future<void> _searchAndNavigate() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    const apiKey = 'AIzaSyDVmv1Gb4zNaZQsP1jPVw5IdevWH5brTaY';
    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(query)}&key=$apiKey');

    final resp = await http.get(url);
    final data = json.decode(resp.body);
    if (data['status'] == 'OK') {
      final loc = data['results'][0]['geometry']['location'];
      final newPos = LatLng(loc['lat'], loc['lng']);
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(newPos, 15));
      setState(() {
        _destination = newPos;
        _setupMarkers();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dirección no encontrada')),
      );
    }
  }

  void _setupMarkers() {
    _markers.clear();
    if (_currentPosition != null) {
      _markers.add(Marker(
        markerId: const MarkerId('user'),
        position: _currentPosition!,
        infoWindow: const InfoWindow(title: 'Tú estás aquí'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ));
    }
    for (var i = 0; i < _carPositions.length; i++) {
      _markers.add(Marker(
        markerId: MarkerId('car_$i'),
        position: _carPositions[i],
        infoWindow: InfoWindow(title: 'Carrito $i'),
      ));
    }
    if (_destination != null) {
      _markers.add(Marker(
        markerId: const MarkerId('dest'),
        position: _destination!,
        infoWindow: const InfoWindow(title: 'Destino'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ));
    }
  }

  void _requestRide() {
    if (_destination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una dirección primero')),
      );
      return;
    }
    // TODO: Llamar a tu backend Laravel pasando _destination.latitude/lng
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Viaje solicitado a: $_destination')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _currentPosition == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  onMapCreated: (c) {
                    _mapController = c;
                    _setupMarkers();
                  },
                  initialCameraPosition: CameraPosition(
                    target: _currentPosition!,
                    zoom: 15,
                  ),
                  myLocationEnabled: true,
                  markers: _markers,
                ),
                Positioned(
                  top: 40,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 4)
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              hintText: 'Buscar dirección...',
                              border: InputBorder.none,
                            ),
                            onSubmitted: (_) => _searchAndNavigate(),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: _searchAndNavigate,
                        )
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 24,
                  left: 50,
                  right: 50,
                  child: ElevatedButton(
                    onPressed: _requestRide,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24)),
                      backgroundColor: Colors.green[700],
                    ),
                    child: const Text('Solicitar viaje aquí'),
                  ),
                ),
              ],
            ),
    );
  }
}
