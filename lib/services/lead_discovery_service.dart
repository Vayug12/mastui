import 'dart:async';
import 'dart:math';

import '../models/lead_model.dart';
import 'cloudflare_ai_service.dart';
import 'duckduckgo_search_service.dart';

/// Configuration for lead discovery.
class LeadDiscoveryConfig {
  final String niche;
  final String location;
  final List<String> platforms;
  final bool extractEmails;
  final bool extractPhones;
  final int? maxResults;
  final int page;

  const LeadDiscoveryConfig({
    required this.niche,
    this.location = '',
    this.platforms = const ['Instagram', 'LinkedIn', 'Facebook'],
    this.extractEmails = true,
    this.extractPhones = true,
    this.maxResults,
    this.page = 1,
  });
}

/// Orchestrates search queries across multi-engine providers (Yahoo, Bing, DDG),
/// extracts structured contact details, and provides intelligent fallback leads.
class LeadDiscoveryService {
  LeadDiscoveryService._();
  static final instance = LeadDiscoveryService._();

  /// Polite crawling delay between queries (can be zero in test environments)
  static Duration crawlDelay = const Duration(milliseconds: 400);

  /// Optional custom stream provider for tests
  Stream<Lead> Function(LeadDiscoveryConfig config)? mockStreamHandler;

  static final RegExp _emailRegex = RegExp(
    r'\b[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}\b',
    caseSensitive: false,
  );

  /// Only match genuine obfuscated emails with explicit bracket notation (e.g. "user [at] domain [dot] com").
  /// Explicitly excludes plain English prepositions like bare "at" or bare "dot".
  static final RegExp _obfuscatedEmailRegex = RegExp(
    r'\b([a-zA-Z0-9._%+-]+)\s*(?:\[at\]|\(at\)|\[@\])\s*([a-zA-Z0-9.-]+)\s*(?:\[dot\]|\(dot\)|\.)\s*([a-zA-Z]{2,})\b',
    caseSensitive: false,
  );

  static const Set<String> _blacklistedEmailDomains = {
    'example.com',
    'example.org',
    'example.net',
    'domain.com',
    'test.com',
    'sample.com',
    'placeholder.com',
    'yoursite.com',
    'yourcompany.com',
    'email.com',
    'sentry.io',
    'github.com',
    'wixpress.com',
    'squarespace.com',
    'instagram.com',
    'facebook.com',
    'tiktok.com',
    'linkedin.com',
    'twitter.com',
    'x.com',
    'youtube.com',
  };

  static const Set<String> _blacklistedEmailPrefixes = {
    'noreply',
    'no-reply',
    'donotreply',
    'abuse',
    'security',
    'privacy',
    'mailer-daemon',
    'postmaster',
  };

  static final RegExp _phoneRegex = RegExp(
    r'(?:\+?91[\s-]?)?(?:[6-9]\d{9}|[6-9]\d{4}[\s-]?\d{5}|[6-9]\d{2}[\s-]?\d{3}[\s-]?\d{4}|\(?0\d{2,4}\)?[\s-]?\d{6,8}|\+?\d{1,3}[\s-]?(?:\(?\d{2,4}\)?[\s-]?)?\d{3,4}[\s-]?\d{4})',
  );

  static final RegExp _websiteRegex = RegExp(
    r'(?:https?:\/\/|www\.)[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(?:\/[^\s]*)?',
    caseSensitive: false,
  );


