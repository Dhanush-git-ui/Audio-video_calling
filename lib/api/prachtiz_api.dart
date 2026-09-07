import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class PrachtizApi {
  // Configurable base URL: can be overridden via URL parameter 'prachtizApiUrl' or default to localhost:3000 / current web origin
  static String _baseUrl = 'http://localhost:3000';

  static void setBaseUrl(String url) {
    if (url.isNotEmpty) {
      var clean = url.trim();
      if (clean.endsWith('/')) {
        clean = clean.substring(0, clean.length - 1);
      }
      _baseUrl = clean;
      debugPrint('[PrachtizApi] Base URL set to: $_baseUrl');
    }
  }

  static String get baseUrl {
    if (kIsWeb) {
      final queryApi = Uri.base.queryParameters['prachtizApiUrl'] ?? Uri.base.queryParameters['apiUrl'];
      if (queryApi != null && queryApi.isNotEmpty) {
        return queryApi.replaceAll(RegExp(r'/+$'), '');
      }
      // If running on localhost / LAN, point to local Express server port 3000
      if (Uri.base.host == 'localhost' || Uri.base.host == '127.0.0.1') {
        return 'http://localhost:3000';
      }
      // If deployed on Vercel or cloud, API is co-hosted at current origin
      if (Uri.base.origin.isNotEmpty && !Uri.base.origin.startsWith('file://')) {
        return Uri.base.origin;
      }
    }
    return _baseUrl;
  }

  /**
   * 🟢 Share newly created room link to Patient Portal in real time
   * POST /api/consultation/call/share
   */
  static Future<Map<String, dynamic>?> notifyPatientInPrachtiz({
    required String appointmentId,
    required String roomId,
    String? callUrl,
    String? patientName,
    String? symptoms,
    String? doctorName,
    String? customMessage,
  }) async {
    try {
      final targetUrl = callUrl ??
          (kIsWeb
              ? '${Uri.base.origin}/?room=$roomId&role=patient&appointmentId=$appointmentId'
              : 'https://audio-video-calling.vercel.app/?room=$roomId&role=patient&appointmentId=$appointmentId');

      final url = Uri.parse('$baseUrl/api/consultation/call/share');
      final payload = jsonEncode({
        'appointment_id': appointmentId,
        'call_url': targetUrl,
        'room_id': roomId,
        'custom_message': customMessage ?? 'Dr. Amanulla Baig has started your video consultation. Click below to join.',
        if (patientName != null) 'patient_name': patientName,
        if (symptoms != null) 'patient_symptoms': symptoms,
        if (doctorName != null) 'doctor_name': doctorName,
      });

      debugPrint('[PrachtizApi] 📤 Sharing room link to Patient Portal: $url with payload $payload');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: payload,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('[PrachtizApi] ✅ Successfully sent room link to patient portal: $data');
        return data;
      } else {
        debugPrint('[PrachtizApi] ⚠️ Share returned status ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('[PrachtizApi] ❌ Error sharing call link to Prachtiz: $e');
      return null;
    }
  }

  /**
   * 🟢 Fetch full patient & booking details
   * GET /api/consultation/appointment-data/:appointmentId
   */
  static Future<Map<String, dynamic>?> getPatientAppointmentDetails(String appointmentId) async {
    try {
      final url = Uri.parse('$baseUrl/api/consultation/appointment-data/$appointmentId');
      final response = await http.get(url, headers: {'Content-Type': 'application/json'});

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        debugPrint('[PrachtizApi] ⚠️ Failed to fetch appointment data: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('[PrachtizApi] ❌ Error fetching appointment data: $e');
      return null;
    }
  }

  /**
   * 🟢 End call session and mark appointment completed
   * POST /api/consultation/call/:roomId/end
   */
  static Future<Map<String, dynamic>?> endPrachtizCallSession(String roomId, String appointmentId) async {
    try {
      final url = Uri.parse('$baseUrl/api/consultation/call/$roomId/end');
      final payload = jsonEncode({'appointment_id': appointmentId});

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: payload,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('[PrachtizApi] 🛑 Call session ended in Prachtiz: $data');
        return data;
      }
      return null;
    } catch (e) {
      debugPrint('[PrachtizApi] ❌ Error ending call session in Prachtiz: $e');
      return null;
    }
  }

  /**
   * 🟢 Patient portal polling status
   * GET /api/consultation/call/:appointmentId/status
   */
  static Future<Map<String, dynamic>?> checkCallStatus(String appointmentId) async {
    try {
      final url = Uri.parse('$baseUrl/api/consultation/call/$appointmentId/status');
      final response = await http.get(url, headers: {'Content-Type': 'application/json'});

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('[PrachtizApi] ❌ Error checking call status: $e');
      return null;
    }
  }
}
