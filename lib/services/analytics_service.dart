import 'dart:convert';
import 'package:http/http.dart' as http;

class AnalyticsService {
  AnalyticsService._();
  static final instance = AnalyticsService._();

  static const _baseUrl = 'https://mastui-api.sanjeev-yadav1201.workers.dev';

  Future<void> trackEvent({
    required String eventName,
    Map<String, dynamic>? parameters,
  }) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/analytics/event'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'event': eventName,
          'timestamp': DateTime.now().toIso8601String(),
          ...?parameters,
        }),
      );
    } catch (_) {}
  }
}
