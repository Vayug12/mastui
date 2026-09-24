import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Result status of direct SMTP handshake socket probe.
enum SmtpProbeStatus {
  verified, // Mailbox confirmed to exist (250 OK)
  invalid, // Mailbox does not exist (550 / 551 / 553)
  catchAll, // Server accepts any recipient blindly
  unreachable, // Port 25 blocked by ISP/carrier, timeout, or socket error
}

/// Comprehensive B2B work email resolution and verification result.
class B2bEmailResult {
  final String primaryEmail;
  final String domain;
  final String status; // 'verified' | 'mx_valid' | 'predicted'
  final double confidence; // 0.0 to 1.0
  final List<String> alternativePatterns;
  final String? mailProvider; // e.g. 'Google Workspace', 'Microsoft 365'
  final bool isCatchAll;

  const B2bEmailResult({
    required this.primaryEmail,
    required this.domain,
    required this.status,
    required this.confidence,
    this.alternativePatterns = const [],
    this.mailProvider,
    this.isCatchAll = false,
  });

  bool get isVerified => status == 'verified';
  bool get isMxValid => status == 'mx_valid' || status == 'verified';
}

/// Zero-cost, Apollo-style B2B Email Intelligence and SMTP Handshake Service.
///
/// Features:
/// 1. Algorithmic B2B email pattern generation based on person name + domain.
/// 2. Domain & MX record resolution via Google DNS-over-HTTPS (DoH).
/// 3. Mailbox-level SMTP handshake probe on port 25 with catch-all detection.
/// 4. Graceful fallback when port 25 is blocked by mobile cellular or home ISPs.
/// 5. In-memory caching for sub-millisecond responses on repeated domains.
class B2bEmailService {
  B2bEmailService._();
  static final instance = B2bEmailService._();

  // In-memory cache: domain -> List<MxRecordInfo>
  final Map<String, List<MxRecordInfo>> _mxCache = {};

  // In-memory cache: "fullName|domain" -> B2bEmailResult
  final Map<String, B2bEmailResult> _resultCache = {};

  /// Known social/hosting platforms to exclude when resolving company domains
  static const Set<String> _excludedDomains = {
    'linkedin.com',
    'instagram.com',
    'facebook.com',
    'twitter.com',
    'x.com',
    'youtube.com',
    'tiktok.com',
    'linktr.ee',
    'gmail.com',
    'yahoo.com',
    'outlook.com',
    'hotmail.com',
    'icloud.com',
    'google.com',
    'bing.com',
    'duckduckgo.com',
  };

  /// Common corporate suffixes to strip when guessing domains from company names
  static final RegExp _companySuffixRegex = RegExp(
    r'\b(pvt\.?\s*ltd\.?|private\s*limited|ltd\.?|llc|inc\.?|corp\.?|corporation|technologies|tech|solutions|services|group|holdings|enterprises)\b',
    caseSensitive: false,
  );

  /// Titles / honorifics to strip from person names
  static final RegExp _titlePrefixRegex = RegExp(
    r'^(dr\.?|mr\.?|ms\.?|mrs\.?|prof\.?|adv\.?|er\.?|ca\.?)\s+',
    caseSensitive: false,
  );

  // ---------------------------------------------------------------------------
  // 1. Domain Extraction & Inference
  // ---------------------------------------------------------------------------

  /// Extracts the most plausible company domain from available lead information.
  String? extractDomain({
    String? website,
    String? businessName,
    String? bioSnippet,
  }) {
    // 1. Try direct website if available
    if (website != null && website.trim().isNotEmpty) {
      final cleaned = cleanDomain(website);
      if (cleaned != null && !_excludedDomains.contains(cleaned)) {
        return cleaned;
      }
    }

    // 2. Try looking for domain mentions in the bio snippet (e.g. "visit razorpay.com")
    if (bioSnippet != null && bioSnippet.trim().isNotEmpty) {
      final domainMatch = RegExp(
        r'\b([a-zA-Z0-9-]+\.(?:com|in|co|org|io|ai|tech|net|co\.in|xyz))\b',
        caseSensitive: false,
      ).firstMatch(bioSnippet);

      if (domainMatch != null) {
        final found = domainMatch.group(1)?.toLowerCase().trim();
        if (found != null && !_excludedDomains.contains(found)) {
          return found;
        }
      }
    }

    // 3. Infer from business / company name
    if (businessName != null && businessName.trim().isNotEmpty) {
      final inferred = inferDomainFromCompanyName(businessName);
      if (inferred != null) return inferred;
    }

    return null;
  }

