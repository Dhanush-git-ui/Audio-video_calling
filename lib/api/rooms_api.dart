import 'dart:convert';
import 'api_client.dart';

class RoomsApi {
  static Future<Map<String, dynamic>> createRoom({String? roomName}) async {
    final res = await ApiClient.post('/rooms', {
      if (roomName != null) 'roomName': roomName,
    });
    return jsonDecode(res.body);
  }

  static Future<String?> mintToken(String roomId, String identity) async {
    final res = await ApiClient.post('/rooms/$roomId/token', {
      'identity': identity,
    });
    final body = jsonDecode(res.body);
    return body['token'] as String?;
  }

  static Future<bool> verifyAccessCode(String roomId, String code) async {
    final res = await ApiClient.post('/rooms/$roomId/verify-code', {
      'code': code,
    });
    return res.statusCode == 200;
  }

  static Future<Map<String, dynamic>> getRoomMetadata(String roomId) async {
    final res = await ApiClient.get('/rooms/$roomId');
    return jsonDecode(res.body);
  }
}
