import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as dev;
import 'api_config.dart';

class LoginResult {
  final bool success;
  final String? message;
  final int? statusCode;

  const LoginResult._({
    required this.success,
    this.message,
    this.statusCode,
  });

  const LoginResult.success() : this._(success: true);

  const LoginResult.failure({
    String? message,
    int? statusCode,
  }) : this._(
          success: false,
          message: message,
          statusCode: statusCode,
        );
}

class AuthService {
  static String get baseUrl => ApiConfig.baseUrl;

  static const _jsonHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  static Future<LoginResult> login({
    String? email,
    String? phone,
    required String password,
  }) async {
    try {
      final String? emailNormalized = (email != null && email.trim().isNotEmpty)
          ? email.trim().toLowerCase()
          : null;

      final String? phoneDigits = (phone != null && phone.trim().isNotEmpty)
          ? phone.replaceAll(RegExp(r'\D'), '')
          : null;

      final String passwordClean = password.trim();

      final Map<String, dynamic> body = {
        'password': passwordClean,
        if (emailNormalized != null) 'email': emailNormalized,
        if (phoneDigits != null) 'phone': phoneDigits,
      };

      if (!body.containsKey('email') && !body.containsKey('phone')) {
        dev.log('❗ LOGIN sin email/phone');
        return const LoginResult.failure(
          message: 'Ingresa un correo o teléfono válido.',
        );
      }

      final res = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: _jsonHeaders,
        body: jsonEncode(body),
      );

      dev.log('📥 LOGIN ${res.statusCode}: ${res.body}');

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['token'] as String);
        await prefs.setString('role', (data['user']['role'] ?? '').toString());
        return const LoginResult.success();
      } else {
        String message = 'Credenciales inválidas';
        try {
          final err = jsonDecode(res.body);
          dev.log('❌ LOGIN ERROR: $err');
          final apiMessage = err['message']?.toString().trim();
          if (apiMessage != null && apiMessage.isNotEmpty) {
            message = apiMessage;
          }
        } catch (_) {
          dev.log('❌ LOGIN ERROR (raw): ${res.body}');
        }
        return LoginResult.failure(
          message: message,
          statusCode: res.statusCode,
        );
      }
    } on HandshakeException catch (e) {
      dev.log('🔥 LOGIN TLS EXCEPTION: $e');
      return const LoginResult.failure(
        message:
            'No se pudo establecer una conexión segura con el servidor. Verifica el certificado SSL/TLS del API.',
      );
    } on SocketException catch (e) {
      dev.log('🔥 LOGIN SOCKET EXCEPTION: $e');
      return const LoginResult.failure(
        message:
            'No se pudo conectar al servidor. Revisa la red y el host del API.',
      );
    } catch (e) {
      dev.log('🔥 LOGIN EXCEPTION: $e');
      return LoginResult.failure(
        message: 'Error de conexión: $e',
      );
    }
  }

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
        'email': email.trim().toLowerCase(),
        'phone': phone.replaceAll(RegExp(r'\D'), ''),
        'password': password.trim(),
        'password_confirmation': passwordConfirmation.trim(),
      };

      final res = await http.post(
        Uri.parse('$baseUrl/register'),
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

  static Future<Map<String, String>> authHeaders() async {
    final token = await getToken();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
}