  /// Normalizes a URL or domain string into a clean hostname (e.g. `https://www.razorpay.com/about` -> `razorpay.com`).
  String? cleanDomain(String raw) {
    var s = raw.trim().toLowerCase();
    if (s.isEmpty) return null;

    s = s.replaceAll(RegExp(r'^https?:\/\/'), '');
    s = s.replaceAll(RegExp(r'^www\.'), '');
    final slashIndex = s.indexOf('/');
    if (slashIndex != -1) {
      s = s.substring(0, slashIndex);
    }
    final colonIndex = s.indexOf(':');
    if (colonIndex != -1) {
      s = s.substring(0, colonIndex);
    }

    s = s.replaceAll(RegExp(r'[^a-z0-9.-]'), '');
    if (s.contains('.') && s.length >= 4) {
      return s;
    }
    return null;
  }

  /// Infers a corporate domain candidate from a business or company name (e.g. "Razorpay Software" -> "razorpay.com").
  String? inferDomainFromCompanyName(String companyName) {
    var cleaned = companyName.toLowerCase();
    cleaned = cleaned.replaceAll(_companySuffixRegex, '').trim();
    cleaned = cleaned.replaceAll(RegExp(r'[^a-z0-9]'), '');

    if (cleaned.length >= 3) {
      return '$cleaned.com';
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // 2. Email Pattern Generation
  // ---------------------------------------------------------------------------

  /// Generates standard B2B email pattern candidates ranked by industry prevalence.
  List<String> generatePatterns(String fullName, String domain) {
    final cleanName = fullName.replaceAll(_titlePrefixRegex, '').trim().toLowerCase();
    final parts = cleanName
        .split(RegExp(r'[\s._-]+'))
        .where((p) => p.isNotEmpty)
        .map((p) => p.replaceAll(RegExp(r'[^a-z0-9]'), ''))
        .where((p) => p.isNotEmpty)
        .toList();

    if (parts.isEmpty || domain.isEmpty) return [];

    final first = parts.first;
    final last = parts.length > 1 ? parts.last : '';
    final fInitial = first.isNotEmpty ? first[0] : '';
    final lInitial = last.isNotEmpty ? last[0] : '';

    final patterns = <String>[];

    if (last.isNotEmpty) {
      // 1. first.last@domain (Industry standard, ~65%)
      patterns.add('$first.$last@$domain');

      // 2. first@domain (Common for founders/executives, ~20%)
      patterns.add('$first@$domain');

      // 3. flast@domain (Common in enterprise, ~10%)
      patterns.add('$fInitial$last@$domain');

      // 4. first_last@domain
      patterns.add('${first}_$last@$domain');

      // 5. firstlast@domain
      patterns.add('$first$last@$domain');

      // 6. first.l@domain
      if (lInitial.isNotEmpty) {
        patterns.add('$first.$lInitial@$domain');
      }
    } else {
      // Single word name: contact / direct
      patterns.add('$first@$domain');
      patterns.add('contact@$domain');
    }

    return patterns.toSet().toList();
  }

  // ---------------------------------------------------------------------------
  // 3. DNS-over-HTTPS MX Record Resolution
  // ---------------------------------------------------------------------------

  /// Resolves active Mail Exchange (MX) hosts for a domain using Google DNS-over-HTTPS.
  Future<List<MxRecordInfo>> resolveMxHosts(String domain) async {
    final clean = cleanDomain(domain);
    if (clean == null) return [];

    if (_mxCache.containsKey(clean)) {
      return _mxCache[clean]!;
    }

    try {
      final url = Uri.parse('https://dns.google/resolve?name=${Uri.encodeComponent(clean)}&type=MX');
      final response = await http.get(url).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final status = data['Status'] as int? ?? -1;

        if (status == 0) {
          final answers = data['Answer'] as List<dynamic>?;
          if (answers != null && answers.isNotEmpty) {
            final records = <MxRecordInfo>[];

            for (final ans in answers) {
              final rawData = ans['data'] as String?;
              if (rawData == null) continue;

              // Format in Google DoH: "[preference] [host]." e.g. "10 aspmx.l.google.com."
              final parts = rawData.trim().split(RegExp(r'\s+'));
              int pref = 10;
              String host = rawData;

              if (parts.length >= 2) {
                pref = int.tryParse(parts[0]) ?? 10;
                host = parts[1];
              }

              // Strip trailing dot
              if (host.endsWith('.')) {
                host = host.substring(0, host.length - 1);
              }

              records.add(MxRecordInfo(
                host: host.toLowerCase(),
                preference: pref,
                provider: _identifyProvider(host),
              ));
            }

            records.sort((a, b) => a.preference.compareTo(b.preference));
            _mxCache[clean] = records;
            return records;
          }
        }
      }
    } catch (_) {
      // Graceful fallback on network error
    }

    _mxCache[clean] = [];
    return [];
  }

  String _identifyProvider(String mxHost) {
    final lower = mxHost.toLowerCase();
    if (lower.contains('google.com') || lower.contains('googlemail.com') || lower.contains('aspmx')) {
      return 'Google Workspace';
    } else if (lower.contains('outlook.com') || lower.contains('microsoft')) {
      return 'Microsoft 365';
    } else if (lower.contains('zoho.')) {
      return 'Zoho Mail';
    } else if (lower.contains('protonmail') || lower.contains('proton.me')) {
      return 'Proton';
    } else if (lower.contains('mimecast')) {
      return 'Mimecast';
    } else if (lower.contains('barracuda')) {
      return 'Barracuda';
    }
    return 'Corporate Mail Server';
  }

  // ---------------------------------------------------------------------------
  // 4. Direct SMTP Socket Mailbox Probe (Port 25)
  // ---------------------------------------------------------------------------

  /// Attempts a direct SMTP handshake with the mail server on port 25 without sending an email.
  /// Gracefully detects catch-all domains, invalid mailboxes, or blocked port 25.
  Future<SmtpProbeStatus> probeSmtpMailbox(String mxHost, String email, {Duration timeout = const Duration(milliseconds: 2500)}) async {
    if (kIsWeb) {
      return SmtpProbeStatus.unreachable;
    }

    Socket? socket;
    try {
      socket = await Socket.connect(mxHost, 25, timeout: timeout);

      final reader = socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .asBroadcastStream();

      // Helper to read the next complete SMTP response code
      Future<int> readSmtpCode() async {
        await for (final line in reader.timeout(timeout)) {
          final trimmed = line.trim();
          if (trimmed.length >= 3) {
            final code = int.tryParse(trimmed.substring(0, 3));
            // Final line of response has a space after code (e.g. "250 OK" vs "250-SIZE 35882577")
            if (code != null && (trimmed.length == 3 || trimmed[3] == ' ')) {
              return code;
            }
          }
        }
        return -1;
      }

      // 1. Read initial banner (expected 220)
      final bannerCode = await readSmtpCode();
      if (bannerCode != 220) {
        socket.destroy();
        return SmtpProbeStatus.unreachable;
      }

      // 2. HELO checkmail.org
      socket.write('HELO checkmail.org\r\n');
      await socket.flush();
      final heloCode = await readSmtpCode();
      if (heloCode != 250) {
        socket.destroy();
        return SmtpProbeStatus.unreachable;
      }

      // 3. MAIL FROM:<probe@checkmail.org>
      socket.write('MAIL FROM:<probe@checkmail.org>\r\n');
      await socket.flush();
      final mailFromCode = await readSmtpCode();
      if (mailFromCode != 250) {
        socket.destroy();
        return SmtpProbeStatus.unreachable;
      }

      // 4. RCPT TO:<candidateEmail>
      socket.write('RCPT TO:<$email>\r\n');
      await socket.flush();
      final rcptCode = await readSmtpCode();

      if (rcptCode == 250) {
        // 5. Test for Catch-All: Probe a random non-existent mailbox on same domain
        final domain = email.split('@').last;
        final randomProbe = 'check_probe_${DateTime.now().millisecondsSinceEpoch}@$domain';
        socket.write('RCPT TO:<$randomProbe>\r\n');
        await socket.flush();
        final catchAllCode = await readSmtpCode();

        // Send QUIT
        socket.write('QUIT\r\n');
        await socket.flush();
        socket.destroy();

        if (catchAllCode == 250) {
          return SmtpProbeStatus.catchAll;
        }
        return SmtpProbeStatus.verified;
      } else if (rcptCode >= 550 && rcptCode <= 553) {
        socket.write('QUIT\r\n');
        await socket.flush();
        socket.destroy();
        return SmtpProbeStatus.invalid;
      }

      socket.destroy();
      return SmtpProbeStatus.unreachable;
    } catch (_) {
      // Common on cellular data / ISPs that block outgoing port 25
      try {
        socket?.destroy();
      } catch (_) {}
      return SmtpProbeStatus.unreachable;
    }
  }

  // ---------------------------------------------------------------------------
  // 5. Orchestrated B2B Work Email Predictor & Verifier
  // ---------------------------------------------------------------------------

  /// End-to-end B2B work email resolution and verification.
  /// Combines pattern generation, MX validation, and SMTP probing with zero external costs.
  Future<B2bEmailResult?> predictAndVerifyWorkEmail({
    required String fullName,
    String? businessName,
    String? website,
    String? bioSnippet,
  }) async {
    final domain = extractDomain(
      website: website,
      businessName: businessName,
      bioSnippet: bioSnippet,
    );

    if (domain == null) return null;

    final cacheKey = '$fullName|$domain'.toLowerCase();
    if (_resultCache.containsKey(cacheKey)) {
      return _resultCache[cacheKey];
    }

    final patterns = generatePatterns(fullName, domain);
    if (patterns.isEmpty) return null;

    // Resolve MX records
    final mxRecords = await resolveMxHosts(domain);
    final hasMx = mxRecords.isNotEmpty;
    final primaryHost = hasMx ? mxRecords.first.host : null;
    final provider = hasMx ? mxRecords.first.provider : null;

    if (!hasMx) {
      // Domain has no mail server configured
      return null;
    }

    // Default primary pattern is first.last@domain (or first@domain)
    String bestEmail = patterns.first;
    String status = 'mx_valid';
    double confidence = 0.75;
    bool isCatchAll = false;

    // If MX host is available, attempt SMTP probe for the top patterns
    if (primaryHost != null) {
      for (final candidate in patterns.take(2)) {
        final probeStatus = await probeSmtpMailbox(primaryHost, candidate);

        if (probeStatus == SmtpProbeStatus.verified) {
          bestEmail = candidate;
          status = 'verified';
          confidence = 0.98;
          break;
        } else if (probeStatus == SmtpProbeStatus.catchAll) {
          bestEmail = candidate;
          status = 'mx_valid';
          confidence = 0.80;
          isCatchAll = true;
          break;
        } else if (probeStatus == SmtpProbeStatus.invalid) {
          // If first.last was invalid, try next pattern
          continue;
        } else {
          // Port 25 unreachable (typical on mobile/residential ISPs):
          // High-confidence heuristic based on MX provider
          status = 'mx_valid';
          confidence = provider == 'Google Workspace' || provider == 'Microsoft 365' ? 0.85 : 0.75;
          break;
        }
      }
    }

    final altPatterns = patterns.where((p) => p != bestEmail).toList();

    final result = B2bEmailResult(
      primaryEmail: bestEmail,
      domain: domain,
      status: status,
      confidence: confidence,
      alternativePatterns: altPatterns,
      mailProvider: provider,
      isCatchAll: isCatchAll,
    );

    _resultCache[cacheKey] = result;
    return result;
  }
}

/// Simple DTO representing resolved MX record info.
class MxRecordInfo {
  final String host;
  final int preference;
  final String provider;

  const MxRecordInfo({
    required this.host,
    required this.preference,
    required this.provider,
  });
}
