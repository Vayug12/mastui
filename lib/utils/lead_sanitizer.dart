/// Robust sanitizer for lead titles, business names, and URLs.
/// Removes search engine breadcrumbs (e.g. "//www. instagram . com >")
/// and platform junk (e.g. "Instagram https") adhering to mastui/design.md.
class LeadSanitizer {
  LeadSanitizer._();

  static final RegExp _breadcrumbRegex = RegExp(
    r'^(?:\/\/\s*)?(?:www\s*\.\s*)?[a-zA-Z0-9.-]+\s*\.\s*(?:com|in|org|net|co|io|biz|info|app|ai)\s*[>›»/]\s*',
    caseSensitive: false,
  );

  static final RegExp _urlPrefixRegex = RegExp(
    r'^(?:https?:\/\/)?(?:www\.)?[a-zA-Z0-9.-]+(?:\.[a-z]{2,})+(?:\/[^\s>]*)?\s*[>›»]\s*',
    caseSensitive: false,
  );

  static final RegExp _platformSuffixRegex = RegExp(
    r'\s*(?:[-|–—:]\s*)?(?:•\s*)?(?:Instagram|LinkedIn|Facebook|Twitter|X|YouTube)\s*(?:https?|photos\s+and\s+videos|profile)?\s*$',
    caseSensitive: false,
  );

  static final RegExp _platformJunkExactRegex = RegExp(
    r'^(?:Instagram|LinkedIn|Facebook|Twitter|X|YouTube)\s*(?:https?)?$',
    caseSensitive: false,
  );

  static final List<String> _socialDomains = [
    'instagram.com',
    'linkedin.com',
    'facebook.com',
    'twitter.com',
    'x.com',
    'youtube.com',
    'yahoo.com',
    'bing.com',
    'duckduckgo.com',
    'google.com',
  ];

  /// Cleans raw search engine breadcrumb / URL artifacts from titles & names.
  static String cleanTitle(String? raw) {
    if (raw == null) return '';
    var text = raw.trim();
    if (text.isEmpty) return '';

    // Remove repeated breadcrumb prefix
    while (_breadcrumbRegex.hasMatch(text) || _urlPrefixRegex.hasMatch(text)) {
      text = text.replaceAll(_breadcrumbRegex, '').replaceAll(_urlPrefixRegex, '').trim();
    }

    // Remove standalone leading or trailing URL
    text = text.replaceAll(RegExp(r'https?:\/\/\S+', caseSensitive: false), '').trim();

    // Remove platform suffix like "- Instagram https" or "• Instagram photos and videos"
    text = text.replaceAll(RegExp(r'\s*•\s*(?:Instagram|LinkedIn|Facebook|Twitter|X|photos|videos).*', caseSensitive: false), '');
    text = text.replaceAll(_platformSuffixRegex, '').trim();

    // Strip trailing/leading punctuation
    text = text.replaceAll(RegExp(r'^[-–—:|/>›»\s]+|[-–—:|/>›»\s]+$'), '').trim();

    return text;
  }

  /// Checks if a string is pure platform junk (e.g. "Instagram https", "LinkedIn", "Instagram").
  static bool isPlatformJunk(String? text) {
    if (text == null) return true;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return true;
    return _platformJunkExactRegex.hasMatch(trimmed) ||
        trimmed.toLowerCase() == 'web' ||
        trimmed.toLowerCase() == 'null';
  }

