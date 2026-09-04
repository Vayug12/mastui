import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'revenue_cat_service.dart';

/// Service for interacting with Cloudflare Workers AI.
/// Preserved and generalized for the new product requirements.
class CloudflareAiService {
  CloudflareAiService._();
  static final instance = CloudflareAiService._();

  static const _baseUrl = 'https://mastui-api.sanjeev-yadav1201.workers.dev';
  static const _deviceIdKey = 'app_device_id';

  String? _deviceId;

  /// A random per-install device ID for metering and quotas.
  Future<String> resolveDeviceId() async {
    final cached = _deviceId;
    if (cached != null) return cached;

    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_deviceIdKey);
    if (id == null) {
      final random = Random.secure();
      final bytes = List<int>.generate(16, (_) => random.nextInt(256));
      id = base64Url.encode(bytes).replaceAll('=', '');
      await prefs.setString(_deviceIdKey, id);
    }

    _deviceId = id;
    return id;
  }

  static const _maxRetries = 3;

  /// General AI text completion / prompt request
  Future<String> generateText({
    required String prompt,
    String? systemInstruction,
  }) async {
    final deviceId = await resolveDeviceId();
    final appUserId = await RevenueCatService.instance.appUserId();

    for (var attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        final response = await http
            .post(
              Uri.parse('$_baseUrl/ai/generate'),
              headers: {
                'Content-Type': 'application/json',
                'X-Device-Id': deviceId,
                'X-RC-User-Id': ?appUserId,
              },
              body: jsonEncode({
                'prompt': prompt,
                'system': ?systemInstruction,
              }),
            )
            .timeout(const Duration(seconds: 45));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return (data['response'] ?? data['text'] ?? '').toString();
        } else if (response.statusCode == 503 && attempt < _maxRetries - 1) {
          await Future<void>.delayed(Duration(seconds: 2 * (attempt + 1)));
          continue;
        } else {
          final data = jsonDecode(response.body);
          throw CloudflareAiException(
            data['error']?.toString() ?? 'Failed to generate response.',
            statusCode: response.statusCode,
          );
        }
      } on SocketException {
        throw const CloudflareAiException('No internet connection.');
      } on CloudflareAiException {
        rethrow;
      } catch (e) {
        if (attempt == _maxRetries - 1) {
          throw CloudflareAiException('Request timed out. Please try again.');
        }
      }
    }
    throw const CloudflareAiException('Could not connect to Cloudflare AI.');
  }

  /// Vision-based image analysis via Cloudflare AI
  Future<Map<String, dynamic>> analyzeImage({
    required File image,
    Map<String, String>? extraFields,
  }) async {
    final bytes = await image.readAsBytes();
    final mediaType = _detectImageType(bytes, image.path);
    final deviceId = await resolveDeviceId();
    final appUserId = await RevenueCatService.instance.appUserId();

    for (var attempt = 0; attempt < _maxRetries; attempt++) {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/generate-prompt'),
      )
        ..headers['X-Device-Id'] = deviceId
        ..headers.addAll({'X-RC-User-Id': ?appUserId});

      if (extraFields != null) {
        request.fields.addAll(extraFields);
      }

      request.files.add(http.MultipartFile.fromBytes(
        'image',
        bytes,
        filename: image.uri.pathSegments.last,
        contentType: mediaType,
      ));

      final http.Response response;
      try {
        final streamed =
            await request.send().timeout(const Duration(seconds: 60));
        response = await http.Response.fromStream(streamed);
      } on SocketException {
        throw const CloudflareAiException('No internet connection.');
      } catch (_) {
        throw const CloudflareAiException('Request timed out. Please try again.');
      }

      if (response.statusCode == 503 && attempt < _maxRetries - 1) {
        await Future<void>.delayed(Duration(seconds: 2 * (attempt + 1)));
        continue;
      }

      final body = _decodeBody(response.body);
      if (response.statusCode != 200) {
        throw CloudflareAiException(
          body?['error'] as String? ?? 'Cloudflare AI could not process request.',
          statusCode: response.statusCode,
        );
      }

      return body ?? {};
    }

    throw const CloudflareAiException('Could not process image right now.');
  }

  static MediaType _detectImageType(List<int> bytes, String path) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return MediaType('image', 'png');
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return MediaType('image', 'jpeg');
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return MediaType('image', 'webp');
    }
    final lower = path.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return MediaType('image', 'jpeg');
    }
    if (lower.endsWith('.webp')) return MediaType('image', 'webp');
    return MediaType('image', 'png');
  }

  static Map<String, dynamic>? _decodeBody(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}

class CloudflareAiException implements Exception {
  const CloudflareAiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
