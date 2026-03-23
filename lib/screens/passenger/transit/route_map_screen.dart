import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui; // para redimensionar la imagen
import 'package:flutter/services.dart' show rootBundle; // para leer assets
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

import '../../../services/transit_service.dart';

class TransitRouteMapScreen extends StatefulWidget {
  final int routeId;
  final String title;
  const TransitRouteMapScreen({
    super.key,
    required this.routeId,
    required this.title,
  });

  @override
  State<TransitRouteMapScreen> createState() => _TransitRouteMapScreenState();
}

class _TransitRouteMapScreenState extends State<TransitRouteMapScreen> {
  static const int _BUS_ICON_PX = 56; // tamaño del ícono
  static const bool _SHOW_STOPS = false;

  final _svc = TransitService();

  GoogleMapController? _map;
  final Set<Marker> _markers = {};
  final Set<Polyline> _lines = {};

  Timer? _timer;
  bool _mapReady = false;
  bool _didFit = false;
  int _vehHash = 0;

  String? _err;
  String _emptyMsg = '';

  BitmapDescriptor? _busIcon;

  @override
  void initState() {
    super.initState();
    _loadBusIcon().then((_) => _init());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ---- Carga y redimensiona el PNG a un ancho fijo (px) ----
  Future<BitmapDescriptor> _bitmapFromAsset(
    String path,
    int targetWidthPx,
  ) async {
    final data = await rootBundle.load(path);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: targetWidthPx,
    );
    final frame = await codec.getNextFrame();
    final bytes =
        (await frame.image.toByteData(format: ui.ImageByteFormat.png))!
            .buffer
            .asUint8List();
    return BitmapDescriptor.fromBytes(bytes);
  }

  Future<void> _loadBusIcon() async {
    try {
      _busIcon = await _bitmapFromAsset('assets/images/van.png', _BUS_ICON_PX);
    } catch (_) {
      _busIcon =
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
    }
    if (mounted) setState(() {});
  }

  // ---------- Helpers de parseo tolerantes ----------
  double? _toD(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  int? _toI(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }
  // ---------------------------------------------------

  Color _fromHex(String hex) {
    hex = hex.trim().replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse('0x$hex'));
  }

  Future<void> _init() async {
    try {
      if (!mounted) return;
      setState(() {
        _markers.clear();
        _lines.clear();
        _emptyMsg = '';
        _err = null;
      });

      final data = await _svc.fetchRoute(widget.routeId);

      // ---- Polyline ----
      final poly = (data['polyline'] ?? '').toString();
      if (poly.isNotEmpty) {
        // ✅ FIX: decodePolyline es static en tu versión instalada
        final pts = PolylinePoints.decodePolyline(poly);

        final coords = pts.map((p) => LatLng(p.latitude, p.longitude)).toList();
        final colorHex = (data['color'] ?? '7A7A7A').toString();

        _lines.add(
          Polyline(
            polylineId: const PolylineId('route'),
            width: 5,
            color: _fromHex(colorHex),
            points: coords,
            geodesic: true,
          ),
        );

        if (mounted) setState(() {});

        if (coords.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (_map != null && !_didFit) {
              _didFit = true;
              await Future.delayed(const Duration(milliseconds: 150));
              _map?.animateCamera(
                CameraUpdate.newLatLngBounds(_bounds(coords), 48),
              );
            }
          });
        }
      }

      // ---- Paradas (opcional) ----
      if (_SHOW_STOPS) {
        final dynamic rawStops = data['stops'] ?? data['stops_json'];
        List<dynamic> stops = const [];
        try {
          if (rawStops is String && rawStops.trim().isNotEmpty) {
            stops = (jsonDecode(rawStops) as List);
          } else if (rawStops is List) {
            stops = rawStops;
          }
        } catch (_) {
          stops = const [];
        }

        for (final s in stops) {
          if (s is! Map) continue;

          final id =
              s['id'] != null ? s['id'].toString() : UniqueKey().toString();
          final lat = _toD(s['lat']);
          final lng = _toD(s['lng']);
          if (lat == null || lng == null) continue;

          _markers.add(
            Marker(
              markerId: MarkerId('stop_$id'),
              position: LatLng(lat, lng),
              infoWindow: InfoWindow(title: (s['name'] ?? 'Parada').toString()),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure,
              ),
            ),
          );
        }
      }

      if (mounted) setState(() {});

      await _refreshVehicles();

      _timer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => _refreshVehicles(),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = e.toString();
      });
    }
  }

  Future<void> _refreshVehicles() async {
    try {
      if (!_mapReady || !mounted) return;

      final v = await _svc.fetchVehicles(transitRouteId: widget.routeId);
      debugPrint('route ${widget.routeId} vehicles: ${v.length}');

      final nextMarkers = Set<Marker>.from(
        _markers.where(
          (m) => _SHOW_STOPS && m.markerId.value.startsWith('stop_'),
        ),
      );

      int hasher = 0;

      for (final it in v) {
        final id = (it['id']).toString();
        final lat = _toD(it['last_lat']);
        final lng = _toD(it['last_lng']);
        final brg = _toI(it['last_bearing']) ?? 0;
        if (lat == null || lng == null) continue;

        hasher = hasher * 31 ^
            id.hashCode ^
            lat.hashCode ^
            lng.hashCode ^
            brg.hashCode;

        nextMarkers.add(
          Marker(
            markerId: MarkerId('veh_$id'),
            position: LatLng(lat, lng),
            infoWindow: InfoWindow(title: 'Unidad $id'),
            rotation: brg.toDouble(),
            flat: true,
            anchor: const Offset(0.5, 0.5),
            icon: _busIcon ??
                BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueViolet,
                ),
            zIndex: 10.0,
          ),
        );
      }

      final nextEmpty = v.isEmpty ? 'Sin unidades activas en esta ruta.' : '';

      if (hasher != _vehHash || nextEmpty != _emptyMsg) {
        _vehHash = hasher;
        if (!mounted) return;
        setState(() {
          _emptyMsg = nextEmpty;
          _markers
            ..clear()
            ..addAll(nextMarkers);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = e.toString();
      });
    }
  }

  LatLngBounds _bounds(List<LatLng> pts) {
    double minLat = pts.first.latitude, maxLat = pts.first.latitude;
    double minLng = pts.first.longitude, maxLng = pts.first.longitude;
    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(19.7008, -101.1844),
              zoom: 12,
            ),
            onMapCreated: (c) {
              _map = c;
              _mapReady = true;
              _refreshVehicles();
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            markers: _markers,
            polylines: _lines,
          ),
          if (_err != null)
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _err!,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          if (_emptyMsg.isNotEmpty)
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _emptyMsg,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