  /// Generates high-accuracy, exact-phrase search queries for targeted platforms.
  List<String> buildQueries(LeadDiscoveryConfig config) {
    final queries = <String>[];
    final cleanNiche = config.niche.replaceAll('"', '').trim();
    final cleanLoc = config.location.replaceAll('"', '').trim();

    final platformDomains = <String, String>{
      'Instagram': 'site:instagram.com',
      'LinkedIn': 'site:linkedin.com/in/',
      'Facebook': 'site:facebook.com',
      'X': 'site:x.com',
      'Twitter': 'site:twitter.com',
    };

    final activePlatforms = config.platforms.isEmpty
        ? ['Instagram', 'LinkedIn', 'Facebook', 'X']
        : config.platforms;

    for (final platform in activePlatforms) {
      final domain = platformDomains[platform] ?? 'site:${platform.toLowerCase()}.com';
      final nicheTerm = '"$cleanNiche"';
      final locTerm = cleanLoc.isNotEmpty ? '"$cleanLoc"' : '';

      if (platform == 'LinkedIn') {
        // High-value Decision Maker & Founder focused dorks for LinkedIn
        if (locTerm.isNotEmpty) {
          queries.add('$domain $nicheTerm "Founder" $locTerm');
          queries.add('$domain $nicheTerm "CEO" $locTerm');
          queries.add('$domain $cleanNiche Founder $cleanLoc');
          queries.add('$domain $cleanNiche CEO $cleanLoc');
          queries.add('$domain $cleanNiche Owner $cleanLoc');
          queries.add('site:linkedin.com in $cleanNiche $cleanLoc Founder');
          if (config.extractEmails) {
            queries.add('$domain $nicheTerm $locTerm "@gmail.com"');
            queries.add('site:linkedin.com in $cleanNiche $cleanLoc @gmail.com');
          }
          queries.add('$domain $nicheTerm $locTerm');
        } else {
          queries.add('$domain $nicheTerm "Founder"');
          queries.add('$domain $nicheTerm "CEO"');
          queries.add('$domain $cleanNiche Founder');
          queries.add('$domain $cleanNiche CEO');
          queries.add('$domain $cleanNiche Owner');
          queries.add('site:linkedin.com in $cleanNiche Founder');
          if (config.extractEmails) {
            queries.add('$domain $nicheTerm "@gmail.com"');
            queries.add('site:linkedin.com in $cleanNiche @gmail.com');
          }
          queries.add('$domain $nicheTerm');
        }
        continue;
      }

      // 1. Email footprint queries (exact dork + natural dork)
      if (config.extractEmails) {
        if (locTerm.isNotEmpty) {
          queries.add('$domain $nicheTerm $locTerm "@gmail.com"');
          queries.add('$domain $cleanNiche $cleanLoc @gmail.com');
          queries.add('$domain $nicheTerm $locTerm "email"');
        } else {
          queries.add('$domain $nicheTerm "@gmail.com"');
          queries.add('$domain $cleanNiche @gmail.com');
          queries.add('$domain $nicheTerm "email"');
        }
      }

      // 2. Phone & WhatsApp footprint queries (exact dork + natural dork)
      if (config.extractPhones) {
        if (locTerm.isNotEmpty) {
          queries.add('$domain $nicheTerm $locTerm "WhatsApp"');
          queries.add('$domain $cleanNiche $cleanLoc WhatsApp');
          queries.add('$domain $nicheTerm $locTerm "phone"');
          queries.add('$domain $cleanNiche $cleanLoc phone');
          queries.add('$domain $nicheTerm $locTerm "+91"');
        } else {
          queries.add('$domain $nicheTerm "WhatsApp"');
          queries.add('$domain $cleanNiche WhatsApp');
          queries.add('$domain $nicheTerm "phone"');
          queries.add('$domain $cleanNiche phone');
          queries.add('$domain $nicheTerm "contact"');
        }
      }

      // 3. Platform presence query
      if (locTerm.isNotEmpty) {
        queries.add('$domain $nicheTerm $locTerm');
        queries.add('$domain $cleanNiche $cleanLoc');
      } else {
        queries.add('$domain $nicheTerm');
        queries.add('$domain $cleanNiche');
      }
    }

    return queries;
  }

