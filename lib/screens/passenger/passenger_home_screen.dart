// ------------- imports -------------
import 'dart:convert';
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

  /* ---------- ciclo ---------- */
  @override
  void initState() {
    super.initState();
    _locate();
  }

  @override
  void dispose() {
    _map?.dispose();
    _searchCtl.dispose();
    super.dispose();
  }

  /* ---------- GPS ---------- */
  Future<void> _locate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled())
        return setState(() => _me = _fallback);
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied)
        p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied ||
          p == LocationPermission.deniedForever)
        return setState(() => _me = _fallback);
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
    _markers
      ..clear()
      ..addIf(
          _me != null,
          () => Marker(
              markerId: const MarkerId('me'),
              position: _me!,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueAzure)))
      ..addIf(
          _dest != null,
          () => Marker(
              markerId: const MarkerId('dest'),
              position: _dest!,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen)));
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
                    onPressed: () {
                      if (_dest == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Selecciona un destino primero')));
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Viaje solicitado a $_dest')));
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24))),
                    child: const Text('Solicitar viaje aquí'))))
      ])),
    );
  }
}

/* helpers */
extension _SetExt<E> on Set<E> {
  void addIf(bool cond, E Function() build) {
    if (cond) add(build());
  }
}
