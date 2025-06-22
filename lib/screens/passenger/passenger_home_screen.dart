// ------------- imports -------------
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../shared/welcome_screen.dart';

// ------------ constantes ------------
const _apiKey = 'AIzaSyAunhRNSucPlDvMPIAdah7pERRg-pJfKZw';
const _fallback = LatLng(19.7050, -101.1927);

// ------------ modelo simple ------------
class _Sug {
  final String id, desc;
  _Sug(this.id, this.desc);
}

class PassengerHomeScreen extends StatefulWidget {
  const PassengerHomeScreen({super.key});
  @override
  State<PassengerHomeScreen> createState() => _State();
}

class _State extends State<PassengerHomeScreen> {
  /* ---------- estado ---------- */
  GoogleMapController? _map;
  LatLng? _me, _dest;
  final _markers = <Marker>{};
  final _searchCtl = TextEditingController();
  final _sugs = <_Sug>[];
  bool _loadingSugs = false;

  BitmapDescriptor? _taxiIcon;

  /* ---------- ciclo ---------- */
  late final Timer _timerConductores;

  @override
  void initState() {
    super.initState();

    _loadTaxiIcon() // ① Carga el ícono con Size(48,48)
        .then((_) {
      _locate().then((_) => _cargarConductoresCercanos());
      _timerConductores = Timer.periodic(
        const Duration(seconds: 10),
        (_) => _cargarConductoresCercanos(),
      );
    });
  }

  @override
  void dispose() {
    _timerConductores.cancel();
    _map?.dispose();
    _searchCtl.dispose();
    super.dispose();
  }

