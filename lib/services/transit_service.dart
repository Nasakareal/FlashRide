import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'auth_service.dart';

class TransitRateLimitException implements Exception {
  final String resource;
  final Duration? retryAfter;

  const TransitRateLimitException({
    required this.resource,
    this.retryAfter,
  });

  String get message {
    final seconds = retryAfter?.inSeconds;
    if (seconds != null && seconds > 0) {
      return 'Demasiadas consultas para $resource. Intenta de nuevo en $seconds s.';
    }
    return 'Demasiadas consultas para $resource. Intenta de nuevo en unos segundos.';
  }

  @override
  String toString() => message;
}

String transitFriendlyError(Object error) {
  if (error is TransitRateLimitException) {
    return error.message;
  }
  return error.toString();
}

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
  static final String _base = AuthService.baseUrl;
  static const double _nearThresholdMeters = 300;
  static const double _fallbackThresholdMeters = 700;
  static const double _maxSuggestedDistanceMeters = 1200;
  static const Distance _distance = Distance();
  static const Duration _routesTtl = Duration(minutes: 5);
  static const Duration _routeTtl = Duration(minutes: 10);
  static const Duration _vehiclesTtl = Duration(seconds: 12);
  static const Duration _defaultBackoff = Duration(seconds: 30);

  static List<dynamic>? _routesCache;
  static DateTime? _routesCacheAt;
  static Future<List<dynamic>>? _routesInFlight;

  static final Map<int, Map<String, dynamic>> _routeCache =
      <int, Map<String, dynamic>>{};
  static final Map<int, DateTime> _routeCacheAt = <int, DateTime>{};
  static final Map<int, Future<Map<String, dynamic>>> _routeInFlight =
      <int, Future<Map<String, dynamic>>>{};

  static final Map<String, List<dynamic>> _vehiclesCache =
      <String, List<dynamic>>{};
  static final Map<String, DateTime> _vehiclesCacheAt = <String, DateTime>{};
  static final Map<String, Future<List<dynamic>>> _vehiclesInFlight =
      <String, Future<List<dynamic>>>{};

  static final Map<String, DateTime> _backoffUntil = <String, DateTime>{};

  Map<String, String> get _headers => const {
        'Accept': 'application/json',
      };

  Uri _u(String path) {
    final b =
        _base.endsWith('/') ? _base.substring(0, _base.length - 1) : _base;
    final p = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$b$p');
  }

  bool _isFresh(DateTime? fetchedAt, Duration ttl) {
    if (fetchedAt == null) return false;
    return DateTime.now().difference(fetchedAt) < ttl;
  }

  Duration? _retryAfter(http.Response response) {
    final raw = response.headers['retry-after'];
    if (raw == null || raw.trim().isEmpty) return null;

    final seconds = int.tryParse(raw.trim());
    if (seconds != null) {
      return Duration(seconds: seconds.clamp(1, 600));
    }

    final retryAt = DateTime.tryParse(raw);
    if (retryAt == null) return null;

    final diff = retryAt.toUtc().difference(DateTime.now().toUtc());
    return diff.isNegative ? Duration.zero : diff;
  }

  Duration? _activeBackoff(String key) {
    final until = _backoffUntil[key];
    if (until == null) return null;

    final diff = until.difference(DateTime.now());
    if (diff.isNegative) {
      _backoffUntil.remove(key);
      return null;
    }

    return diff;
  }

  void _setBackoff(String key, Duration? retryAfter) {
    _backoffUntil[key] = DateTime.now().add(retryAfter ?? _defaultBackoff);
  }

  TransitRateLimitException _rateLimit(
    String resource, {
    Duration? retryAfter,
  }) {
    return TransitRateLimitException(
      resource: resource,
      retryAfter: retryAfter,
    );
  }

  Map<String, dynamic>? _routeFromRoutesCache(int id) {
    final routes = _routesCache;
    if (routes == null) return null;

    for (final raw in routes.whereType<Map>()) {
      final route = _mapFrom(raw);
      if (_toInt(route['id']) == id) {
        return route;
      }
    }

    return null;
  }

  void seedRoute(Map<String, dynamic> routeData) {
    final route = Map<String, dynamic>.from(routeData);
    if (!_hasGeometry(route)) return;

    final id = _toInt(route['id']);
    if (id == null) return;

    _routeCache[id] = route;
    _routeCacheAt[id] = DateTime.now();
  }

  Future<List<dynamic>> fetchRoutes({bool forceRefresh = false}) async {
    const backoffKey = 'routes';

    if (!forceRefresh &&
        _routesCache != null &&
        _isFresh(_routesCacheAt, _routesTtl)) {
      return _routesCache!;
    }

    if (!forceRefresh) {
      final backoff = _activeBackoff(backoffKey);
      if (backoff != null) {
        if (_routesCache != null) return _routesCache!;
        throw _rateLimit('las rutas', retryAfter: backoff);
      }

      if (_routesInFlight != null) return _routesInFlight!;
    }

    final future = () async {
      final r = await http
          .get(_u('/transit/routes'), headers: _headers)
          .timeout(const Duration(seconds: 12));

      if (r.statusCode == 429) {
        final retryAfter = _retryAfter(r);
        _setBackoff(backoffKey, retryAfter);
        if (_routesCache != null) return _routesCache!;
        throw _rateLimit('las rutas', retryAfter: retryAfter);
      }

      if (r.statusCode != 200) {
        throw Exception('HTTP ${r.statusCode}: ${r.body}');
      }

      final j = jsonDecode(r.body);
      if (j is! List) throw Exception('payload inválido (routes)');

      _routesCache = List<dynamic>.from(j);
      _routesCacheAt = DateTime.now();

      for (final raw in _routesCache!.whereType<Map>()) {
        final route = _mapFrom(raw);
        final id = _toInt(route['id']);
        if (id != null && _hasGeometry(route)) {
          _routeCache[id] = route;
          _routeCacheAt[id] = _routesCacheAt!;
        }
      }

      return _routesCache!;
    }();

    if (!forceRefresh) {
      _routesInFlight = future;
    }

    try {
      return await future;
    } finally {
      if (identical(_routesInFlight, future)) {
        _routesInFlight = null;
      }
    }
  }

  Future<Map<String, dynamic>> fetchRoute(
    int id, {
    bool forceRefresh = false,
  }) async {
    final backoffKey = 'route:$id';

    if (!forceRefresh &&
        _routeCache.containsKey(id) &&
        _isFresh(_routeCacheAt[id], _routeTtl)) {
      return _routeCache[id]!;
    }

    if (!forceRefresh) {
      final fromRoutesCache = _routeFromRoutesCache(id);
      if (fromRoutesCache != null && _hasGeometry(fromRoutesCache)) {
        _routeCache[id] = fromRoutesCache;
        _routeCacheAt[id] = DateTime.now();
        return fromRoutesCache;
      }

      final backoff = _activeBackoff(backoffKey);
      if (backoff != null) {
        final cached = _routeCache[id];
        if (cached != null) return cached;
        throw _rateLimit('la ruta', retryAfter: backoff);
      }

      final inFlight = _routeInFlight[id];
      if (inFlight != null) return inFlight;
    }

    final future = () async {
      final r = await http
          .get(_u('/transit/routes/$id'), headers: _headers)
          .timeout(const Duration(seconds: 12));

      if (r.statusCode == 429) {
        final retryAfter = _retryAfter(r);
        _setBackoff(backoffKey, retryAfter);
        final cached = _routeCache[id];
        if (cached != null) return cached;
        throw _rateLimit('la ruta', retryAfter: retryAfter);
      }

      if (r.statusCode != 200) {
        throw Exception('HTTP ${r.statusCode}: ${r.body}');
      }

      final j = jsonDecode(r.body);
      if (j is! Map<String, dynamic>) {
        throw Exception('payload inválido (route)');
      }

      _routeCache[id] = j;
      _routeCacheAt[id] = DateTime.now();
      return j;
    }();

    if (!forceRefresh) {
      _routeInFlight[id] = future;
    }

    try {
      return await future;
    } finally {
      if (identical(_routeInFlight[id], future)) {
        _routeInFlight.remove(id);
      }
    }
  }

  Future<List<dynamic>> fetchVehicles({int? transitRouteId}) async {
    final cacheKey = transitRouteId == null
        ? 'vehicles:all'
        : 'vehicles:route:$transitRouteId';
    final resource =
        transitRouteId == null ? 'las unidades' : 'las unidades de la ruta';
    final Uri url = (transitRouteId == null)
        ? _u('/transit/vehicles')
        : _u('/transit/routes/$transitRouteId/vehicles');

    if (_vehiclesCache.containsKey(cacheKey) &&
        _isFresh(_vehiclesCacheAt[cacheKey], _vehiclesTtl)) {
      return _vehiclesCache[cacheKey]!;
    }

    final backoff = _activeBackoff(cacheKey);
    if (backoff != null) {
      final cached = _vehiclesCache[cacheKey];
      if (cached != null) return cached;
      throw _rateLimit(resource, retryAfter: backoff);
    }

    final inFlight = _vehiclesInFlight[cacheKey];
    if (inFlight != null) return inFlight;

    final future = () async {
      final r = await http
          .get(url, headers: _headers)
          .timeout(const Duration(seconds: 12));

      if (r.statusCode == 429) {
        final retryAfter = _retryAfter(r);
        _setBackoff(cacheKey, retryAfter);
        final cached = _vehiclesCache[cacheKey];
        if (cached != null) return cached;
        throw _rateLimit(resource, retryAfter: retryAfter);
      }

      if (r.statusCode != 200) {
        throw Exception('HTTP ${r.statusCode}: ${r.body}');
      }

      final j = jsonDecode(r.body);
      if (j is! List) throw Exception('payload inválido (vehicles)');

      final list = List<dynamic>.from(j);
      _vehiclesCache[cacheKey] = list;
      _vehiclesCacheAt[cacheKey] = DateTime.now();
      return list;
    }();

    _vehiclesInFlight[cacheKey] = future;

    try {
      return await future;
    } finally {
      if (identical(_vehiclesInFlight[cacheKey], future)) {
        _vehiclesInFlight.remove(cacheKey);
      }
    }
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
