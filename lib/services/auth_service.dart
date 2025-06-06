import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as dev;

class AuthService {
  static const _baseUrl = 'http://158.23.170.129/api';

  /// LOGIN: devuelve true/false
  static Future<bool> login({
    String? email,
    String? phone,
    required String password,
  }) async {
    final body = {
      'password': password,
      if (email != null && email.isNotEmpty) 'email': email,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
    };

    final res = await http.post(
      Uri.parse('$_baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    dev.log('📥 LOGIN ${res.statusCode}: ${res.body}');
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', data['token']);
      await prefs.setString('role', data['user']['role']);
      return true;
    }
    return false;
  }

  /// REGISTER: devuelve { ok:bool, errors:Map<String,List<String>> }
  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'phone': phone,
          'password': password,
          'password_confirmation': passwordConfirmation,
        }),
      );
      dev.log('📥 REGISTER ${res.statusCode}: ${res.body}');
      final body = jsonDecode(res.body);

      if (res.statusCode == 201) {
        // Éxito: guardamos token y rol
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', body['token']);
        await prefs.setString('role', body['user']['role']);
        return {'ok': true};
      } else {
        // Error de validación u otro
        final errs = body['errors'] as Map<String, dynamic>? ??
            {
              'general': [body['message'] ?? 'Error desconocido']
            };
        return {
          'ok': false,
          'errors': errs.map((k, v) => MapEntry(k, List<String>.from(v))),
        };
      }
    } catch (e) {
      // Falló la petición HTTP o parsing
      dev.log('🔥 REGISTER EXCEPTION: $e');
      return {
        'ok': false,
        'errors': {
          'general': [e.toString()]
        }
      };
    }
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('role');
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