  /// Parses a cleaned string into a primary display name and an optional secondary handle or role.
  /// Handles combined tokens such as "katyta__b Katiliana" -> ("Katiliana", "@katyta__b")
  /// and "sugardotsolutions Sugardot" -> ("Sugardot", "@sugardotsolutions").
  static (String name, String? secondary) parseNameAndHandle(
    String rawTitle, {
    String? fallbackHandle,
  }) {
    final cleaned = cleanTitle(rawTitle);
    if (cleaned.isEmpty) {
      if (fallbackHandle != null && fallbackHandle.isNotEmpty) {
        final formattedHandle = fallbackHandle.startsWith('@') ? fallbackHandle : '@$fallbackHandle';
        return (fallbackHandle, formattedHandle);
      }
      return ('Business Lead', null);
    }

    // Check if title has explicit handle in parentheses: e.g. "Dr. Pervez Cooper (@mumbai.dentist)"
    final parenHandleMatch = RegExp(r'\(@([a-zA-Z0-9._]+)\)').firstMatch(cleaned);
    if (parenHandleMatch != null) {
      final handle = '@${parenHandleMatch.group(1)}';
      var primary = cleaned.replaceAll(parenHandleMatch.group(0)!, '').replaceAll(RegExp(r'\s+'), ' ').trim();
      primary = cleanTitle(primary);
      return (primary.isNotEmpty ? primary : handle, handle);
    }

    // Check for delimiter like " - ", " | ", or " : "
    final splitParts = cleaned
        .split(RegExp(r'\s*[-|–—:]\s*'))
        .map((p) => cleanTitle(p))
        .where((p) => p.isNotEmpty && !isPlatformJunk(p))
        .toList();

    if (splitParts.length > 1) {
      final primary = splitParts[0];
      final secondary = splitParts.sublist(1).join(' - ');
      return (primary, secondary);
    }

    // Single segment: check if it's composed of 2 words where one is handle and other is Name
    // e.g. "katyta__b Katiliana" or "sugardotsolutions Sugardot"
    final words = cleaned.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length == 2) {
      final first = words[0];
      final second = words[1];

      final isFirstHandle = _looksLikeHandle(first);
      final isSecondHandle = _looksLikeHandle(second);

      if (isFirstHandle && !isSecondHandle) {
        // first is handle (katyta__b), second is Name (Katiliana)
        return (second, '@$first');
      } else if (!isFirstHandle && isSecondHandle) {
        // first is Name, second is handle
        return (first, '@$second');
      }
    }

    // If whole string looks like a pure handle (e.g. "katyta__b")
    if (words.length == 1 && _looksLikeHandle(words[0])) {
      final handle = words[0];
      return (handle, '@$handle');
    }

    return (cleaned, fallbackHandle != null && fallbackHandle.isNotEmpty ? (fallbackHandle.startsWith('@') ? fallbackHandle : '@$fallbackHandle') : null);
  }

  static bool _looksLikeHandle(String token) {
    if (token.isEmpty) return false;
    if (token.contains('_')) return true; // contains underscores like katyta__b
    if (token.startsWith('@')) return true;
    // all lowercase alphanumeric without spaces or symbols, between 4 and 30 chars
    return RegExp(r'^[a-z0-9.]{4,30}$').hasMatch(token);
  }

  /// Determines if a website URL is a distinct, valid company website
  /// rather than a duplicate of profileUrl or a generic social media page.
  static bool isDistinctWebsite(String? website, String? profileUrl) {
    if (website == null) return false;
    final webClean = website.trim().toLowerCase();
    if (webClean.isEmpty) return false;

    if (profileUrl != null) {
      final profClean = profileUrl.trim().toLowerCase();
      if (webClean == profClean) return false;

      // Check without trailing slashes and protocols
      final normWeb = _stripProtocolAndSlash(webClean);
      final normProf = _stripProtocolAndSlash(profClean);
      if (normWeb == normProf) return false;
    }

    // Disallow generic social domains
    for (final domain in _socialDomains) {
      if (webClean.contains(domain)) {
        return false;
      }
    }

    return true;
  }

  static String _stripProtocolAndSlash(String url) {
    return url
        .replaceAll(RegExp(r'^https?:\/\/'), '')
        .replaceAll(RegExp(r'^www\.'), '')
        .replaceAll(RegExp(r'\/+$'), '');
  }
}
