import 'dart:convert';
import 'api_client.dart';

class BiometricApi {
  static Future<Map<String, dynamic>> uploadCapture({
    required String roomId,
    required String targetType,
    required String imageDataUrl,
  }) async {
    final res = await ApiClient.post('/biometric/capture', {
      'roomId': roomId,
      'targetType': targetType,
      'imageDataUrl': imageDataUrl,
    });
    return jsonDecode(res.body);
  }

  static Future<List<dynamic>> fetchAuditTrail(String roomId) async {
    final res = await ApiClient.get('/biometric/audit/$roomId');
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      return body['data'] as List<dynamic>? ?? [];
    }
    return [];
  }
}
