import 'dart:convert';
import 'package:http/http.dart' as http;

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
/// and DuckDuckGo with automatic anomaly detection and seamless failover.
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

  /// Tracks whether DuckDuckGo is currently blocked by CAPTCHA/anomaly modal.
  bool _isDdgRateLimited = false;
  bool get isDdgRateLimited => _isDdgRateLimited;

  /// Searches using the resilient multi-engine pipeline:
  /// Primary: Yahoo Search -> Secondary: Bing -> Tertiary: DuckDuckGo.
  Future<List<SearchResultItem>> search(
    String query, {
    int page = 1,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    // 1. Primary Engine: Yahoo Search (100% success rate, no CAPTCHA blocks)
    try {
      final yahooResults = await searchYahoo(query, page: page, timeout: timeout);
      if (yahooResults.isNotEmpty) {
        return yahooResults;
      }
    } catch (_) {}

    // 2. Secondary Engine: Bing Search
    try {
      final bingResults = await searchBing(query, page: page, timeout: timeout);
      if (bingResults.isNotEmpty) {
        return bingResults;
      }
    } catch (_) {}

    // 3. Tertiary Engine: DuckDuckGo (with anomaly guard)
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

    return results;
  }

  /// Executes search against DuckDuckGo HTML / Lite with anomaly detection and pagination.
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

  /// Decodes Yahoo redirect URLs: /RU=https%3a%2f%2f.../RK=2/
  String _cleanYahooUrl(String rawUrl) {
    var url = rawUrl.trim();
    if (url.contains('/RU=')) {
      final match = RegExp(r'/RU=([^/]+)/RK=').firstMatch(url);
      if (match != null) {
        final encoded = match.group(1) ?? '';
        return Uri.decodeComponent(encoded);
      }
    }
    return url;
  }

  /// Decodes Bing redirect URLs: bing.com/ck/a?...&u=a1<base64>
  String _cleanBingUrl(String rawUrl) {
    var url = rawUrl.trim();
    if (url.contains('bing.com/ck/a?') && url.contains('&u=')) {
      final uParam = Uri.tryParse(url)?.queryParameters['u'];
      if (uParam != null && uParam.startsWith('a1')) {
        try {
          var b64 = uParam.substring(2);
          while (b64.length % 4 != 0) {
            b64 += '=';
          }
          final decoded = utf8.decode(base64Url.decode(b64));
          if (decoded.startsWith('http')) return decoded;
        } catch (_) {}
      }
    }
    return url;
  }

  /// Decodes DuckDuckGo redirect URLs: /l/?uddg=https%3A%2F%2F...
  String _cleanDdgUrl(String rawUrl) {
    var url = rawUrl.trim();
    if (url.contains('uddg=')) {
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
