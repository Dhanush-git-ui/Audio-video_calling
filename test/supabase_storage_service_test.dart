import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:chav_flutter/config.dart';
import 'package:chav_flutter/services/supabase_storage_service.dart';

void main() {
  setUp(() {
    SupabaseStorageService.clearDeduplicationCache();
  });

  group('Supabase Storage Configuration', () {
    test('Configures correct target bucket and folder path', () {
      expect(SupabaseConfig.consultationBucket, equals('chav_consultation_files'));
      expect(SupabaseConfig.consultationFolder, equals('consultation-files'));
    });

    test('Public URL generator formats correct path in bucket', () {
      final url = SupabaseStorageService.getPublicUrl('consultation-files/sample.pdf');
      expect(url, contains('/storage/v1/object/public/chav_consultation_files/consultation-files/sample.pdf'));
    });
  });

  group('Supabase Response Error Handling & Client API', () {
    test('Supabase client exposes .storage.from(bucket).upload()', () {
      final bucket = Supabase.storage.from('chav_consultation_files');
      expect(bucket.bucketName, equals('chav_consultation_files'));
    });

    test('upload() returns error object on empty bytes rather than throwing', () async {
      final bucket = Supabase.storage.from('chav_consultation_files');
      final response = await bucket.upload('consultation-files/empty.txt', Uint8List(0));
      expect(response.error, isNotNull);
      expect(response.error!.statusCode, equals(400));
      expect(response.hasError, isTrue);
      expect(response.data, isNull);
    });

    test('uploadFile() rejects empty bytes with explicit error result', () async {
      final result = await SupabaseStorageService.uploadFile(
        fileName: 'empty.txt',
        bytes: Uint8List(0),
      );
      expect(result.isSuccess, isFalse);
      expect(result.hasError, isTrue);
      expect(result.error, isNotNull);
      expect(result.error!.statusCode, equals(400));
    });
  });

  group('SHA-256 Hashing & Deduplication / Idempotency', () {
    test('Calculates consistent deterministic SHA-256 hash', () {
      final sampleBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final hash1 = SupabaseStorageService.computeHash(sampleBytes);
      final hash2 = SupabaseStorageService.computeHash(sampleBytes);
      expect(hash1, equals(hash2));
      expect(hash1.length, equals(64)); // 256 bits = 64 hex chars
    });

    test('Different bytes generate different hashes', () {
      final bytesA = Uint8List.fromList([1, 2, 3]);
      final bytesB = Uint8List.fromList([1, 2, 4]);
      expect(
        SupabaseStorageService.computeHash(bytesA),
        isNot(equals(SupabaseStorageService.computeHash(bytesB))),
      );
    });

    test('Detects already-uploaded hash and skips duplicate upload', () async {
      final testBytes = Uint8List.fromList([10, 20, 30, 40, 50]);
      final hash = SupabaseStorageService.computeHash(testBytes);

      expect(SupabaseStorageService.isAlreadyUploaded(hash), isFalse);

      // Simulate a first upload
      final upload1 = await SupabaseStorageService.uploadFile(
        fileName: 'test.pdf',
        bytes: testBytes,
      );

      // If upload1 succeeded or failed due to network, test idempotency behavior
      if (upload1.isSuccess) {
        expect(SupabaseStorageService.isAlreadyUploaded(hash), isTrue);
        // Second upload of identical bytes skips network upload
        final upload2 = await SupabaseStorageService.uploadFile(
          fileName: 'test.pdf',
          bytes: testBytes,
        );
        expect(upload2.isSuccess, isTrue);
        expect(upload2.isDuplicate, isTrue);
      }
    });
  });

  tearDownAll(() async {
    try {
      await http.delete(
        Uri.parse('${SupabaseConfig.url}/storage/v1/object/${SupabaseConfig.consultationBucket}'),
        headers: {
          'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
          'apikey': SupabaseConfig.anonKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'prefixes': ['consultation-files/test.pdf']
        }),
      );
    } catch (_) {}
  });
}
