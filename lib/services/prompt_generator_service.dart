import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'revenue_cat_service.dart';

/// Turns a screenshot the user picked into a ready-to-paste prompt by way of
/// the Worker's vision model.
class PromptGeneratorService {
  PromptGeneratorService._();
  static final instance = PromptGeneratorService._();

  static const _baseUrl = 'https://mastui-api.sanjeev-yadav1201.workers.dev';
  static const _deviceIdKey = 'mastui_device_id';

  String? _deviceId;

  /// A random per-install id. It only exists so the Worker can meter its
  /// shared daily allowance per device — nothing about the user is stored.
  Future<String> _resolveDeviceId() async {
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

  Future<GeneratedPrompt> generate({
    required File image,
    required String platform,
  }) async {
    final bytes = await image.readAsBytes();
    final mediaType = _detectImageType(bytes, image.path);

    for (var attempt = 0; attempt < _maxRetries; attempt++) {
      // The Worker verifies this id against RevenueCat itself, so a spoofed
      // one buys nothing — it is only a lookup key, never a claim of Pro.
      final appUserId = await RevenueCatService.instance.appUserId();

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/generate-prompt'),
      )
        ..headers['X-Device-Id'] = await _resolveDeviceId()
        ..headers.addAll({'X-RC-User-Id': ?appUserId})
        ..fields['platform'] = platform
        ..files.add(http.MultipartFile.fromBytes(
          'image',
          bytes,
          filename: image.uri.pathSegments.last,
          contentType: mediaType,
        ));

      final http.Response response;
      try {
        final streamed = await request.send().timeout(const Duration(seconds: 60));
        response = await http.Response.fromStream(streamed);
      } on SocketException {
        throw const PromptGenerationException('No internet connection.');
      } catch (_) {
        throw const PromptGenerationException(
          'That took too long. Please try again.',
        );
      }

      // Retry on 503 (model busy) with exponential back-off.
      if (response.statusCode == 503 && attempt < _maxRetries - 1) {
        await Future<void>.delayed(Duration(seconds: 2 * (attempt + 1)));
        continue;
      }

      final body = _decodeBody(response.body);
      if (response.statusCode != 200) {
        throw PromptGenerationException(
          body?['error'] as String? ?? 'Could not generate a prompt right now.',
          isQuotaExhausted: response.statusCode == 429,
          // Only true when Pro would actually raise the cap — an exhausted
          // account-wide AI budget blocks everyone equally.
          canUpgrade: body?['upgradeAvailable'] as bool? ?? false,
        );
      }

      final prompt = body?['prompt'] as String?;
      if (prompt == null || prompt.isEmpty) {
        throw const PromptGenerationException(
          'Could not read that screenshot. Try a clearer one.',
        );
      }

      return GeneratedPrompt(
        prompt: prompt,
        styleName: body?['styleName'] as String?,
        remaining: body?['remaining'] as int? ?? 0,
        isPro: body?['isPro'] as bool? ?? false,
      );
    }

    throw const PromptGenerationException(
      'Prompt generation is busy right now. Please try again later.',
    );
  }

  Map<String, dynamic>? _decodeBody(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Inspects the first bytes to determine the real image format, regardless
  /// of the file extension (which may be wrong after picker compression).
  MediaType _detectImageType(List<int> bytes, String path) {
    if (bytes.length >= 4) {
      // PNG  magic: 89 50 4E 47
      if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
        return MediaType('image', 'png');
      }
      // JPEG magic: FF D8 FF
      if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
        return MediaType('image', 'jpeg');
      }
      // WebP  magic: 52 49 46 46 … 57 45 42 50
      if (bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 &&
          bytes.length >= 12 && bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50) {
        return MediaType('image', 'webp');
      }
    }

    // Fallback: trust the file extension.
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'png':
        return MediaType('image', 'png');
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'webp':
        return MediaType('image', 'webp');
      default:
        return MediaType('image', 'png');
    }
  }
}

class GeneratedPrompt {
  const GeneratedPrompt({
    required this.prompt,
    required this.remaining,
    this.isPro = false,
    this.styleName,
  });

  final String prompt;
  final String? styleName;

  /// Generations the device has left today.
  final int remaining;

  /// As resolved by the Worker against RevenueCat — the authoritative answer.
  final bool isPro;
}

class PromptGenerationException implements Exception {
  const PromptGenerationException(
    this.message, {
    this.isQuotaExhausted = false,
    this.canUpgrade = false,
  });

  final String message;
  final bool isQuotaExhausted;

  /// True only when buying Pro would lift this particular block.
  final bool canUpgrade;

  @override
  String toString() => message;
}
