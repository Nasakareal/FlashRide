import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as dev;

class AuthService {
  // ⚡ Usa siempre HTTPS con /public/api
  static const _baseUrl = 'https://158.23.170.129/flashride/public/api';

  static String get baseUrl => _baseUrl;

  static const _jsonHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  /// LOGIN: devuelve true/false
  static Future<bool> login({
    String? email,
    String? phone,
    required String password,
  }) async {
    try {
      final String? emailTrim =
          (email != null && email.trim().isNotEmpty) ? email.trim() : null;
      final String? phoneDigits = (phone != null && phone.trim().isNotEmpty)
          ? phone.replaceAll(RegExp(r'\D'), '')
          : null;

      final Map<String, dynamic> body = {
        'password': password,
        if (emailTrim != null) 'email': emailTrim,
        if (phoneDigits != null) 'phone': phoneDigits,
      };

      if (!body.containsKey('email') && !body.containsKey('phone')) {
        dev.log('❗ LOGIN sin email/phone');
        return false;
      }

      final res = await http.post(
        Uri.parse('$_baseUrl/login'),
        headers: _jsonHeaders,
        body: jsonEncode(body),
      );

      dev.log('📥 LOGIN ${res.statusCode}: ${res.body}');

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['token'] as String);
        await prefs.setString('role', (data['user']['role'] ?? '').toString());
        return true;
      } else {
        try {
          final err = jsonDecode(res.body);
          dev.log('❌ LOGIN ERROR: $err');
        } catch (_) {
          dev.log('❌ LOGIN ERROR (raw): ${res.body}');
        }
        return false;
      }
    } catch (e) {
      dev.log('🔥 LOGIN EXCEPTION: $e');
      return false;
    }
  }

  /// REGISTER
  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      final payload = {
        'name': name.trim(),
        'email': email.trim(),
        'phone': phone.replaceAll(RegExp(r'\D'), ''),
        'password': password,
        'password_confirmation': passwordConfirmation,
      };

      final res = await http.post(
        Uri.parse('$_baseUrl/register'),
        headers: _jsonHeaders,
        body: jsonEncode(payload),
      );

      dev.log('📥 REGISTER ${res.statusCode}: ${res.body}');
      final body = jsonDecode(res.body);

      if (res.statusCode == 201) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', body['token']);
        await prefs.setString('role', (body['user']['role'] ?? '').toString());
        return {'ok': true};
      } else {
        final errs = (body['errors'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, List<String>.from(v))) ??
            {
              'general': [body['message']?.toString() ?? 'Error desconocido']
            };
        return {'ok': false, 'errors': errs};
      }
    } catch (e) {
      dev.log('🔥 REGISTER EXCEPTION: $e');
      return {
        'ok': false,
        'errors': {
          'general': [e.toString()]
        }
      };
    }
  }

  /// Recupera el token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final t = prefs.getString('token');
    if (t == null || t.isEmpty) {
      dev.log("⚠️ No hay token guardado en SharedPreferences");
      return null;
    }
    return t;
  }

  static Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('role');
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  /// Helper para headers con token ya listo
  static Future<Map<String, String>> authHeaders() async {
    final token = await getToken();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
}