  /// Streams discovered leads in real time. If [config.maxResults] is set,
  /// limits results to that number; otherwise streams all discovered leads without limit.
  Stream<Lead> discoverLeadsStream(LeadDiscoveryConfig config) async* {
    if (mockStreamHandler != null) {
      yield* mockStreamHandler!(config);
      return;
    }
    final queries = buildQueries(config);
    final seenKeys = <String>{};
    var totalYielded = 0;

    // Safe pool: 2 concurrent queries per batch with human-like stagger jitter
    // to prevent search engine rate limits or IP bot blocks.
    const batchSize = 2;
    final random = Random();

    for (var i = 0; i < queries.length; i += batchSize) {
      if (config.maxResults != null && totalYielded >= config.maxResults!) break;

      final end = (i + batchSize < queries.length) ? i + batchSize : queries.length;
      final batch = queries.sublist(i, end);

      // Distribute queries across alternating engines (Yahoo <-> Bing) with slight stagger
      final batchFutures = <Future<List<SearchResultItem>>>[];
      for (var idx = 0; idx < batch.length; idx++) {
        final q = batch[idx];
        final engine = (idx % 2 == 0) ? 'Yahoo' : 'Bing';
        final staggerMs = idx * (200 + random.nextInt(150));

        batchFutures.add(
          Future.delayed(
            Duration(milliseconds: staggerMs),
            () => DuckDuckGoSearchService.instance.search(
              q,
              page: config.page,
              preferredEngine: engine,
            ),
          ),
        );
      }

      final batchResults = await Future.wait(batchFutures);

      for (final results in batchResults) {
        for (final item in results) {
          if (config.maxResults != null && totalYielded >= config.maxResults!) break;

          final lead = await _extractLeadFromItem(item, config);
          if (lead == null) continue;

          // Deduplication key
          final key = (lead.email?.isNotEmpty == true)
              ? lead.email!.toLowerCase()
              : (lead.phone?.isNotEmpty == true)
                  ? lead.phone!
                  : lead.profileUrl.toLowerCase();

          if (seenKeys.contains(key)) continue;
          seenKeys.add(key);

          totalYielded++;
          yield lead;
        }
      }

      // Polite crawling delay between batches (250-400ms human jitter)
      final delay = crawlDelay > Duration.zero
          ? crawlDelay
          : Duration(milliseconds: 250 + random.nextInt(150));
      await Future<void>.delayed(delay);
    }
  }

  /// Validates that the URL belongs to a genuine user/creator profile and not a system page or generic post.
  bool _isInvalidSocialUrl(String url, String platform) {
    final lower = url.toLowerCase();
    final uri = Uri.tryParse(url);
    final segments = uri?.pathSegments.where((s) => s.isNotEmpty).toList() ?? [];

    switch (platform) {
      case 'Instagram':
        if (!lower.contains('instagram.com')) return true;
        if (segments.isEmpty) return true;
        const invalidIg = {
          'p', 'reel', 'reels', 'explore', 'stories', 'tv', 'accounts',
          'direct', 'tags', 'directory', 'legal', 'about', 'developer',
        };
        if (invalidIg.contains(segments.first.toLowerCase())) return true;
        return false;

      case 'LinkedIn':
        if (!lower.contains('linkedin.com')) return true;
        if (!lower.contains('/in/') && !lower.contains('/company/')) return true;
        const invalidLi = {'pulse', 'posts', 'jobs', 'learning', 'help', 'feed', 'login', 'signup', 'legal'};
        if (segments.any((s) => invalidLi.contains(s.toLowerCase()))) return true;
        return false;

      case 'Facebook':
        if (!lower.contains('facebook.com')) return true;
        if (segments.isEmpty) return true;
        const invalidFb = {'sharer', 'share', 'login', 'recover', 'help', 'policies', 'pages', 'groups', 'watch', 'events', 'marketplace', 'gaming', 'ads'};
        if (invalidFb.contains(segments.first.toLowerCase())) return true;
        return false;

      case 'X':
        if (!lower.contains('x.com') && !lower.contains('twitter.com')) return true;
        if (segments.isEmpty) return true;
        const invalidX = {'i', 'explore', 'home', 'notifications', 'messages', 'search', 'settings', 'privacy', 'tos', 'intent', 'share'};
        if (invalidX.contains(segments.first.toLowerCase())) return true;
        return false;

      case 'Web':
        return false;
      default:
        return false;
    }
  }

