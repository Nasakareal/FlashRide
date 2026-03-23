import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class TransitRouteSuggestion {
  final int routeId;
  final String shortName;
  final String longName;
  final String vehicleType;
  final String description;
  final String colorHex;
  final double distanceMeters;
  final List<LatLng> polylinePoints;

  const TransitRouteSuggestion({
    required this.routeId,
    required this.shortName,
    required this.longName,
    required this.vehicleType,
    required this.description,
    required this.colorHex,
    required this.distanceMeters,
    required this.polylinePoints,
  });

  String get title {
    if (shortName.isNotEmpty) return 'Ruta $shortName';
    if (longName.isNotEmpty) return longName;
    return 'Ruta sugerida';
  }

  String get subtitle {
    final parts = <String>[];
    if (longName.isNotEmpty) parts.add(longName);
    if (vehicleType.isNotEmpty) parts.add(vehicleType);
    if (description.isNotEmpty) parts.add(description);
    return parts.join(' · ');
  }
}

class TransitService {
  static const String _base = 'https://158.23.170.129/flashride/public/api';
  static const double _nearThresholdMeters = 300;
  static const double _fallbackThresholdMeters = 700;
  static const double _maxSuggestedDistanceMeters = 1200;
  static const Distance _distance = Distance();

  List<dynamic>? _routesCache;
  final Map<int, Map<String, dynamic>> _routeCache =
      <int, Map<String, dynamic>>{};

  Map<String, String> get _headers => const {
        'Accept': 'application/json',
      };

  Uri _u(String path) {
    final b =
        _base.endsWith('/') ? _base.substring(0, _base.length - 1) : _base;
    final p = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$b$p');
  }

  Future<List<dynamic>> fetchRoutes({bool forceRefresh = false}) async {
    if (!forceRefresh && _routesCache != null) {
      return _routesCache!;
    }

    final r = await http
        .get(_u('/transit/routes'), headers: _headers)
        .timeout(const Duration(seconds: 12));
    if (r.statusCode != 200) {
      throw Exception('HTTP ${r.statusCode}: ${r.body}');
    }
    final j = jsonDecode(r.body);
    if (j is! List) throw Exception('payload inválido (routes)');

    _routesCache = List<dynamic>.from(j);
    return _routesCache!;
  }

  Future<Map<String, dynamic>> fetchRoute(
    int id, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _routeCache.containsKey(id)) {
      return _routeCache[id]!;
    }

    final r = await http
        .get(_u('/transit/routes/$id'), headers: _headers)
        .timeout(const Duration(seconds: 12));
    if (r.statusCode != 200) {
      throw Exception('HTTP ${r.statusCode}: ${r.body}');
    }
    final j = jsonDecode(r.body);
    if (j is! Map<String, dynamic>) throw Exception('payload inválido (route)');

