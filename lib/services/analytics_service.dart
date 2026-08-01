import 'dart:convert';
import 'package:http/http.dart' as http;

class AnalyticsService {
  AnalyticsService._();
  static final instance = AnalyticsService._();

  static const _baseUrl = 'https://mastui-api.sanjeev-yadav1201.workers.dev';

  Future<void> trackView({
    required String designId,
    required String category,
  }) =>
      _sendEvent(designId: designId, category: category, event: 'view');

  Future<void> trackCopy({
    required String designId,
    required String category,
  }) =>
      _sendEvent(designId: designId, category: category, event: 'copy');

  Future<void> trackDownload({
    required String designId,
    required String category,
  }) =>
      _sendEvent(designId: designId, category: category, event: 'download');

  Future<void> trackDwell({
    required String designId,
    required String category,
    required int seconds,
  }) async {
    if (seconds < 2) return; // ignore very short glances
    try {
      await http.post(
        Uri.parse('$_baseUrl/analytics/event'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'designId': designId,
          'category': category,
          'event': 'dwell',
          'seconds': seconds,
        }),
      );
    } catch (_) {}
  }

  Future<void> trackSearch({required String query}) async {
    if (query.trim().length < 2) return;
    try {
      await http.post(
        Uri.parse('$_baseUrl/analytics/event'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'designId': '_search',
          'category': '_search',
          'event': 'search',
          'query': query.trim(),
        }),
      );
    } catch (_) {}
  }

  Future<void> _sendEvent({
    required String designId,
    required String category,
    required String event,
  }) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/analytics/event'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'designId': designId,
          'category': category,
          'event': event,
        }),
      );
    } catch (_) {
      // Best-effort — never block the UI
    }
  }

  Future<bool> submitFeedback({
    required String designId,
    required String category,
    required String message,
    int? rating,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/analytics/feedback'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'designId': designId,
          'category': category,
          'message': message,
          'rating': ?rating,
        }),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