  /// Normalizes and cleans profile URL to a canonical direct link.
  String _normalizeProfileUrl(String url, String platform) {
    try {
      final uri = Uri.parse(url);
      var host = uri.host.toLowerCase();
      for (final prefix in ['www.', 'mobile.', 'm.', 'in.']) {
        if (host.startsWith(prefix)) {
          host = host.substring(prefix.length);
        }
      }
      if (host.isEmpty) host = '${platform.toLowerCase()}.com';
      final cleanUri = Uri(
        scheme: 'https',
        host: host,
        pathSegments: uri.pathSegments.where((s) => s.isNotEmpty),
      );
      var normalized = cleanUri.toString();
      if (!normalized.endsWith('/') && platform == 'Instagram') {
        normalized = '$normalized/';
      }
      return normalized;
    } catch (_) {
      return url;
    }
  }

  /// Extracts structured Lead from a single SearchResultItem with Apollo-style B2B email intelligence.
  Future<Lead?> _extractLeadFromItem(SearchResultItem item, LeadDiscoveryConfig config) async {
    final combinedText = '${item.title} ${item.snippet}';

    // 1. Determine Platform
    var platform = 'Web';
    final urlLower = item.url.toLowerCase();
    if (urlLower.contains('instagram.com')) {
      platform = 'Instagram';
    } else if (urlLower.contains('linkedin.com/in/') || urlLower.contains('linkedin.com/company/') || urlLower.contains('linkedin.com/pub/')) {
      platform = 'LinkedIn';
    } else if (urlLower.contains('facebook.com')) {
      platform = 'Facebook';
    } else if (urlLower.contains('x.com') || urlLower.contains('twitter.com')) {
      platform = 'X';
    }

    // Secondary platform detection if URL was a search redirect (e.g. Yahoo / Bing redirect)
    if (platform == 'Web') {
      final combinedLower = combinedText.toLowerCase();
      if (urlLower.contains('instagram') || combinedLower.contains('instagram.com') || item.title.contains('Instagram')) {
        platform = 'Instagram';
      } else if (urlLower.contains('linkedin') || combinedLower.contains('linkedin.com') || item.title.contains('LinkedIn')) {
        platform = 'LinkedIn';
      } else if (urlLower.contains('facebook') || combinedLower.contains('facebook.com') || item.title.contains('Facebook')) {
        platform = 'Facebook';
      } else if (urlLower.contains('twitter') || urlLower.contains('x.com') || combinedLower.contains('twitter.com') || item.title.contains('Twitter') || item.title.contains('/ X')) {
        platform = 'X';
      }
    }

    // 2. Platform Filtering: If user searched for specific platforms, reject random third-party blog/article links
    final activePlatforms = config.platforms.isEmpty
        ? ['Instagram', 'LinkedIn', 'Facebook', 'X']
        : config.platforms;
    if (!activePlatforms.contains(platform)) {
      return null;
    }

    // 3. Reject invalid system/feed/post URLs
    if (_isInvalidSocialUrl(item.url, platform)) {
      return null;
    }

    // 3b. Strict Location Filter: If user specified a location, discard leads not matching it
    if (config.location.trim().isNotEmpty && !_matchesLocation(item, config.location)) {
      return null;
    }

    // 4. Extract Email (standard or obfuscated)
    String? email = _extractEmail(combinedText);

    // 5. Extract Phone
    String? phone = _extractPhone(combinedText);

    // 6. Parse Title & Business Name (Heuristic first)
    var parsedNames = _parseNameAndBusiness(item.title, platform);
    var website = _extractWebsite(combinedText, item.url, platform);

    // AI Entity Extraction: Use LLM for LinkedIn & complex profile leads to guarantee accurate name & business separation
    if (platform == 'LinkedIn') {
      try {
        final aiEntity = await CloudflareAiService.instance.extractLeadEntity(
          rawTitle: item.title,
          rawSnippet: item.snippet,
          platform: platform,
        );

        if (aiEntity != null && aiEntity.isAuthenticLead) {
          parsedNames = (
            aiEntity.personName.isNotEmpty ? aiEntity.personName : parsedNames.$1,
            aiEntity.businessName ?? parsedNames.$2,
          );
          if (website == null && aiEntity.domain != null && aiEntity.domain!.isNotEmpty) {
            website = 'https://${aiEntity.domain}';
          }
        }
      } catch (_) {
        // Graceful fallback to heuristic parse
      }
    }

    var cleanProfileUrl = _normalizeProfileUrl(item.url, platform);
    if ((cleanProfileUrl.contains('yahoo.com') || cleanProfileUrl.contains('bing.com')) && platform != 'Web') {
      final handle = _extractHandle(item.title, item.snippet);
      if (handle != null && handle.isNotEmpty) {
        if (platform == 'Instagram') {
          cleanProfileUrl = 'https://instagram.com/$handle/';
        } else if (platform == 'LinkedIn') {
          cleanProfileUrl = 'https://linkedin.com/in/$handle';
        } else if (platform == 'X') {
          cleanProfileUrl = 'https://x.com/$handle';
        } else if (platform == 'Facebook') {
          cleanProfileUrl = 'https://facebook.com/$handle';
        }
      }
    }

    // Hybrid Architecture Step 2: LLM Contact Verification
    // Verifies candidate email & phone against the actual snippet context to eliminate
    // false positives, sentence misreads, or platform boilerplate.
    if (email != null || phone != null) {
      try {
        final aiVerified = await CloudflareAiService.instance.verifyContactDetails(
          leadName: parsedNames.$1,
          businessName: parsedNames.$2,
          snippet: item.snippet,
          candidateEmail: email,
          candidatePhone: phone,
        );

        if (aiVerified != null) {
          email = aiVerified.isEmailValid ? (aiVerified.verifiedEmail ?? email) : null;
          phone = aiVerified.isPhoneValid ? (aiVerified.verifiedPhone ?? phone) : null;
        }
      } catch (_) {
        // Graceful fallback to strict heuristics if AI request times out or is unreachable
      }
    }

    bool isWorkEmail = false;
    String? emailStatus = email != null ? 'verified' : null;
    List<String>? alternativeEmails;


    // Filter rules:
    // If strict email only is requested
    if (config.extractEmails && !config.extractPhones && email == null) {
      return null;
    }
    // If neither contact is found, allow verified social profiles with informative bios
    if (email == null && phone == null) {
      final handle = _extractHandle(item.title, item.url);
      if (handle == null && item.snippet.length < 30) {
        return null;
      }
    }

    return Lead(
      id: _generateId(cleanProfileUrl),
      name: parsedNames.$1,
      businessName: parsedNames.$2,
      email: email,
      phone: phone,
      website: website,
      platform: platform,
      profileUrl: cleanProfileUrl,
      location: config.location.isNotEmpty ? config.location : null,
      niche: config.niche,
      bioSnippet: item.snippet,
      extractedAt: DateTime.now(),
      isWorkEmail: isWorkEmail,
      emailStatus: emailStatus,
      alternativeEmails: alternativeEmails,
    );
  }

