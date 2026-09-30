import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'duckduckgo_search_service.dart';

/// In-App Headless/Off-screen Browser Search Service (Tarika 1).
/// Uses native Android Chromium / iOS WebKit rendering engine to execute Bing & Yahoo
/// searches with real browser TLS fingerprint, cookies, and JavaScript execution.
class InAppWebSearchService {
  InAppWebSearchService._();
  static final InAppWebSearchService instance = InAppWebSearchService._();

  WebViewController? _warmController;
  bool _isInitialized = false;

  /// Human mobile user agent for browser rendering
  static const String mobileUserAgent =
      'Mozilla/5.0 (Linux; Android 14; SM-S928B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.6367.113 Mobile Safari/537.36';

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      _warmController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setUserAgent(mobileUserAgent);
      _isInitialized = true;
    } catch (e) {
      debugPrint('InAppWebSearchService initialize skipped (non-mobile host): $e');
    }
  }

  /// Creates or retrieves an isolated WebViewController for thread-safe concurrent searches.
  Future<WebViewController?> _getOrCreateController() async {
    if (!_isInitialized) {
      await initialize();
    }
    try {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setUserAgent(mobileUserAgent);
      return controller;
    } catch (e) {
      if (_warmController != null) return _warmController;
      debugPrint('InAppWebSearchService controller creation skipped: $e');
      return null;
    }
  }

  /// Safely unescapes raw HTML returned from JavaScript execution.
  String _decodeJsHtml(dynamic result) {
    if (result == null) return '';
    var str = result.toString();
    if (str.startsWith('"') && str.endsWith('"')) {
      try {
        final decoded = jsonDecode(str);
        if (decoded is String) return decoded;
      } catch (_) {
        if (str.length >= 2) {
          str = str.substring(1, str.length - 1);
        }
      }
    }
    return str;
  }

  /// Searches Bing via real browser engine and extracts DOM items.
  Future<List<SearchResultItem>> searchBing(
    String query, {
    int page = 1,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final controller = await _getOrCreateController();
    if (controller == null) return [];

    final completer = Completer<List<SearchResultItem>>();
    final offset = (page - 1) * 10 + 1;
    final encoded = Uri.encodeQueryComponent(query);
    final searchUrl = 'https://www.bing.com/search?q=$encoded&first=$offset';

    Timer? timer;
    try {
      controller.setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) async {
            try {
              await Future.delayed(const Duration(milliseconds: 300));
              final html = await controller.runJavaScriptReturningResult(
                'document.documentElement.outerHTML',
              );
              final rawHtml = _decodeJsHtml(html);
              final results = DuckDuckGoSearchService.instance.parseBingResults(rawHtml);
              if (!completer.isCompleted) {
                timer?.cancel();
                completer.complete(results);
              }
            } catch (_) {
              if (!completer.isCompleted) {
                timer?.cancel();
                completer.complete([]);
              }
            }
          },
          onWebResourceError: (error) {
            if (!completer.isCompleted) {
              timer?.cancel();
              completer.complete([]);
            }
          },
        ),
      );

      timer = Timer(timeout, () {
        if (!completer.isCompleted) {
          completer.complete([]);
        }
      });

      await controller.loadRequest(Uri.parse(searchUrl));
      return await completer.future;
    } catch (e) {
      timer?.cancel();
      return [];
    }
  }

  /// Searches Yahoo via real browser engine and extracts DOM items.
  Future<List<SearchResultItem>> searchYahoo(
    String query, {
    int page = 1,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final controller = await _getOrCreateController();
    if (controller == null) return [];

    final completer = Completer<List<SearchResultItem>>();
    final offset = (page - 1) * 10 + 1;
    final encoded = Uri.encodeQueryComponent(query);
    final searchUrl = 'https://search.yahoo.com/search?p=$encoded&b=$offset';

    Timer? timer;
    try {
      controller.setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) async {
            try {
              await Future.delayed(const Duration(milliseconds: 300));
              final html = await controller.runJavaScriptReturningResult(
                'document.documentElement.outerHTML',
              );
              final rawHtml = _decodeJsHtml(html);
              final results = DuckDuckGoSearchService.instance.parseYahooResults(rawHtml);
              if (!completer.isCompleted) {
                timer?.cancel();
                completer.complete(results);
              }
            } catch (_) {
              if (!completer.isCompleted) {
                timer?.cancel();
                completer.complete([]);
              }
            }
          },
          onWebResourceError: (error) {
            if (!completer.isCompleted) {
              timer?.cancel();
              completer.complete([]);
            }
          },
        ),
      );

      timer = Timer(timeout, () {
        if (!completer.isCompleted) {
          completer.complete([]);
        }
      });

      await controller.loadRequest(Uri.parse(searchUrl));
      return await completer.future;
    } catch (e) {
      timer?.cancel();
      return [];
    }
  }

  /// Searches DuckDuckGo via real browser engine and extracts DOM items.
  Future<List<SearchResultItem>> searchDuckDuckGo(
    String query, {
    int page = 1,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final controller = await _getOrCreateController();
    if (controller == null) return [];

    final completer = Completer<List<SearchResultItem>>();
    final encoded = Uri.encodeQueryComponent(query);
    final searchUrl = 'https://duckduckgo.com/html/?q=$encoded';

    Timer? timer;
    try {
      controller.setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) async {
            try {
              await Future.delayed(const Duration(milliseconds: 300));
              final html = await controller.runJavaScriptReturningResult(
                'document.documentElement.outerHTML',
              );
              final rawHtml = _decodeJsHtml(html);
              final results = DuckDuckGoSearchService.instance.parseSearchResults(rawHtml);
              if (!completer.isCompleted) {
                timer?.cancel();
                completer.complete(results);
              }
            } catch (_) {
              if (!completer.isCompleted) {
                timer?.cancel();
                completer.complete([]);
              }
            }
          },
          onWebResourceError: (error) {
            if (!completer.isCompleted) {
              timer?.cancel();
              completer.complete([]);
            }
          },
        ),
      );

      timer = Timer(timeout, () {
        if (!completer.isCompleted) {
          completer.complete([]);
        }
      });

      await controller.loadRequest(Uri.parse(searchUrl));
      return await completer.future;
    } catch (e) {
      timer?.cancel();
      return [];
    }
  }
}
