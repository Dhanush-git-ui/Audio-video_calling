import 'dart:convert';
import 'api_client.dart';

class AuthApi {
  static Future<Map<String, dynamic>> doctorLogin(String username, String password, {String? otp}) async {
    final res = await ApiClient.post('/auth/doctor/login', {
      'username': username,
      'password': password,
      if (otp != null) 'otp': otp,
    });
    final body = jsonDecode(res.body);
    if (res.statusCode == 200 && body['token'] != null) {
      ApiClient.setAuthToken(body['token']);
    }
    return body;
  }

  static Future<Map<String, dynamic>> patientLogin(String name, String mobileOrEmail, {String? otp}) async {
    final res = await ApiClient.post('/auth/patient/login', {
      'name': name,
      'mobileOrEmail': mobileOrEmail,
      if (otp != null) 'otp': otp,
    });
    final body = jsonDecode(res.body);
    if (res.statusCode == 200 && body['token'] != null) {
      ApiClient.setAuthToken(body['token']);
    }
    return body;
  }

  static Future<Map<String, dynamic>> verifyGuest(String roomId, String accessCode, String name) async {
    final res = await ApiClient.post('/auth/guest/verify', {
      'roomId': roomId,
      'accessCode': accessCode,
      'name': name,
    });
    final body = jsonDecode(res.body);
    if (res.statusCode == 200 && body['token'] != null) {
      ApiClient.setAuthToken(body['token']);
    }
    return body;
  }
}