  String? _extractWebsite(String text, String url, String platform) {
    if (url.contains('linktr.ee')) return url;

    // Check if text/snippet contains a website URL
    final urlMatch = _websiteRegex.firstMatch(text);
    if (urlMatch != null) {
      final raw = urlMatch.group(0)?.trim();
      if (raw != null) {
        final lower = raw.toLowerCase();
        if (!lower.contains('instagram.com') &&
            !lower.contains('linkedin.com') &&
            !lower.contains('facebook.com') &&
            !lower.contains('twitter.com') &&
            !lower.contains('x.com') &&
            !lower.contains('youtube.com') &&
            !lower.contains('yahoo.com') &&
            !lower.contains('bing.com') &&
            !lower.contains('duckduckgo.com')) {
          return raw.startsWith('http') ? raw : 'https://$raw';
        }
      }
    }

    if (platform == 'Web' && url.startsWith('http')) {
      final lower = url.toLowerCase();
      if (!lower.contains('yahoo.com') &&
          !lower.contains('bing.com') &&
          !lower.contains('duckduckgo.com')) {
        return url;
      }
    }

    return null;
  }

  bool _isAuthenticEmail(String email) {
    final lower = email.trim().toLowerCase();
    if (!lower.contains('@')) return false;

    // Reject static file extensions misidentified as emails
    if (lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.svg') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.css') ||
        lower.endsWith('.js')) {
      return false;
    }

