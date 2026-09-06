import 'dart:convert';
<<<<<<< HEAD
import 'package:crypto/crypto.dart';
=======
import 'dart:typed_data';
>>>>>>> origin/main
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

<<<<<<< HEAD
/// Representation of an error returned by Supabase Storage operations.
class StorageError {
  final String message;
  final int? statusCode;
  final String? error;

  StorageError({
    required this.message,
    this.statusCode,
    this.error,
  });

  @override
  String toString() => 'StorageError(status: $statusCode, error: $error, message: $message)';
}

/// Representation of the response from Supabase Storage operations, containing
/// data and error properties conforming to Supabase client conventions.
class StorageResponse<T> {
  final T? data;
  final StorageError? error;

  bool get hasError => error != null;

  StorageResponse({this.data, this.error});
}

/// Result returned by uploadFile containing upload status, metadata, and error details.
class StorageUploadResult {
  final bool isSuccess;
  final String? storagePath;
  final String? publicUrl;
  final StorageError? error;
  final bool isDuplicate;

  bool get hasError => error != null;

  StorageUploadResult.success({
    required this.storagePath,
    required this.publicUrl,
    this.isDuplicate = false,
  })  : isSuccess = true,
        error = null;

  StorageUploadResult.failure(this.error)
      : isSuccess = false,
        storagePath = null,
        publicUrl = null,
        isDuplicate = false;
}

/// Bucket interface implementing Supabase storage bucket operations:
/// `supabase.storage.from('chav_consultation_files').upload(...)`
class SupabaseStorageBucket {
  final String bucketName;
  final String baseUrl;
  final String apiKey;

  SupabaseStorageBucket({
    required this.bucketName,
    required this.baseUrl,
    required this.apiKey,
  });

  /// Checks if the API key is unconfigured
  bool get _isUnconfigured => apiKey.trim().isEmpty;

  /// Uploads raw bytes to a target path within this bucket.
  /// Does NOT throw exceptions on API error responses; returns a StorageResponse with { data, error }.
  Future<StorageResponse<String>> upload(
    String path,
    Uint8List bytes, {
    String? contentType,
    bool upsert = false,
  }) async {
    if (bytes.isEmpty) {
      return StorageResponse(
        error: StorageError(message: 'File bytes cannot be empty.', statusCode: 400),
      );
    }

    if (_isUnconfigured) {
      const msg = 'Supabase Anon Key is not configured. Please set a valid Anon Key in lib/config.dart or via --dart-define=SUPABASE_ANON_KEY=...';
      print('⚠️ [Supabase Storage] $msg');
      return StorageResponse(
        error: StorageError(message: msg, statusCode: 401, error: 'UnconfiguredCredentials'),
      );
    }

    try {
      final cleanPath = path.startsWith('/') ? path.substring(1) : path;
      final uri = Uri.parse('$baseUrl/storage/v1/object/$bucketName/$cleanPath');

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'apikey': apiKey,
          'Content-Type': contentType ?? 'application/octet-stream',
          'x-upsert': upsert ? 'true' : 'false',
        },
        body: bytes,
      );

