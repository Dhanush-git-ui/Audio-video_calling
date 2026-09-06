import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart';

/// Fetches a LiveKit token exclusively from the server endpoint.
/// The client never holds apiSecret — server-authoritative by design.
Future<String> fetchServerLiveKitToken({
  required String roomName,
  required String participantName,
  String role = 'patient',
  String? authToken,
}) async {
  final uri = Uri.parse('${AppConfig.baseApiUrl}/rooms/$roomName/token');
  final response = await http.post(
    uri,
    headers: {
      'Content-Type': 'application/json',
      if (authToken != null) 'Authorization': 'Bearer $authToken',
    },
    body: jsonEncode({'identity': participantName, 'role': role}),
  );

  if (response.statusCode >= 200 && response.statusCode < 300) {
    final data = jsonDecode(response.body);
    if (data['token'] != null) return data['token'] as String;
  }
  throw Exception('Token endpoint failed (${response.statusCode}): ${response.body}');
}
