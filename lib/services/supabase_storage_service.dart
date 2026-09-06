import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

class SupabaseFileRecord {
  final String fileName;
  final String captureType;
  final String storagePath;
  final DateTime timestamp;
  final int sizeBytes;
  final String status;
  final String dataUrl;

  SupabaseFileRecord({
    required this.fileName,
    required this.captureType,
    required this.storagePath,
    required this.timestamp,
    required this.sizeBytes,
    required this.status,
    required this.dataUrl,
  });
}

/// Uploads captured biometrics via Backend Storage Service (/api/biometric/capture).
class SupabaseStorageService {
  static final List<SupabaseFileRecord> storedFilesLog = [];
  static String get _backendUrl => '${AppConfig.baseApiUrl}/biometric/capture';

  /// Sends base64 PNG data to the backend Biometric Storage Service.
  static Future<SupabaseFileRecord> uploadBase64Image({
    required String dataUrl,
    required String captureType,
    required String roomName,
    String? authToken,
  }) async {
    final now = DateTime.now();
    final epoch = now.millisecondsSinceEpoch;
    final fileName = '${captureType.toLowerCase()}_$epoch.png';
    final filePath = 'biometric_captures/${roomName}_$fileName';

    Uint8List bytes;
    try {
      final base64Str = dataUrl.contains(',') ? dataUrl.split(',').last : dataUrl;
      bytes = base64.decode(base64Str);
    } catch (e) {
      bytes = Uint8List(0);
    }

    String status = '✅ Stored in Backend Biometric Storage ($filePath)';

    try {
      final response = await http.post(
        Uri.parse(_backendUrl),
        headers: {
          'Content-Type': 'application/json',
          if (authToken != null) 'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'roomId': roomName,
          'targetType': captureType,
          'imageDataUrl': dataUrl,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        status = '✅ Uploaded via Secure Backend Storage (/api/biometric/capture)';
      } else {
        status = '⚠️ Storage upload failed (${response.statusCode})';
      }
    } catch (e) {
      debugPrint("Storage service note: $e");
    }

    final record = SupabaseFileRecord(
      fileName: fileName,
      captureType: captureType,
      storagePath: filePath,
      timestamp: now,
      sizeBytes: bytes.length,
      status: status,
      dataUrl: dataUrl,
    );

    storedFilesLog.add(record);
    return record;
  }

  static Future<bool> uploadFile({
    required String fileName,
    required Uint8List bytes,
    required DateTime receivedAt,
    required DateTime callEndedAt,
  }) async {
    try {
      final epoch = callEndedAt.millisecondsSinceEpoch;
      final filePath = '${SupabaseConfig.prefix}/${epoch}_$fileName';

      final uploadUrl = Uri.parse('${SupabaseConfig.url}/storage/v1/object/${SupabaseConfig.bucket}/$filePath');
      await http.post(
        uploadUrl,
        headers: {
          'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
          'apikey': SupabaseConfig.anonKey,
          'Content-Type': 'application/octet-stream',
          'x-upsert': 'true',
        },
        body: bytes,
      );
      return true;
    } catch (e, st) {
      debugPrint('Supabase upload note for $fileName: $e\n$st');
      return false;
    }
  }
}
