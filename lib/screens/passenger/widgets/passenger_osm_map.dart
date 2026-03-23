import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class PassengerOsmMap extends StatelessWidget {
  final MapController controller;
  final LatLng center;
  final double zoom;
  final List<Marker> markers;
  final List<Polyline> polylines;
  final VoidCallback? onUserGestureStart;

  const PassengerOsmMap({
    super.key,
    required this.controller,
    required this.center,
    required this.zoom,
    required this.markers,
    this.polylines = const <Polyline>[],
    this.onUserGestureStart,
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom,
        interactionOptions:
            const InteractionOptions(flags: InteractiveFlag.all),
        onPointerDown: (_, __) => onUserGestureStart?.call(),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'flashride_app',
        ),
        if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
        MarkerLayer(markers: markers),
      ],
    );
  }
}
