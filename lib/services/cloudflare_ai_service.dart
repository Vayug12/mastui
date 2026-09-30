import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'connection_service.dart';

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

    for (var attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        final response = await http
            .post(
              Uri.parse('$_baseUrl/ai/generate'),
              headers: {
                'Content-Type': 'application/json',
                'X-Device-Id': deviceId,
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
        throw const CloudflareAiException(ConnectionService.offlineMessage);
      } on TimeoutException {
        throw const CloudflareAiException(
          'Slow internet connection or server response. Please try again.',
        );
      } on http.ClientException {
        throw const CloudflareAiException(
          'Unable to connect. Check your internet connection and try again.',
        );
      } on CloudflareAiException {
        rethrow;
      } catch (e) {
        if (attempt == _maxRetries - 1) {
          throw const CloudflareAiException(
            'Could not generate a response. Please try again.',
          );
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

    for (var attempt = 0; attempt < _maxRetries; attempt++) {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/generate-prompt'),
      )..headers['X-Device-Id'] = deviceId;

      if (extraFields != null) {
        request.fields.addAll(extraFields);
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          bytes,
          filename: image.uri.pathSegments.last,
          contentType: mediaType,
        ),
      );

      final http.Response response;
      try {
        response = await request
            .send()
            .then(http.Response.fromStream)
            .timeout(const Duration(seconds: 60));
      } on SocketException {
        throw const CloudflareAiException(ConnectionService.offlineMessage);
      } on TimeoutException {
        throw const CloudflareAiException(
          'Slow internet connection or server response. Please try again.',
        );
      } on http.ClientException {
        throw const CloudflareAiException(
          'Unable to connect. Check your internet connection and try again.',
        );
      } catch (_) {
        throw const CloudflareAiException(
          'Could not process the image. Please try again.',
        );
      }

      if (response.statusCode == 503 && attempt < _maxRetries - 1) {
        await Future<void>.delayed(Duration(seconds: 2 * (attempt + 1)));
        continue;
      }

      final body = _decodeBody(response.body);
      if (response.statusCode != 200) {
        throw CloudflareAiException(
          body?['error'] as String? ??
              'Cloudflare AI could not process request.',
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

  /// LLM-powered entity extraction from raw search results.
  Future<AiLeadEntity?> extractLeadEntity({
    required String rawTitle,
    required String rawSnippet,
    required String platform,
  }) async {
    final prompt =
        '''
Task: Extract structured lead information from the search result.

Platform: $platform
Title: "$rawTitle"
Snippet: "$rawSnippet"

Rules:
1. Output ONLY valid JSON:
{
  "personName": "Real Person Name (or business name if purely an organization)",
  "businessName": "Real Company or Organization Name (or null if not specified)",
  "role": "Job Title/Designation (e.g. CEO, Founder, Managing Director, or null)",
  "domain": "Actual company domain (e.g. zomato.com, razorpay.com) or null",
  "isAuthenticLead": true
}
2. NEVER put generic job titles (CEO, Founder, Director, Owner, Manager, etc.) into "businessName".
3. NEVER guess fake domains like "ceo.com" or "founder.com". Only provide domain if it is a real company or present in the snippet.
''';
    try {
      final res = await generateText(
        prompt: prompt,
        systemInstruction:
            'You are an expert AI Lead Parser. Output only valid JSON.',
      ).timeout(const Duration(seconds: 4));

      final clean = res
          .replaceAll(RegExp(r'```json', caseSensitive: false), '')
          .replaceAll(RegExp(r'```'), '')
          .trim();
      final match = RegExp(r'\{[\s\S]*\}').firstMatch(clean);
      if (match != null) {
        final data = jsonDecode(match.group(0)!) as Map<String, dynamic>;
        final person = (data['personName'] as String?)?.trim();
        final biz = (data['businessName'] as String?)?.trim();
        final role = (data['role'] as String?)?.trim();
        final domain = (data['domain'] as String?)?.trim();
        final isValid = data['isAuthenticLead'] == true;

        if (person != null && person.isNotEmpty) {
          return AiLeadEntity(
            personName: person,
            businessName:
                (biz != null && biz.isNotEmpty && biz.toLowerCase() != 'null')
                ? biz
                : null,
            role:
                (role != null &&
                    role.isNotEmpty &&
                    role.toLowerCase() != 'null')
                ? role
                : null,
            domain:
                (domain != null &&
                    domain.isNotEmpty &&
                    domain.toLowerCase() != 'null' &&
                    domain.contains('.'))
                ? domain
                : null,
            isAuthenticLead: isValid,
          );
        }
      }
    } catch (_) {}
    return null;
  }

  /// LLM-powered Decision Maker Verification to prevent cross-company hallucinations.
  Future<AiDecisionMakerVerification?> verifyDecisionMaker({
    required String targetBusiness,
    required String leadName,
    required String? location,
    required String candidateTitle,
    required String candidateSnippet,
  }) async {
    final prompt =
        '''
Task: Cross-verify if the candidate profile is genuinely the Founder, CEO, Owner, or top Decision Maker of the specific target business.

Target Business: "$targetBusiness"
Lead Name: "$leadName"
Location: "${location ?? 'N/A'}"
Candidate Title: "$candidateTitle"
Candidate Snippet: "$candidateSnippet"

Rules:
1. Output ONLY valid JSON:
{
  "isMatch": true,
  "name": "Clean Person Name (strip Dr./Mr./emojis)",
  "role": "Role Title (e.g. Co-Founder & CEO)",
  "domain": "Verified company domain or null",
  "confidence": 0.0 to 1.0,
  "reason": "Short reason"
}
2. isMatch MUST be true ONLY IF the candidate is directly associated with "$targetBusiness".
3. If candidate is from an UNRELATED company (e.g. searching for a fintech company but candidate is Ather Energy founder), isMatch MUST be false.
4. If uncertain or generic, set isMatch: false.
''';
    try {
      final res = await generateText(
        prompt: prompt,
        systemInstruction:
            'You are a strict data verification engine. Output only valid JSON.',
      ).timeout(const Duration(seconds: 4));

      final clean = res
          .replaceAll(RegExp(r'```json', caseSensitive: false), '')
          .replaceAll(RegExp(r'```'), '')
          .trim();
      final match = RegExp(r'\{[\s\S]*\}').firstMatch(clean);
      if (match != null) {
        final data = jsonDecode(match.group(0)!) as Map<String, dynamic>;
        final isMatch = data['isMatch'] == true;
        final conf =
            (data['confidence'] as num?)?.toDouble() ?? (isMatch ? 0.9 : 0.0);
        final name = (data['name'] as String?)?.trim() ?? '';
        final role = (data['role'] as String?)?.trim() ?? 'Founder & CEO';
        final domain = (data['domain'] as String?)?.trim();

        return AiDecisionMakerVerification(
          isMatch: isMatch && conf >= 0.70 && name.length >= 2,
          name: name,
          role: role,
          domain:
              (domain != null &&
                  domain.isNotEmpty &&
                  domain.toLowerCase() != 'null' &&
                  domain.contains('.'))
              ? domain
              : null,
          confidence: conf,
        );
      }
    } catch (_) {}
    return null;
  }

  /// LLM-powered verification of extracted email and phone numbers against source snippet.
  /// Eliminates sentences parsed as emails ("us at mybrand.com"), prices/pincodes parsed as phones,
  /// and generic platform boilerplate ("support@instagram.com").
  Future<AiContactVerification?> verifyContactDetails({
    required String leadName,
    required String? businessName,
    required String snippet,
    String? candidateEmail,
    String? candidatePhone,
  }) async {
    final hasCandidateEmail =
        candidateEmail != null && candidateEmail.trim().isNotEmpty;
    final hasCandidatePhone =
        candidatePhone != null && candidatePhone.trim().isNotEmpty;

    if (!hasCandidateEmail && !hasCandidatePhone) {
      return null;
    }

    final prompt =
        '''
Task: Cross-verify if the candidate email and phone number genuinely belong to the lead/business based strictly on the search snippet text.

Lead Name: "$leadName"
Business: "${businessName ?? 'N/A'}"
Snippet: "$snippet"
Candidate Email: "${candidateEmail ?? 'None'}"
Candidate Phone: "${candidatePhone ?? 'None'}"

Rules:
1. Output ONLY valid JSON:
{
  "isEmailValid": true/false,
  "isPhoneValid": true/false,
  "verifiedEmail": "extracted valid email or null",
  "verifiedPhone": "extracted valid phone or null"
}
2. Email is INVALID if:
   - It is a natural language sentence misread as an email (e.g. "us@store.com", "at@brand.com").
   - It is a platform support/generic address (e.g. support@instagram.com, info@facebook.com, noreply@..., abuse@...).
   - It is a placeholder (e.g. example.com, test.com).
   - It is NOT explicitly mentioned or intended for this business in the snippet.
3. Phone is INVALID if:
   - It is a price (e.g. 50000, 1500), pincode (e.g. 110001), year/date, order number, or follower count.
   - It is NOT a genuine calling/mobile/WhatsApp number for the lead.
4. If invalid, set the respective is*Valid to false and verified* to null.
''';

    try {
      final res = await generateText(
        prompt: prompt,
        systemInstruction:
            'You are a strict data verification engine. Output only valid JSON.',
      ).timeout(const Duration(seconds: 4));

      final clean = res
          .replaceAll(RegExp(r'```json', caseSensitive: false), '')
          .replaceAll(RegExp(r'```'), '')
          .trim();
      final match = RegExp(r'\{[\s\S]*\}').firstMatch(clean);
      if (match != null) {
        final data = jsonDecode(match.group(0)!) as Map<String, dynamic>;
        final isEmailValid = data['isEmailValid'] == true;
        final isPhoneValid = data['isPhoneValid'] == true;
        final vEmail = (data['verifiedEmail'] as String?)?.trim();
        final vPhone = (data['verifiedPhone'] as String?)?.trim();

        return AiContactVerification(
          isEmailValid: isEmailValid && vEmail != null && vEmail.isNotEmpty,
          isPhoneValid: isPhoneValid && vPhone != null && vPhone.isNotEmpty,
          verifiedEmail: isEmailValid ? vEmail : null,
          verifiedPhone: isPhoneValid ? vPhone : null,
        );
      }
    } catch (_) {
      // Graceful fallback to regex heuristics if AI request fails or times out
    }
    return null;
  }
}

/// Structured contact verification result from LLM.
class AiContactVerification {
  final bool isEmailValid;
  final bool isPhoneValid;
  final String? verifiedEmail;
  final String? verifiedPhone;

  const AiContactVerification({
    this.isEmailValid = false,
    this.isPhoneValid = false,
    this.verifiedEmail,
    this.verifiedPhone,
  });
}

/// Structured entity extraction result from LLM.
class AiLeadEntity {
  final String personName;
  final String? businessName;
  final String? role;
  final String? domain;
  final bool isAuthenticLead;

  const AiLeadEntity({
    required this.personName,
    this.businessName,
    this.role,
    this.domain,
    this.isAuthenticLead = true,
  });
}

/// Structured decision-maker verification result from LLM.
class AiDecisionMakerVerification {
  final bool isMatch;
  final String name;
  final String role;
  final String? domain;
  final double confidence;

  const AiDecisionMakerVerification({
    required this.isMatch,
    required this.name,
    required this.role,
    this.domain,
    this.confidence = 0.0,
  });
}

class CloudflareAiException implements Exception {
  const CloudflareAiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
