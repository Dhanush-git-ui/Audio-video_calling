import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

Future<String> fetchServerLiveKitToken({
  required String roomName,
  required String participantName,
  String role = 'patient',
  String? authToken,
}) async {
  try {
    final uri = Uri.parse('http://localhost:5005/api/rooms/$roomName/token');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (authToken != null) 'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode({
        'identity': participantName,
        'role': role,
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body);
      if (data['token'] != null) {
        return data['token'] as String;
      }
    }
  } catch (e) {
    // Fallback to local signed token if offline
  }

  return generateLiveKitToken(roomName: roomName, participantName: participantName);
}

String generateLiveKitToken({
  required String roomName,
  required String participantName,
  String apiKey = 'devkey',
  String apiSecret = 'secret',
}) {
  final jwt = JWT({
    'iss': apiKey,
    'sub': participantName,
    'nbf': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    'exp': (DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch ~/ 1000),
    'video': {
      'room': roomName,
      'roomJoin': true,
      'canPublish': true,
      'canSubscribe': true,
    }
  });

  return jwt.sign(SecretKey(apiSecret));
}