  /* ---------- GPS ---------- */
  Future<void> _locate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return setState(() => _me = _fallback);
      }

      var p = await Geolocator.checkPermission();

      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }

      if (p == LocationPermission.denied ||
          p == LocationPermission.deniedForever) {
        return setState(() => _me = _fallback);
      }

      final pos = await Geolocator.getCurrentPosition();

      setState(() {
        _me = LatLng(pos.latitude, pos.longitude);
        _paint();
      });
    } catch (_) {
      setState(() => _me = _fallback);
    }
  }

  /* ---------- Autocomplete ---------- */
  Future<void> _askSug(String txt) async {
    if (txt.isEmpty) return setState(() => _sugs.clear());
    setState(() => _loadingSugs = true);
    final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=${Uri.encodeComponent(txt)}&key=$_apiKey&language=es&components=country:mx');
    final r = await http.get(uri);
    final j = json.decode(r.body);
    setState(() {
      _loadingSugs = false;
      _sugs
        ..clear()
        ..addAll((j['predictions'] as List).map(
            (e) => _Sug(e['place_id'] as String, e['description'] as String)));
    });
  }

  Future<void> _pickSug(_Sug s) async {
    _searchCtl.text = s.desc;
    _sugs.clear();
    final r = await http
        .get(Uri.parse('https://maps.googleapis.com/maps/api/place/details/json'
            '?place_id=${s.id}&key=$_apiKey&fields=geometry'));
    final loc = json.decode(r.body)['result']['geometry']['location'];
    final pos = LatLng(loc['lat'], loc['lng']);
    _map?.animateCamera(CameraUpdate.newLatLngZoom(pos, 15));
    setState(() {
      _dest = pos;
      _paint();
    });
  }

  /* ---------- markers ---------- */
  void _paint() {
    _markers.removeWhere((m) => m.markerId.value == 'dest');

    if (_dest != null) {
      _markers.add(Marker(
        markerId: const MarkerId('dest'),
        position: _dest!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ));
    }
  }

  Future<void> _solicitarViaje() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    debugPrint('🧪 TOKEN USADO PARA RIDE => $token');

    if (_me == null || _dest == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ubicación actual o destino no definido.'),
        ),
      );
      return;
    }

    final response = await http.post(
      Uri.parse('http://158.23.170.129/api/rides'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'start_lat': _me!.latitude,
        'start_lng': _me!.longitude,
        'end_lat': _dest!.latitude,
        'end_lng': _dest!.longitude,
      }),
    );

    if (!mounted) return;

    if (response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Viaje solicitado con éxito')),
      );
    } else {
      debugPrint('❌ ERROR => ${response.statusCode} / ${response.body}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al solicitar viaje: ${response.body}')),
      );
    }
  }

  /* ---------- UI ---------- */
  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Bienvenido, Pasajero'),
          leading: Builder(
              builder: (c) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(c).openDrawer()))),
      drawer: Drawer(
          child: ListView(padding: EdgeInsets.zero, children: [
        const DrawerHeader(
            decoration: BoxDecoration(color: Colors.green),
            child: Text('Menú',
                style: TextStyle(color: Colors.white, fontSize: 24))),
        ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Cerrar sesión'),
            onTap: () async {
              final p = await SharedPreferences.getInstance();
              await p.clear();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                  (_) => false);
            }),
      ])),
      body: SafeArea(
          child: Column(children: [
        /* buscador + lista */
        Padding(
            padding: const EdgeInsets.all(8),
            child: Column(children: [
              TextField(
                  controller: _searchCtl,
                  decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Buscar dirección…',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8))),
                  onChanged: _askSug),
              if (_loadingSugs) const LinearProgressIndicator(minHeight: 2),
              ..._sugs.map((s) => ListTile(
                  dense: true,
                  title: Text(s.desc, overflow: TextOverflow.ellipsis),
                  onTap: () => _pickSug(s)))
            ])),
        /* mapa */
        Expanded(
            child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8)),
                clipBehavior: Clip.hardEdge,
                child: GoogleMap(
                    onMapCreated: (c) {
                      _map = c;
                      _paint();
                    },
                    initialCameraPosition:
                        CameraPosition(target: _me ?? _fallback, zoom: 15),
                    myLocationEnabled: true,
                    zoomControlsEnabled: false,
                    markers: _markers))),
        /* botón */
        Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                    onPressed: _solicitarViaje,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24))),
                    child: const Text('Solicitar viaje aquí'))))
      ])),
    );
  }

  Future<void> _loadTaxiIcon() async {
    _taxiIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/images/taxi32.png',
    );
    if (mounted) setState(() {});
  }

  Future<void> _cargarConductoresCercanos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final res = await http.get(
        Uri.parse('http://158.23.170.129/api/drivers/nearby'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode != 200) return;

      final data = jsonDecode(res.body) as List;

      // <-- Aquí es donde metes el nuevosDrivers
      final nuevosDrivers = data
          .map((d) {
            final lat = double.tryParse(d['lat'].toString());
            final lng = double.tryParse(d['lng'].toString());
            if (lat == null || lng == null) return null;
            return Marker(
              markerId: MarkerId('driver_${d['id']}'),
              position: LatLng(lat, lng),
              icon: _taxiIcon ??
                  BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueOrange),
              infoWindow: InfoWindow(title: 'Unidad: ${d['name']}'),
            );
          })
          .whereType<Marker>()
          .toSet();

      if (!mounted) return;
      setState(() {
        // 1) quito todos los viejos
        _markers.removeWhere((m) => m.markerId.value.startsWith('driver_'));
        // 2) añado los nuevos
        _markers.addAll(nuevosDrivers);
        // 3) (opcional) tu destino
        if (_dest != null) {
          _markers.removeWhere((m) => m.markerId.value == 'dest');
          _markers.add(Marker(
            markerId: const MarkerId('dest'),
            position: _dest!,
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueGreen),
          ));
        }
      });
    } catch (e) {
      debugPrint('❌ Error cargando conductores: $e');
    }
  }

  LatLngBounds _getBoundsFromMarkers(Set<Marker> markers) {
    final latitudes = markers.map((m) => m.position.latitude);
    final longitudes = markers.map((m) => m.position.longitude);

    return LatLngBounds(
      southwest: LatLng(latitudes.reduce((a, b) => a < b ? a : b),
          longitudes.reduce((a, b) => a < b ? a : b)),
      northeast: LatLng(latitudes.reduce((a, b) => a > b ? a : b),
          longitudes.reduce((a, b) => a > b ? a : b)),
    );
  }
}

/* helpers */
extension _SetExt<E> on Set<E> {
  void addIf(bool cond, E Function() build) {
    if (cond) add(build());
  }
}
