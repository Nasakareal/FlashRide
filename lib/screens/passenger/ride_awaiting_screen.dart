import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';
import 'ride_inprogress_screen.dart';
import 'ride_completed_screen.dart';
import 'ride_pickup_screen.dart';

class PassengerAwaitingScreen extends StatefulWidget {
  final Map<String, dynamic>
      ride; // Debe incluir: id, start_lat, start_lng, fase
  const PassengerAwaitingScreen({super.key, required this.ride});

  @override
  State<PassengerAwaitingScreen> createState() =>
      _PassengerAwaitingScreenState();
}

class _PassengerAwaitingScreenState extends State<PassengerAwaitingScreen> {
  static final String _API = AuthService.baseUrl;
  static const Color _appBarColor = Color(0xFFFF1B8F);

  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  Timer? _pollTimer;
  int _notFoundCount = 0;
  DateTime _lastCameraMove = DateTime.fromMillisecondsSinceEpoch(0);

  late final double _startLat;
  late final double _startLng;

  LatLng? _driverPos;
  String _fase = 'esperando';

  @override
  void initState() {
    super.initState();

    _startLat =
        double.tryParse(widget.ride['start_lat']?.toString() ?? '') ?? 0.0;
    _startLng =
        double.tryParse(widget.ride['start_lng']?.toString() ?? '') ?? 0.0;
    _fase = (widget.ride['fase'] ?? 'esperando').toString();

    final dLat = double.tryParse(widget.ride['driver_lat']?.toString() ?? '');
    final dLng = double.tryParse(widget.ride['driver_lng']?.toString() ?? '');
    if (dLat != null && dLng != null) {
      _driverPos = LatLng(dLat, dLng);
    }

    _paintBase();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pickup = LatLng(_startLat, _startLng);
    final hasDriver = _driverPos != null || _fase == 'recogiendo';

    return Scaffold(
      appBar: AppBar(
        title: Text(
            hasDriver ? 'Tu conductor va en camino' : 'Buscando conductor…'),
        backgroundColor: _appBarColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: pickup, zoom: 15),
              onMapCreated: (c) {
                _mapController = c;
                _fitCamera(pickup, _driverPos);
              },
              markers: _markers,
              polylines: _polylines,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: true,
              compassEnabled: true,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _cancelRide,
                    icon: const Icon(Icons.cancel),
                    label: const Text('Cancelar viaje'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      side: const BorderSide(color: _appBarColor, width: 1.4),
                      foregroundColor: _appBarColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _paintBase() {
    final pickup = LatLng(_startLat, _startLng);
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('pickup'),
        position: pickup,
        infoWindow: const InfoWindow(title: 'Punto de abordaje'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ),
    };

    if (_driverPos != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: _driverPos!,
          infoWindow: const InfoWindow(title: 'Conductor'),
          icon: BitmapDescriptor.defaultMarker,
        ),
      );
    }

    setState(() => _markers = markers);

    if (_mapController != null) {
      _fitCamera(pickup, _driverPos);
    }
  }

  void _fitCamera(LatLng pickup, LatLng? driver) {
    if (_mapController == null) return;
    if (DateTime.now().difference(_lastCameraMove).inMilliseconds < 900) return;

    if (driver == null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
            CameraPosition(target: pickup, zoom: 15)),
      );
    } else {
      final southWest = LatLng(
        pickup.latitude < driver.latitude ? pickup.latitude : driver.latitude,
        pickup.longitude < driver.longitude
            ? pickup.longitude
            : driver.longitude,
      );
      final northEast = LatLng(
        pickup.latitude > driver.latitude ? pickup.latitude : driver.latitude,
        pickup.longitude > driver.longitude
            ? pickup.longitude
            : driver.longitude,
      );

      final bounds = LatLngBounds(southwest: southWest, northeast: northEast);
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
    }
    _lastCameraMove = DateTime.now();
  }

  void _startPolling() {
    _refreshRide();
    _pollTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _refreshRide());
  }

  bool _movedEnough(LatLng a, LatLng b) {
    final dLat = (a.latitude - b.latitude).abs();
    final dLng = (a.longitude - b.longitude).abs();
    return (dLat > 0.00025) || (dLng > 0.00025);
  }

  Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
  }

  Future<void> _refreshRide() async {
    final rideId = widget.ride['id'];
    if (rideId == null) return;

    try {
      final res = await http.get(Uri.parse('$_API/rides/$rideId'),
          headers: await _headers());

      if (res.statusCode == 404) {
        _notFoundCount++;
        if (_notFoundCount >= 2) {
          _pollTimer?.cancel();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('El viaje ya no existe.')),
          );
          Navigator.pop(context);
        }
        return;
      }

      if (res.statusCode != 200) {
        debugPrint('❌ GET /rides/$rideId => ${res.statusCode}');
        return;
      }

      _notFoundCount = 0;
      final data = jsonDecode(res.body);

      final newFase = (data['fase'] ?? '').toString();
      if (newFase.isNotEmpty && newFase != _fase) {
        _fase = newFase;
      }

      // Si el backend ya asignó conductor, puede mandar sus coords
      final dLat = double.tryParse(data['driver_lat']?.toString() ?? '');
      final dLng = double.tryParse(data['driver_lng']?.toString() ?? '');
      final newDriver =
          (dLat != null && dLng != null) ? LatLng(dLat, dLng) : null;

      if (newDriver != null) {
        if (_driverPos == null || _movedEnough(_driverPos!, newDriver)) {
          _driverPos = newDriver;
          _paintBase();
        }
      }

      // TRANSICIONES de fase
      if (!mounted) return;
      switch (_fase) {
        case 'recogiendo':
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (_) => PassengerPickupScreen(ride: data)));
          break;
        case 'viajando':
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (_) => PassengerRideInProgressScreen(ride: data)));
          break;
        case 'completado':
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (_) => RideCompletedScreen(ride: data)));
          break;
        case 'cancelado':
          _pollTimer?.cancel();
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('El viaje fue cancelado.')));
          Navigator.pop(context);
          break;
        default:
          // 'esperando': se queda aquí
          setState(() {}); // refresca título si cambió
      }
    } catch (e) {
      debugPrint('❌ Poll error: $e');
    }
  }

  Future<void> _cancelRide() async {
    final rideId = widget.ride['id'];
    if (rideId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancelar viaje'),
        content: const Text('¿Seguro que deseas cancelar este viaje?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sí, cancelar')),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await http.post(Uri.parse('$_API/rides/$rideId/cancel'),
          headers: await _headers());
      if (res.statusCode == 200 || res.statusCode == 204) {
        _pollTimer?.cancel();
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Viaje cancelado.')));
        Navigator.pop(context);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('No se pudo cancelar (${res.statusCode}).')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No se pudo cancelar: $e')));
    }
  }
}
