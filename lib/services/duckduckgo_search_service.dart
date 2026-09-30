import 'dart:convert';
import 'package:http/http.dart' as http;
import 'in_app_web_search_service.dart';

/// Raw search result extracted from search engines (Yahoo, Bing, DuckDuckGo).
class SearchResultItem {
  final String title;
  final String url;
  final String snippet;
  final String sourceEngine;

  const SearchResultItem({
    required this.title,
    required this.url,
    required this.snippet,
    this.sourceEngine = 'Web',
  });

  @override
  String toString() => 'SearchResultItem(engine: $sourceEngine, title: $title, url: $url)';
}

/// Multi-engine search service that orchestrates queries across Yahoo, Bing,
/// InApp Browser Engine, and DuckDuckGo Lite with automatic anomaly detection and seamless failover.
class DuckDuckGoSearchService {
  DuckDuckGoSearchService._();
  static final instance = DuckDuckGoSearchService._();

  static const Map<String, String> _desktopHeaders = {
    'User-Agent': 
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
    'Sec-Fetch-Dest': 'document',
    'Sec-Fetch-Mode': 'navigate',
    'Sec-Fetch-Site': 'none',
    'Upgrade-Insecure-Requests': '1',
  };

  static const Map<String, String> _mobileHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 14; SM-S928B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.6367.113 Mobile Safari/537.36',
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
    'Referer': 'https://lite.duckduckgo.com/',
  };

  /// Tracks whether DuckDuckGo is currently blocked by CAPTCHA/anomaly modal.
  bool _isDdgRateLimited = false;
  bool get isDdgRateLimited => _isDdgRateLimited;

  /// Optional mock results for test environments
  List<SearchResultItem>? testMockResults;

  /// Tracks rotating engine calls to prevent consecutive bursts to a single provider.
  int _searchCallCount = 0;

  /// Searches using the resilient multi-engine pipeline with automatic engine rotation:
  /// Primary engines rotate between Yahoo & Bing to prevent single-provider IP rate limits,
  /// with automatic fallback to DuckDuckGo Lite & HTML.
  Future<List<SearchResultItem>> search(
    String query, {
    int page = 1,
    Duration timeout = const Duration(seconds: 12),
    String? preferredEngine,
  }) async {
    if (testMockResults != null) {
      return testMockResults!;
    }

    _searchCallCount++;
    // Alternate starting engine if preferredEngine is not specified: even -> Yahoo, odd -> Bing
    final primary = preferredEngine ?? (_searchCallCount % 2 == 0 ? 'Yahoo' : 'Bing');

    // 1. Primary Stage: In-App Browser Engine (Native Chromium/WebKit)
    // Runs with real browser TLS fingerprint, cookies, and JS execution to bypass bot filters
    try {
      if (primary == 'Bing') {
        final inAppBing = await InAppWebSearchService.instance.searchBing(query, page: page, timeout: timeout);
        if (inAppBing.isNotEmpty) return inAppBing;

        final inAppYahoo = await InAppWebSearchService.instance.searchYahoo(query, page: page, timeout: timeout);
        if (inAppYahoo.isNotEmpty) return inAppYahoo;
      } else {
        final inAppYahoo = await InAppWebSearchService.instance.searchYahoo(query, page: page, timeout: timeout);
        if (inAppYahoo.isNotEmpty) return inAppYahoo;

        final inAppBing = await InAppWebSearchService.instance.searchBing(query, page: page, timeout: timeout);
        if (inAppBing.isNotEmpty) return inAppBing;
      }
    } catch (_) {
      // In-app browser unavailable (e.g. unit test or non-mobile host), continue to direct HTTP
    }

    // 2. Direct HTTP Fallback Pipeline (Yahoo <-> Bing)
    if (primary == 'Bing') {
      try {
        final bingResults = await searchBing(query, page: page, timeout: timeout);
        if (bingResults.isNotEmpty) return bingResults;
      } catch (_) {}

      try {
        final yahooResults = await searchYahoo(query, page: page, timeout: timeout);
        if (yahooResults.isNotEmpty) return yahooResults;
      } catch (_) {}
    } else {
      try {
        final yahooResults = await searchYahoo(query, page: page, timeout: timeout);
        if (yahooResults.isNotEmpty) return yahooResults;
      } catch (_) {}

      try {
        final bingResults = await searchBing(query, page: page, timeout: timeout);
        if (bingResults.isNotEmpty) return bingResults;
      } catch (_) {}
    }

    // 3. Tertiary Fallback: In-App DuckDuckGo or DuckDuckGo Lite Mobile Engine
    try {
      final inAppDdg = await InAppWebSearchService.instance.searchDuckDuckGo(query, page: page, timeout: timeout);
      if (inAppDdg.isNotEmpty) return inAppDdg;
    } catch (_) {}

    try {
      final ddgLiteResults = await searchDuckDuckGoLite(query, page: page, timeout: timeout);
      if (ddgLiteResults.isNotEmpty) {
        return ddgLiteResults;
      }
    } catch (_) {}

    // 4. Quaternary Fallback: DuckDuckGo HTML Engine (with anomaly guard)
    if (!_isDdgRateLimited) {
      try {
        final ddgResults = await searchDuckDuckGo(query, page: page, timeout: timeout);
        if (ddgResults.isNotEmpty) {
          return ddgResults;
        }
      } catch (_) {}
    }

    return [];
  }

  /// Executes query against Yahoo Search with pagination support and decodes results.
  Future<List<SearchResultItem>> searchYahoo(
    String query, {
    int page = 1,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    try {
      final encodedQuery = Uri.encodeQueryComponent(query);
      final offset = (page - 1) * 10 + 1;
      final url = Uri.parse('https://search.yahoo.com/search?p=$encodedQuery&b=$offset');

      final response = await http
          .get(url, headers: _desktopHeaders)
          .timeout(timeout);

      if (response.statusCode != 200) {
        return [];
      }

      return parseYahooResults(response.body);
    } catch (_) {
      return [];
    }
  }

  /// Parses Yahoo HTML search result blocks.
  List<SearchResultItem> parseYahooResults(String html) {
    final results = <SearchResultItem>[];

    // Yahoo search items are structured inside <div class="dd algo..."> or <div class="compTitle"> and <div class="compText">
    final blockRegex = RegExp(
      r'<div[^>]*class="[^"]*(?:algo|algo-sr|Sr)[^"]*"[^>]*>(.*?)<\/div>\s*<\/li>',
      caseSensitive: false,
      dotAll: true,
    );

    final titleAndUrlRegex = RegExp(
      r'<div[^>]*class="[^"]*compTitle[^"]*"[^>]*>.*?<a[^>]*href="([^"]+)"[^>]*>(.*?)<\/a>',
      caseSensitive: false,
      dotAll: true,
    );

    final snippetRegex = RegExp(
      r'<div[^>]*class="[^"]*compText[^"]*"[^>]*>.*?<p[^>]*>(.*?)<\/p>',
      caseSensitive: false,
      dotAll: true,
    );

    final blocks = blockRegex.allMatches(html);

    for (final block in blocks) {
      final blockHtml = block.group(1) ?? '';
      final titleMatch = titleAndUrlRegex.firstMatch(blockHtml);

      if (titleMatch == null) continue;

      final rawUrl = titleMatch.group(1) ?? '';
      final rawTitle = titleMatch.group(2) ?? '';
      final snippetMatch = snippetRegex.firstMatch(blockHtml);
      final rawSnippet = snippetMatch?.group(1) ?? '';

      // Prefer <h3> title text over breadcrumb container
      final h3Match = RegExp(r'<h3[^>]*>(.*?)<\/h3>', caseSensitive: false, dotAll: true).firstMatch(rawTitle);
      final rawTitleText = h3Match?.group(1) ?? rawTitle;

      final cleanUrl = _cleanYahooUrl(rawUrl);
      var cleanTitle = _cleanHtml(rawTitleText);
      cleanTitle = cleanTitle.replaceAll(RegExp(r'^(?:Instagram|LinkedIn|Facebook|X|Twitter)?\s*(?:https?:\/\/)?[a-zA-Z0-9.-]+\s*›\s*[^\s]+\s*', caseSensitive: false), '').trim();
      final cleanSnippet = _cleanHtml(rawSnippet);

      if (cleanTitle.isNotEmpty && cleanSnippet.isNotEmpty) {
        results.add(SearchResultItem(
          title: cleanTitle,
          url: cleanUrl,
          snippet: cleanSnippet,
          sourceEngine: 'Yahoo',
        ));
      }
    }

    // Fallback: direct pattern match across the entire HTML if container block regex missed
    if (results.isEmpty) {
      final titles = titleAndUrlRegex.allMatches(html).toList();
      final snippets = snippetRegex.allMatches(html).toList();

      for (var i = 0; i < titles.length && i < snippets.length; i++) {
        final rawUrl = titles[i].group(1) ?? '';
        final rawTitle = titles[i].group(2) ?? '';
        final rawSnippet = snippets[i].group(1) ?? '';

        final cleanUrl = _cleanYahooUrl(rawUrl);
        final cleanTitle = _cleanHtml(rawTitle);
        final cleanSnippet = _cleanHtml(rawSnippet);

        if (cleanTitle.isNotEmpty && cleanSnippet.isNotEmpty) {
          results.add(SearchResultItem(
            title: cleanTitle,
            url: cleanUrl,
            snippet: cleanSnippet,
            sourceEngine: 'Yahoo',
          ));
        }
      }
    }

    return results;
  }

  /// Executes query against Bing Search with pagination support.
  Future<List<SearchResultItem>> searchBing(
    String query, {
    int page = 1,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    try {
      final encodedQuery = Uri.encodeQueryComponent(query);
      final offset = (page - 1) * 10 + 1;
      final url = Uri.parse('https://www.bing.com/search?q=$encodedQuery&first=$offset');

      final response = await http
          .get(url, headers: _desktopHeaders)
          .timeout(timeout);

      if (response.statusCode != 200) {
        return [];
      }

      return parseBingResults(response.body);
    } catch (_) {
      return [];
    }
  }

  /// Parses Bing HTML search results.
  List<SearchResultItem> parseBingResults(String html) {
    final results = <SearchResultItem>[];

    final blockRegex = RegExp(
      r'<li[^>]*class="[^"]*b_algo[^"]*"[^>]*>(.*?)<\/li>',
      caseSensitive: false,
      dotAll: true,
    );

    final titleRegex = RegExp(
      r'<h2[^>]*>\s*<a[^>]*href="([^"]+)"[^>]*>(.*?)<\/a>\s*<\/h2>',
      caseSensitive: false,
      dotAll: true,
    );

    final snippetRegex = RegExp(
      r'<div[^>]*class="[^"]*b_caption[^"]*"[^>]*>\s*<p[^>]*>(.*?)<\/p>',
      caseSensitive: false,
      dotAll: true,
    );

    final blocks = blockRegex.allMatches(html);

    for (final block in blocks) {
      final blockHtml = block.group(1) ?? '';
      final titleMatch = titleRegex.firstMatch(blockHtml);
      final snippetMatch = snippetRegex.firstMatch(blockHtml);

      if (titleMatch == null) continue;

      final rawUrl = titleMatch.group(1) ?? '';
      final rawTitle = titleMatch.group(2) ?? '';
      final rawSnippet = snippetMatch?.group(1) ?? '';

      final cleanUrl = _cleanBingUrl(rawUrl);
      final cleanTitle = _cleanHtml(rawTitle);
      final cleanSnippet = _cleanHtml(rawSnippet);

      if (cleanTitle.isNotEmpty && cleanSnippet.isNotEmpty) {
        results.add(SearchResultItem(
          title: cleanTitle,
          url: cleanUrl,
          snippet: cleanSnippet,
          sourceEngine: 'Bing',
        ));
      }
    }

    // Fallback: direct pattern match across the entire HTML if container block regex missed
    if (results.isEmpty) {
      final titles = titleRegex.allMatches(html).toList();
      final snippets = snippetRegex.allMatches(html).toList();

      for (var i = 0; i < titles.length; i++) {
        final rawUrl = titles[i].group(1) ?? '';
        final rawTitle = titles[i].group(2) ?? '';
        final rawSnippet = i < snippets.length ? (snippets[i].group(1) ?? '') : '';

        final cleanUrl = _cleanBingUrl(rawUrl);
        final cleanTitle = _cleanHtml(rawTitle);
        final cleanSnippet = _cleanHtml(rawSnippet);

        if (cleanTitle.isNotEmpty && cleanUrl.isNotEmpty) {
          results.add(SearchResultItem(
            title: cleanTitle,
            url: cleanUrl,
            snippet: cleanSnippet.isNotEmpty ? cleanSnippet : cleanTitle,
            sourceEngine: 'Bing',
          ));
        }
      }
    }

    return results;
  }

  /// Executes search against DuckDuckGo Lite endpoint (Tarika 2) with Mobile headers.
  Future<List<SearchResultItem>> searchDuckDuckGoLite(
    String query, {
    int page = 1,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    try {
      const ddgLiteUrl = 'https://lite.duckduckgo.com/lite/';
      final offset = (page - 1) * 30;
      final response = await http
          .post(
            Uri.parse(ddgLiteUrl),
            headers: {
              ..._mobileHeaders,
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: {
              'q': query,
              's': offset > 0 ? '$offset' : '',
              'kl': 'wt-wt',
            },
          )
          .timeout(timeout);

      if (response.statusCode != 200 && response.statusCode != 202) {
        return [];
      }

      if (_isDdgAnomaly(response.body)) {
        return [];
      }

      return parseDdgLiteResults(response.body);
    } catch (_) {
      return [];
    }
  }

  /// Parses DuckDuckGo Lite HTML table results.
  List<SearchResultItem> parseDdgLiteResults(String html) {
    if (_isDdgAnomaly(html)) return [];
    final results = <SearchResultItem>[];

    final linkRegex = RegExp(
      r'<a[^>]*class="[^"]*result-link[^"]*"[^>]*href="([^"]+)"[^>]*>(.*?)<\/a>',
      caseSensitive: false,
      dotAll: true,
    );
    final snippetRegex = RegExp(
      r'<td[^>]*class="[^"]*result-snippet[^"]*"[^>]*>(.*?)<\/td>',
      caseSensitive: false,
      dotAll: true,
    );

    final links = linkRegex.allMatches(html).toList();
    final snippets = snippetRegex.allMatches(html).toList();

    for (var i = 0; i < links.length; i++) {
      final rawUrl = links[i].group(1) ?? '';
      final rawTitle = links[i].group(2) ?? '';
      final rawSnippet = i < snippets.length ? (snippets[i].group(1) ?? '') : '';

      final cleanUrl = _cleanDdgUrl(rawUrl);
      final cleanTitle = _cleanHtml(rawTitle);
      final cleanSnippet = _cleanHtml(rawSnippet);

      if (cleanTitle.isNotEmpty && cleanUrl.isNotEmpty) {
        results.add(SearchResultItem(
          title: cleanTitle,
          url: cleanUrl,
          snippet: cleanSnippet.isNotEmpty ? cleanSnippet : cleanTitle,
          sourceEngine: 'DuckDuckGo',
        ));
      }
    }

    return results;
  }

  /// Executes search against DuckDuckGo HTML with anomaly detection and pagination.
  Future<List<SearchResultItem>> searchDuckDuckGo(
    String query, {
    int page = 1,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    try {
      const ddgUrl = 'https://html.duckduckgo.com/html/';
      final offset = (page - 1) * 30;
      final response = await http
          .post(
            Uri.parse(ddgUrl),
            headers: {
              ..._desktopHeaders,
              'Content-Type': 'application/x-www-form-urlencoded',
              'Referer': 'https://html.duckduckgo.com/',
            },
            body: {
              'q': query,
              's': offset > 0 ? '$offset' : '',
              'b': '',
              'kl': 'wt-wt',
            },
          )
          .timeout(timeout);

      if (response.statusCode != 200) {
        return [];
      }

      // Check for anomaly CAPTCHA challenge
      if (_isDdgAnomaly(response.body)) {
        _isDdgRateLimited = true;
        return [];
      }

      return parseSearchResults(response.body);
    } catch (_) {
      return [];
    }
  }

  /// Checks if DuckDuckGo returned a bot anomaly challenge instead of search results.
  bool _isDdgAnomaly(String html) {
    final lower = html.toLowerCase();
    return lower.contains('anomaly-modal') ||
        lower.contains('anomaly-modal__check') ||
        lower.contains('error-lite+') ||
        lower.contains('challenge-form') ||
        lower.contains('images not loading?');
  }

  /// Parses DuckDuckGo HTML results.
  List<SearchResultItem> parseSearchResults(String html) {
    if (_isDdgAnomaly(html)) return [];

    final results = <SearchResultItem>[];

    final resultBlockRegex = RegExp(
      r'<div[^>]*class="[^"]*(?:result|result__body)[^"]*"[^>]*>(.*?)<\/div>\s*<\/div>',
      caseSensitive: false,
      dotAll: true,
    );

    final titleAndUrlRegex = RegExp(
      r'<a[^>]*class="[^"]*result__a[^"]*"[^>]*href="([^"]+)"[^>]*>(.*?)<\/a>',
      caseSensitive: false,
      dotAll: true,
    );

    final snippetRegex = RegExp(
      r'<(?:a|div)[^>]*class="[^"]*result__snippet[^"]*"[^>]*>(.*?)<\/(?:a|div)>',
      caseSensitive: false,
      dotAll: true,
    );

    final blocks = resultBlockRegex.allMatches(html);

    for (final block in blocks) {
      final blockHtml = block.group(1) ?? '';
      final titleMatch = titleAndUrlRegex.firstMatch(blockHtml);
      final snippetMatch = snippetRegex.firstMatch(blockHtml);

      if (titleMatch == null) continue;

      final rawUrl = titleMatch.group(1) ?? '';
      final rawTitle = titleMatch.group(2) ?? '';
      final rawSnippet = snippetMatch?.group(1) ?? '';

      final cleanUrl = _cleanDdgUrl(rawUrl);
      final cleanTitle = _cleanHtml(rawTitle);
      final cleanSnippet = _cleanHtml(rawSnippet);

      if (cleanTitle.isNotEmpty && cleanSnippet.isNotEmpty) {
        results.add(SearchResultItem(
          title: cleanTitle,
          url: cleanUrl,
          snippet: cleanSnippet,
          sourceEngine: 'DuckDuckGo',
        ));
      }
    }

    return results;
  }

  /// Cleans redirect URLs from Bing, Yahoo, and DuckDuckGo into direct destination URLs.
  String cleanRedirectUrl(String rawUrl) {
    var url = rawUrl.trim();
    if (url.contains('/ck/a?') || url.contains('bing.com/ck/a?')) {
      return _cleanBingUrl(url);
    }
    if (url.contains('/RU=') || url.contains('RU=')) {
      return _cleanYahooUrl(url);
    }
    if (url.contains('uddg=')) {
      return _cleanDdgUrl(url);
    }
    return url;
  }

  /// Decodes Yahoo redirect URLs: /RU=https%3a%2f%2f.../RK=2/
  String _cleanYahooUrl(String rawUrl) {
    var url = rawUrl.trim().replaceAll('&amp;', '&');
    if (url.contains('/RU=') || url.contains('RU=')) {
      final match = RegExp(r'[?&/]RU=([^/]+?)(?:/RK=|\/|\s|$)').firstMatch(url);
      if (match != null) {
        final encoded = match.group(1) ?? '';
        try {
          return Uri.decodeComponent(encoded);
        } catch (_) {
          return encoded;
        }
      }
    }
    return url;
  }

  /// Decodes Bing redirect URLs: `bing.com/ck/a?...&u=a1<base64>`
  String _cleanBingUrl(String rawUrl) {
    var url = rawUrl.trim().replaceAll('&amp;', '&');
    if (url.contains('/ck/a?') || url.contains('bing.com/ck/a?')) {
      final match = RegExp(r'[?&](?:amp;)?u=([^&]+)').firstMatch(url);
      if (match != null) {
        var uVal = Uri.decodeComponent(match.group(1)!);
        if (uVal.startsWith('a1') || uVal.startsWith('a0')) {
          uVal = uVal.substring(2);
        }
        try {
          var b64 = uVal;
          while (b64.length % 4 != 0) {
            b64 += '=';
          }
          b64 = b64.replaceAll('-', '+').replaceAll('_', '/');
          final decoded = utf8.decode(base64.decode(b64));
          if (decoded.startsWith('http')) return decoded;
        } catch (_) {}
      }
    }
    return url;
  }

  /// Decodes DuckDuckGo redirect URLs: /l/?uddg=https%3A%2F%2F...
  String _cleanDdgUrl(String rawUrl) {
    var url = rawUrl.trim().replaceAll('&amp;', '&');
    if (url.contains('uddg=')) {
      final match = RegExp(r'[?&]uddg=([^&]+)').firstMatch(url);
      if (match != null) {
        return Uri.decodeComponent(match.group(1)!);
      }
      final uri = Uri.tryParse(url.startsWith('http') ? url : 'https://duckduckgo.com$url');
      if (uri != null && uri.queryParameters.containsKey('uddg')) {
        return uri.queryParameters['uddg']!;
      }
    }
    if (url.startsWith('//')) {
      return 'https:$url';
    }
    return url;
  }

  /// Removes HTML tags and unescapes HTML entities.
  String _cleanHtml(String raw) {
    var text = raw.replaceAll(RegExp(r'<[^>]*>'), ' ');
    text = text
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&#x27;', "'")
      .replaceAll('&#39;', "'")
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&#8211;', '-')
      .replaceAll('&#8212;', '-')
      .replaceAll('&middot;', '·')
      .replaceAll('&bull;', '•')
      .replaceAll('&#8226;', '•')
      .replaceAll('&zwj;', '')
      .replaceAll('&zwnj;', '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
    return text;
  }
}