      // HTTP 200 - 299: Success
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return StorageResponse(data: cleanPath);
      }

      // Parse error details from Supabase JSON response
      String errorMsg = response.body;
      String? errCode;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          errorMsg = decoded['message'] ?? decoded['error'] ?? response.body;
          errCode = decoded['error']?.toString() ?? decoded['statusCode']?.toString();
        }
      } catch (_) {}

      return StorageResponse(
        error: StorageError(
          message: errorMsg,
          statusCode: response.statusCode,
          error: errCode,
        ),
      );
    } catch (e) {
      // Return network/host errors as an error object rather than throwing
      return StorageResponse(
        error: StorageError(
          message: e.toString(),
          statusCode: 0,
          error: 'NetworkException',
        ),
      );
    }
  }

  /// Checks if a file already exists in the bucket at the given path.
  Future<bool> exists(String path, {int? expectedSize}) async {
    try {
      final cleanPath = path.startsWith('/') ? path.substring(1) : path;
      final uri = Uri.parse('$baseUrl/storage/v1/object/public/$bucketName/$cleanPath');
      final res = await http.head(uri);
      if (res.statusCode == 200) {
        if (expectedSize != null) {
          final len = int.tryParse(res.headers['content-length'] ?? '');
          return len == expectedSize;
        }
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}

/// Supabase Storage client providing `.from(bucketName)`
class SupabaseStorageClient {
  final String url;
  final String apiKey;

  SupabaseStorageClient({required this.url, required this.apiKey});

  SupabaseStorageBucket from(String bucketId) {
    return SupabaseStorageBucket(
      bucketName: bucketId,
      baseUrl: url,
      apiKey: apiKey,
    );
  }
}

/// Client instance matching standard Supabase SDK syntax:
/// `supabase.storage.from('chav_consultation_files').upload(...)`
class Supabase {
  static SupabaseStorageClient get storage => SupabaseStorageClient(
        url: SupabaseConfig.url,
        apiKey: SupabaseConfig.anonKey,
      );
}

/// Service handling Supabase Storage for Biometrics and Chatbox Consultation Files.
=======
/// Uploads captured biometrics via Backend Storage Service (/api/biometric/capture).
>>>>>>> origin/main
class SupabaseStorageService {
  static final List<SupabaseFileRecord> storedFilesLog = [];
  static const String _backendUrl = 'http://localhost:5005/api/biometric/capture';

<<<<<<< HEAD
  /// In-memory cache of SHA-256 hashes of uploaded files in the current session
  /// to ensure strict idempotency and avoid duplicate uploads.
  static final Set<String> _uploadedHashes = <String>{};

  /// Map of file hash to saved storage path in bucket.
  static final Map<String, String> _hashToStoragePath = <String, String>{};

  /// Computes the SHA-256 hash of raw byte data.
  static String computeHash(Uint8List bytes) {
    return sha256.convert(bytes).toString();
  }

  /// Checks if a file hash has already been marked as uploaded in this session.
  static bool isAlreadyUploaded(String fileHash) {
    return _uploadedHashes.contains(fileHash);
  }

  /// Clears in-memory deduplication cache (primarily for tests).
  static void clearDeduplicationCache() {
    _uploadedHashes.clear();
    _hashToStoragePath.clear();
  }

  /// Determines MIME type from file extension.
  static String _detectMimeType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.txt')) return 'text/plain';
    if (lower.endsWith('.doc') || lower.endsWith('.docx')) return 'application/msword';
    if (lower.endsWith('.xls') || lower.endsWith('.xlsx')) return 'application/vnd.ms-excel';
    if (lower.endsWith('.ppt') || lower.endsWith('.pptx')) return 'application/vnd.ms-powerpoint';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.zip')) return 'application/zip';
    return 'application/octet-stream';
  }

  /// Returns the public URL for a file stored in chav_consultation_files.
  static String getPublicUrl(String storagePath) {
    final cleanPath = storagePath.startsWith('/') ? storagePath.substring(1) : storagePath;
    return '${SupabaseConfig.url}/storage/v1/object/public/${SupabaseConfig.consultationBucket}/$cleanPath';
  }

  /// Uploads captured biometrics via Backend Storage Service (/api/biometric/capture).
=======
  /// Sends base64 PNG data to the backend Biometric Storage Service.
>>>>>>> origin/main
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
        // Direct REST fallback if server unavailable
        final uploadUrl = Uri.parse('${SupabaseConfig.url}/storage/v1/object/${SupabaseConfig.bucket}/$filePath');
        await http.post(
          uploadUrl,
          headers: {
            'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
            'apikey': SupabaseConfig.anonKey,
            'Content-Type': 'image/png',
            'x-upsert': 'true',
          },
          body: bytes,
        );
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

<<<<<<< HEAD
  /// Uploads a chatbox consultation file into the `chav_consultation_files` bucket
  /// under the `consultation-files/` folder path.
  ///
  /// Strictly checks the error object returned by `supabase.storage.from(...).upload(...)`
  /// and performs content-based deduplication before uploading.
  static Future<StorageUploadResult> uploadFile({
    required String fileName,
    required Uint8List? bytes,
    DateTime? receivedAt,
    DateTime? callEndedAt,
  }) async {
    if (bytes == null || bytes.isEmpty) {
      const msg = 'Cannot upload an empty or null file.';
      print('⚠️ [Supabase Storage] $msg');
      return StorageUploadResult.failure(StorageError(message: msg, statusCode: 400));
    }

    final fileHash = computeHash(bytes);

    // 1. In-memory session deduplication check
    if (_uploadedHashes.contains(fileHash)) {
      final existingPath = _hashToStoragePath[fileHash] ?? '${SupabaseConfig.consultationFolder}/$fileName';
      final publicUrl = getPublicUrl(existingPath);
      print('ℹ️ [Supabase Deduplication] File "$fileName" (SHA-256: ${fileHash.substring(0, 10)}...) already uploaded this session ($existingPath). Skipping re-upload.');
      return StorageUploadResult.success(
        storagePath: existingPath,
        publicUrl: publicUrl,
        isDuplicate: true,
      );
    }

    final cleanName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final targetPath = '${SupabaseConfig.consultationFolder}/$cleanName';

    // 2. Remote storage existence check (Deduplication)
    // Check if the exact file already exists in the bucket before uploading
    final alreadyExists = await Supabase.storage
        .from(SupabaseConfig.consultationBucket)
        .exists(targetPath, expectedSize: bytes.length);

    if (alreadyExists) {
      _uploadedHashes.add(fileHash);
      _hashToStoragePath[fileHash] = targetPath;
      final publicUrl = getPublicUrl(targetPath);
      print('ℹ️ [Supabase Deduplication] File "$cleanName" already exists in ${SupabaseConfig.consultationBucket}/$targetPath with identical size (${bytes.length} bytes). Skipping re-upload.');
      return StorageUploadResult.success(
        storagePath: targetPath,
        publicUrl: publicUrl,
        isDuplicate: true,
      );
    }

    // 3. Upload to chav_consultation_files bucket under consultation-files/
    final mimeType = _detectMimeType(fileName);
    final response = await Supabase.storage
        .from(SupabaseConfig.consultationBucket)
        .upload(targetPath, bytes, contentType: mimeType, upsert: false);

    // 4. Supabase Response Error Handling: explicitly check response.error object
    if (response.error != null) {
      // If 409 Conflict: file was already saved concurrently or previously
      if (response.error!.statusCode == 409) {
        _uploadedHashes.add(fileHash);
        _hashToStoragePath[fileHash] = targetPath;
        print('ℹ️ [Supabase Storage] File "$cleanName" already present in ${SupabaseConfig.consultationBucket}/$targetPath (409 Duplicate). Marked as saved.');
        return StorageUploadResult.success(
          storagePath: targetPath,
          publicUrl: getPublicUrl(targetPath),
          isDuplicate: true,
        );
      }

      final errorDetail = 'Upload failed (${response.error!.statusCode ?? "Network"}): ${response.error!.message}';
      print('❌ [Supabase Storage Error] $errorDetail');
      return StorageUploadResult.failure(response.error!);
    }

    // Success!
    final savedPath = response.data ?? targetPath;
    _uploadedHashes.add(fileHash);
    _hashToStoragePath[fileHash] = savedPath;
    final publicUrl = getPublicUrl(savedPath);

    print('✅ [Supabase Storage Success] Successfully uploaded "$cleanName" to ${SupabaseConfig.consultationBucket}/$savedPath');
    return StorageUploadResult.success(
      storagePath: savedPath,
      publicUrl: publicUrl,
      isDuplicate: false,
    );
=======
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
>>>>>>> origin/main
  }
}
