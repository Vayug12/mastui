import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Lightweight service to verify email domain validity and active MX (Mail Exchange) records.
/// Uses zero-cost DNS-over-HTTPS (DoH) with zero external credentials and an in-memory cache.
class EmailVerificationService {
  EmailVerificationService._();
  static final instance = EmailVerificationService._();

  // In-memory cache of domain -> isVerified
  final Map<String, bool> _domainCache = {};

  // High-trust mail providers that are guaranteed to have active MX records.
  static const Set<String> _trustedProviders = {
    'gmail.com',
    'googlemail.com',
    'yahoo.com',
    'yahoo.co.in',
    'yahoo.co.uk',
    'outlook.com',
    'hotmail.com',
    'live.com',
    'msn.com',
    'icloud.com',
    'me.com',
    'mac.com',
    'proton.me',
    'protonmail.com',
    'aol.com',
    'zoho.com',
    'zoho.in',
    'yandex.com',
    'rediffmail.com',
    'mail.com',
    'gmx.com',
  };

  /// Returns true if the email domain is known or has active MX records.
  Future<bool> isEmailValid(String email) async {
    final clean = email.trim().toLowerCase();
    if (!clean.contains('@')) return false;

    final parts = clean.split('@');
    if (parts.length != 2 || parts[0].isEmpty || parts[1].isEmpty) {
      return false;
    }

    final domain = parts[1].trim();

    // Fast-path: Common trusted providers (0ms latency)
    if (_trustedProviders.contains(domain)) {
      return true;
    }

    // Check memory cache
    if (_domainCache.containsKey(domain)) {
      return _domainCache[domain]!;
    }

    // Resolve MX record via DNS-over-HTTPS
    final hasMx = await _checkMxRecord(domain);
    _domainCache[domain] = hasMx;
    return hasMx;
  }

  /// Synchronous fast check: returns true if already known or trusted, null if needs async check.
  bool? isTrustedOrCached(String email) {
    final clean = email.trim().toLowerCase();
    if (!clean.contains('@')) return false;
    final parts = clean.split('@');
    if (parts.length != 2) return false;
    final domain = parts[1].trim();

    if (_trustedProviders.contains(domain)) return true;
    return _domainCache[domain];
  }

  Future<bool> _checkMxRecord(String domain) async {
    try {
      // Query Google DNS over HTTPS for MX records (type 15)
      final url = Uri.parse('https://dns.google/resolve?name=${Uri.encodeComponent(domain)}&type=MX');
      final response = await http.get(url).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final status = data['Status'] as int? ?? -1;

        // Status 0 indicates NOERROR
        if (status == 0) {
          final answers = data['Answer'] as List<dynamic>?;
          if (answers != null && answers.isNotEmpty) {
            // Found MX records
            return true;
          }

          // If no explicit MX record, check if domain has an A record (fallback for mail delivery)
          return await _checkARecord(domain);
        }
      }
    } catch (_) {
      // Fallback or network timeout
    }
    return false;
  }

  Future<bool> _checkARecord(String domain) async {
    try {
      final url = Uri.parse('https://dns.google/resolve?name=${Uri.encodeComponent(domain)}&type=A');
      final response = await http.get(url).timeout(const Duration(seconds: 2));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final status = data['Status'] as int? ?? -1;
        final answers = data['Answer'] as List<dynamic>?;
        return status == 0 && (answers != null && answers.isNotEmpty);
      }
    } catch (_) {}
    return false;
  }
}
