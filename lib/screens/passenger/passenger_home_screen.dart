import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../shared/welcome_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PassengerHomeScreen extends StatefulWidget {
  const PassengerHomeScreen({super.key});

  @override
  State<PassengerHomeScreen> createState() => _PassengerHomeScreenState();
}

class _PassengerHomeScreenState extends State<PassengerHomeScreen> {
  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  final TextEditingController _searchController = TextEditingController();
  LatLng? _destination;
  final Set<Marker> _markers = {};

  final List<LatLng> _carPositions = [
    LatLng(19.7060, -101.1910),
    LatLng(19.7030, -101.1950),
    LatLng(19.7070, -101.1940),
  ];

  static final LatLng _fallback = LatLng(19.7050, -101.1927);

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        setState(() => _currentPosition = _fallback);
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) {
          return setState(() => _currentPosition = _fallback);
        }
      }
      if (perm == LocationPermission.deniedForever) {
        return setState(() => _currentPosition = _fallback);
      }
      final p = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = LatLng(p.latitude, p.longitude);
        _setupMarkers();
      });
    } catch (_) {
      setState(() => _currentPosition = _fallback);
    }
  }

  Future<void> _searchAndNavigate() async {
    final q = _searchController.text.trim();
    if (q.isEmpty) return;
    const key = 'AIzaSyDVmv1Gb4zNaZQsP1jPVw5IdevWH5brTaY';
    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(q)}&key=$key');
    final r = await http.get(url);
    final data = json.decode(r.body);
    if (data['status'] == 'OK') {
      final loc = data['results'][0]['geometry']['location'];
      final pos = LatLng(loc['lat'], loc['lng']);
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(pos, 15));
      setState(() {
        _destination = pos;
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
        markerId: const MarkerId('you'),
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

  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (r) => false,
    );
  }

  void _requestRide() {
    if (_destination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un destino primero')),
      );
      return;
    }
    // LLAMA AQUÍ A TU BACKEND PASÁNDOLE _destination.latitude/lng
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Viaje solicitado a $_destination')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bienvenido, Pasajero'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
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
                  top: 16,
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
                              hintText: 'Buscar dirección…',
                              border: InputBorder.none,
                            ),
                            onSubmitted: (_) => _searchAndNavigate(),
                          ),
                        ),
                        IconButton(
                            icon: const Icon(Icons.search),
                            onPressed: _searchAndNavigate),
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
                      backgroundColor: Colors.green[700],
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24)),
                    ),
                    child: const Text('Solicitar viaje aquí'),
                  ),
                ),
              ],
            ),
    );
  }
}