    _routeCache[id] = j;
    return j;
  }

  Future<List<dynamic>> fetchVehicles({int? transitRouteId}) async {
    final Uri url = (transitRouteId == null)
        ? _u('/transit/vehicles')
        : _u('/transit/routes/$transitRouteId/vehicles');

    final r = await http
        .get(url, headers: _headers)
        .timeout(const Duration(seconds: 12));
    if (r.statusCode != 200) {
      throw Exception('HTTP ${r.statusCode}: ${r.body}');
    }
    final j = jsonDecode(r.body);
    if (j is! List) throw Exception('payload inválido (vehicles)');
    return j;
  }

  Future<List<TransitRouteSuggestion>> suggestRoutesForDestination({
    required LatLng destination,
    int limit = 2,
  }) async {
    final rawRoutes = await fetchRoutes();

    final suggestions = (await Future.wait(
      rawRoutes.whereType<Map>().map((rawRoute) async {
        final routeBase = _mapFrom(rawRoute);
        final routeId = _toInt(routeBase['id']);
        if (routeId == null) return null;

        Map<String, dynamic> routeData = routeBase;
        if (!_hasGeometry(routeData)) {
          try {
            routeData = {
              ...routeBase,
              ...await fetchRoute(routeId),
            };
          } catch (_) {
            return null;
          }
        }

        final polylinePoints = _extractPolylinePoints(routeData);
        final stopPoints = _extractStopPoints(routeData);
        final minDistance = _minimumDistanceMeters(
          point: destination,
          polylinePoints: polylinePoints,
          stopPoints: stopPoints,
        );

        if (minDistance == null || minDistance > _maxSuggestedDistanceMeters) {
          return null;
        }

        return TransitRouteSuggestion(
          routeId: routeId,
          shortName: (routeData['short_name'] ?? '').toString().trim(),
          longName: (routeData['long_name'] ?? '').toString().trim(),
          vehicleType: (routeData['vehicle_type'] ?? '').toString().trim(),
          description: (routeData['description'] ?? '').toString().trim(),
          colorHex: _normalizedColor(
            (routeData['color'] ?? '1A73E8').toString(),
          ),
          distanceMeters: minDistance,
          polylinePoints: polylinePoints,
        );
      }),
    ))
        .whereType<TransitRouteSuggestion>()
        .toList()
      ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));

    final veryNear = suggestions
        .where((item) => item.distanceMeters <= _nearThresholdMeters)
        .take(limit)
        .toList();

    if (veryNear.length >= limit) {
      return veryNear;
    }

    final near = suggestions
        .where((item) =>
            item.distanceMeters > _nearThresholdMeters &&
            item.distanceMeters <= _fallbackThresholdMeters)
        .take(limit - veryNear.length)
        .toList();

    return [...veryNear, ...near];
  }

  bool _hasGeometry(Map<String, dynamic> routeData) {
    final polyline = (routeData['polyline'] ?? '').toString().trim();
    if (polyline.isNotEmpty) return true;

    final rawStops = routeData['stops'] ?? routeData['stops_json'];
    if (rawStops is List && rawStops.isNotEmpty) return true;
    if (rawStops is String && rawStops.trim().isNotEmpty) return true;
    return false;
  }

  Map<String, dynamic> _mapFrom(Map raw) {
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  String _normalizedColor(String raw) {
    final value = raw.trim().replaceAll('#', '');
    if (value.isEmpty) return '1A73E8';
    if (value.length == 6) return value.toUpperCase();
    if (value.length == 8) return value.substring(2).toUpperCase();
    return '1A73E8';
  }

  List<LatLng> _extractPolylinePoints(Map<String, dynamic> routeData) {
    final encoded = (routeData['polyline'] ?? '').toString().trim();
    if (encoded.isEmpty) return const <LatLng>[];

    try {
      return PolylinePoints.decodePolyline(encoded)
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList();
    } catch (_) {
      return const <LatLng>[];
    }
  }

  List<LatLng> _extractStopPoints(Map<String, dynamic> routeData) {
    final rawStops = routeData['stops'] ?? routeData['stops_json'];
    List<dynamic> parsedStops = const <dynamic>[];

    if (rawStops is List) {
      parsedStops = rawStops;
    } else if (rawStops is String && rawStops.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawStops);
        if (decoded is List) parsedStops = decoded;
      } catch (_) {}
    }

    return parsedStops
        .whereType<Map>()
        .map((stop) {
          final lat = _toDouble(
            stop['lat'] ?? stop['latitude'] ?? stop['stop_lat'],
          );
          final lng = _toDouble(
            stop['lng'] ?? stop['longitude'] ?? stop['stop_lng'],
          );
          if (lat == null || lng == null) return null;
          return LatLng(lat, lng);
        })
        .whereType<LatLng>()
        .toList();
  }

  double? _minimumDistanceMeters({
    required LatLng point,
    required List<LatLng> polylinePoints,
    required List<LatLng> stopPoints,
  }) {
    double? best;

    void check(double candidate) {
      if (best == null || candidate < best!) {
        best = candidate;
      }
    }

    for (final stop in stopPoints) {
      check(_distance.as(LengthUnit.Meter, point, stop));
    }

    if (polylinePoints.length == 1) {
      check(_distance.as(LengthUnit.Meter, point, polylinePoints.first));
      return best;
    }

    for (var i = 0; i < polylinePoints.length - 1; i++) {
      check(
        _distanceToSegmentMeters(
          point,
          polylinePoints[i],
          polylinePoints[i + 1],
        ),
      );
    }

    return best;
  }

  double _distanceToSegmentMeters(LatLng point, LatLng start, LatLng end) {
    final referenceLat = (point.latitude + start.latitude + end.latitude) / 3;
    const metersPerLat = 111320.0;
    final metersPerLng = 111320.0 * math.cos(referenceLat * math.pi / 180.0);

    final px = (point.longitude - start.longitude) * metersPerLng;
    final py = (point.latitude - start.latitude) * metersPerLat;
    final sx = (end.longitude - start.longitude) * metersPerLng;
    final sy = (end.latitude - start.latitude) * metersPerLat;

    final segLenSquared = (sx * sx) + (sy * sy);
    if (segLenSquared == 0) {
      return math.sqrt((px * px) + (py * py));
    }

    final t = ((px * sx) + (py * sy)) / segLenSquared;
    final clamped = t.clamp(0.0, 1.0).toDouble();
    final dx = px - (sx * clamped);
    final dy = py - (sy * clamped);
    return math.sqrt((dx * dx) + (dy * dy));
  }
}
