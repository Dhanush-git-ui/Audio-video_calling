import 'dart:convert';
import 'api_client.dart';

class ScoringApi {
  static Future<Map<String, dynamic>> postFaceSignals(Map<String, dynamic> signals) async {
    final res = await ApiClient.post('/scoring/face', signals);
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> postIrisSignals(Map<String, dynamic> signals) async {
    final res = await ApiClient.post('/scoring/iris', signals);
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> postBodySignals(Map<String, dynamic> signals) async {
    final res = await ApiClient.post('/scoring/body', signals);
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> postLivenessSignals(Map<String, dynamic> signals) async {
    final res = await ApiClient.post('/scoring/liveness', signals);
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> postAntiSpoofSignals(Map<String, dynamic> signals) async {
    final res = await ApiClient.post('/scoring/anti-spoof', signals);
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> finalizeVerification({
    required String userId,
    required String roomId,
    String? deviceId,
    Map<String, double>? subScores,
  }) async {
    final res = await ApiClient.post('/scoring/finalize', {
      'userId': userId,
      'roomId': roomId,
      if (deviceId != null) 'deviceId': deviceId,
      if (subScores != null) 'subScores': subScores,
    });
    return jsonDecode(res.body);
  }
}
