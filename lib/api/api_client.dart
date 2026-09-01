import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

class ApiClient {
  static String? _authToken;

  static void setAuthToken(String token) {
    _authToken = token;
  }

  static String? get authToken => _authToken;

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      };

  static Future<http.Response> get(String endpoint) async {
    final uri = Uri.parse('${AppConfig.baseApiUrl}$endpoint');
    return await http.get(uri, headers: _headers);
  }

  static Future<http.Response> post(String endpoint, Map<String, dynamic> body) async {
    final uri = Uri.parse('${AppConfig.baseApiUrl}$endpoint');
    return await http.post(uri, headers: _headers, body: jsonEncode(body));
  }

  static Future<http.Response> patch(String endpoint, Map<String, dynamic> body) async {
    final uri = Uri.parse('${AppConfig.baseApiUrl}$endpoint');
    return await http.patch(uri, headers: _headers, body: jsonEncode(body));
  }
}