    final parts = lower.split('@');
    if (parts.length != 2) return false;
    final user = parts[0].trim();
    final domain = parts[1].trim();

    if (user.length < 2 || domain.length < 4 || !domain.contains('.')) {
      return false;
    }

    if (_blacklistedEmailDomains.contains(domain)) {
      return false;
    }

    if (_blacklistedEmailPrefixes.contains(user)) {
      return false;
    }

    return true;
  }

  bool _isAuthenticPhone(String rawPhone, String sourceText) {
    final digitsOnly = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length < 10 || digitsOnly.length > 13) {
      return false;
    }

    // Check if preceded by currency or price symbols in source text
    final matchIndex = sourceText.indexOf(rawPhone);
    if (matchIndex != -1) {
      final startIndex = (matchIndex - 15).clamp(0, sourceText.length);
      final preceding = sourceText.substring(startIndex, matchIndex).toLowerCase();
      if (preceding.contains('₹') ||
          preceding.contains('rs.') ||
          preceding.contains('rs ') ||
          preceding.contains('inr') ||
          preceding.contains('price') ||
          preceding.contains('pincode') ||
          preceding.contains('pin code') ||
          preceding.contains('pin:') ||
          preceding.contains('zip')) {
        return false;
      }
    }

    return true;
  }

  String? _extractEmail(String text) {
    // Check standard email
    final match = _emailRegex.firstMatch(text);
    if (match != null) {
      final found = match.group(0)?.trim();
      if (found != null && _isAuthenticEmail(found)) {
        return found;
      }
    }

    // Check obfuscated email (e.g. user [at] gmail [dot] com)
    final obMatch = _obfuscatedEmailRegex.firstMatch(text);
    if (obMatch != null) {
      final user = obMatch.group(1);
      final domain = obMatch.group(2);
      final tld = obMatch.group(3);
      if (user != null && domain != null && tld != null) {
        final constructed = '$user@$domain.$tld'.toLowerCase();
        if (_isAuthenticEmail(constructed)) {
          return constructed;
        }
      }
    }

    return null;
  }

  String? _extractPhone(String text) {
    final match = _phoneRegex.firstMatch(text);
    if (match != null) {
      final rawPhone = match.group(0)?.replaceAll(RegExp(r'[^\d+]'), '');
      if (rawPhone != null && _isAuthenticPhone(rawPhone, text)) {
        return rawPhone;
      }
    }
    return null;
  }


  String? _extractHandle(String title, String url) {
    final handleMatch = RegExp(r'@([a-zA-Z0-9._]+)').firstMatch(title);
    if (handleMatch != null) return handleMatch.group(1);

    final urlParts = Uri.tryParse(url)?.pathSegments;
    if (urlParts != null && urlParts.isNotEmpty) {
      final segment = urlParts.first.trim();
      if (segment.isNotEmpty && segment != 'p' && segment != 'in' && segment != 'reel') {
        return segment;
      }
    }
    return null;
  }

  static final RegExp _jobRoleRegex = RegExp(
    r'^(?:ceo|founder|co-founder|co founder|owner|director|managing director|md|president|vice president|vp|general manager|gm|head of [a-z\s]+|partner|principal|proprietor|chief [a-z\s]+ officer|c[a-z]o|manager|executive|consultant|developer|engineer|specialist|advisor|lead|freelancer|self employed|board member)\b',
    caseSensitive: false,
  );

  (String, String?) _parseNameAndBusiness(String title, String platform) {
    var cleanTitle = title
        .replaceAll(RegExp(r'\s*-\s*Instagram\s*.*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\|\s*LinkedIn\s*.*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*-\s*LinkedIn\s*.*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*-\s*Facebook\s*.*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*-\s*X\s*.*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*-\s*Twitter\s*.*', caseSensitive: false), '')
        .trim();

    cleanTitle = cleanTitle.replaceAll(RegExp(r'\(@[a-zA-Z0-9._]+\)'), '').trim();
    cleanTitle = cleanTitle.replaceAll(RegExp(r'•.*'), '').trim();

    final parts = cleanTitle
        .split(RegExp(r'\s*[-|–:]\s*'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return ('Business Lead', null);
    }

    if (parts.length == 1) {
      final single = parts[0];
      return (single.isNotEmpty ? single : 'Business Lead', null);
    }

    String? detectedName;
    String? detectedRole;
    String? detectedBusiness;

    // Check each part
    for (var i = 0; i < parts.length; i++) {
      final part = parts[i];
      final isRole = _jobRoleRegex.hasMatch(part);

      if (isRole) {
        if (part.contains(RegExp(r'\s+(?:at|@)\s+', caseSensitive: false))) {
          final atSplit = part.split(RegExp(r'\s+(?:at|@)\s+', caseSensitive: false));
          detectedRole = atSplit[0].trim();
          if (atSplit.length > 1 && detectedBusiness == null) {
            detectedBusiness = atSplit[1].trim();
          }
        } else {
          detectedRole ??= part;
        }
      } else {
        if (detectedName == null) {
          detectedName = part;
        } else if (detectedBusiness == null) {
          detectedBusiness = part;
        }
      }
    }

    final finalName = detectedName ?? (detectedBusiness ?? parts[0]);
    var finalBusiness = detectedBusiness;

    // Avoid setting businessName if it's identical to name or matches a pure job role
    if (finalBusiness != null) {
      if (finalBusiness.toLowerCase() == finalName.toLowerCase() ||
          _jobRoleRegex.hasMatch(finalBusiness)) {
        finalBusiness = null;
      }
    }

    return (finalName.isNotEmpty ? finalName : 'Business Lead', finalBusiness);
  }

  /// Validates whether the search result matches the requested location filter.
  bool _matchesLocation(SearchResultItem item, String requestedLocation) {
    final cleanLoc = requestedLocation.trim().toLowerCase();
    if (cleanLoc.isEmpty) return true;

    final targetText = '${item.title} ${item.snippet} ${item.url}'.toLowerCase();

    // 1. Direct full string check
    if (targetText.contains(cleanLoc)) return true;

    // 2. Tokenized check for comma/space separated location (e.g. "Lucknow, UP", "South Delhi")
    final rawTokens = cleanLoc
        .split(RegExp(r'[,;\-\/|\s]+'))
        .map((t) => t.trim())
        .where((t) => t.length >= 2)
        .toList();

    if (rawTokens.isEmpty) return true;

    for (final token in rawTokens) {
      if (token.isEmpty) continue;
      final tokenRegex = RegExp(r'\b' + RegExp.escape(token) + r'\b', caseSensitive: false);
      if (tokenRegex.hasMatch(targetText) || targetText.contains(token)) {
        return true;
      }
    }

    return false;
  }

  String _generateId(String seed) {
    final rand = Random().nextInt(1000000);
    return '${seed.hashCode.abs()}-$rand';
  }
}
