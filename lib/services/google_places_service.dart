import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class PlaceSug {
  final String id;
  final String desc;
  const PlaceSug(this.id, this.desc);
}

class GooglePlacesService {
  final String apiKey;

  const GooglePlacesService({required this.apiKey});

  Future<List<PlaceSug>> autocomplete({
    required String input,
    required LatLng near,
    String language = 'es',
    String country = 'mx',
    int radius = 30000,
  }) async {
    final txt = input.trim();
    if (txt.isEmpty) return const [];

    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json'
      '?input=${Uri.encodeComponent(txt)}'
      '&key=$apiKey'
      '&language=$language'
      '&components=country:$country'
      '&region=$country'
      '&location=${near.latitude},${near.longitude}'
      '&radius=$radius'
      '&strictbounds=true',
    );

    final r = await http.get(uri);
    if (r.statusCode != 200) {
      throw Exception('Places autocomplete ${r.statusCode}: ${r.body}');
    }

    final j = jsonDecode(r.body);
    final preds = (j is Map && j['predictions'] is List)
        ? (j['predictions'] as List)
        : const [];
    return preds
        .whereType<Map>()
        .map((e) => PlaceSug(
              (e['place_id'] ?? '').toString(),
              (e['description'] ?? '').toString(),
            ))
        .where((s) => s.id.isNotEmpty && s.desc.isNotEmpty)
        .toList();
  }

  Future<LatLng> placeDetailsLatLng({
    required String placeId,
  }) async {
    final id = placeId.trim();
    if (id.isEmpty) {
      throw Exception('placeId vacío');
    }

    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/details/json'
      '?place_id=$id'
      '&key=$apiKey'
      '&fields=geometry',
    );

    final r = await http.get(uri);
    if (r.statusCode != 200) {
      throw Exception('Place details ${r.statusCode}: ${r.body}');
    }

    final j = jsonDecode(r.body);
    final loc = (j is Map &&
            j['result'] is Map &&
            (j['result'] as Map)['geometry'] is Map &&
            ((j['result'] as Map)['geometry'] as Map)['location'] is Map)
        ? (((j['result'] as Map)['geometry'] as Map)['location'] as Map)
        : null;

    if (loc == null) {
      throw Exception('Respuesta inválida de place/details');
    }

    final lat = (loc['lat'] is num)
        ? (loc['lat'] as num).toDouble()
        : double.tryParse('${loc['lat']}');
    final lng = (loc['lng'] is num)
        ? (loc['lng'] as num).toDouble()
        : double.tryParse('${loc['lng']}');

    if (lat == null || lng == null) {
      throw Exception('Sin lat/lng en place/details');
    }

    return LatLng(lat, lng);
  }
}
