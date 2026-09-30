import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

enum ConnectionStatus { checking, online, slow, offline }

/// Checks reachability independently of search results and provider errors.
class ConnectionService extends ChangeNotifier {
  ConnectionService({Future<void> Function()? probe})
    : _probe = probe ?? _probeInternet;

  static final instance = ConnectionService();
  final Future<void> Function() _probe;
  ConnectionStatus status = ConnectionStatus.checking;
  bool isChecking = false;
  bool _disposed = false;
  bool _started = false;
  Timer? _poll;
  Timer? _slowTimer;

  static const slowMessage =
      'Slow internet connection. Results may take longer to load.';
  static const offlineMessage =
      'No internet connection. Check your Wi-Fi or mobile data and try again.';

  // Use two independent hosts already used by search. Any HTTP response
  // confirms reachability, including rate limiting and server errors.
  static Future<void> _probeInternet() async {
    final client = http.Client();
    final reachable = Completer<void>();
    var failures = 0;
    Future<void> checkHost(String host) async {
      try {
        await client.head(Uri.https(host, '/'));
        if (!reachable.isCompleted) reachable.complete();
      } catch (error, stack) {
        failures++;
        if (failures == 2 && !reachable.isCompleted) {
          reachable.completeError(error, stack);
        }
      }
    }

    try {
      unawaited(checkHost('www.bing.com'));
      unawaited(checkHost('duckduckgo.com'));
      await reachable.future.timeout(const Duration(seconds: 10));
    } finally {
      client.close();
    }
  }

  void start() {
    if (_started || _disposed) return;
    _started = true;
    resume();
  }

  void resume() {
    if (!_started || _disposed) return;
    _poll?.cancel();
    unawaited(check());
    _poll = Timer.periodic(const Duration(seconds: 20), (_) {
      unawaited(check());
    });
  }

  void pause() => _poll?.cancel();

  Future<void> check() async {
    if (isChecking || _disposed) return;
    isChecking = true;
    notifyListeners();
    var slow = false;
    _slowTimer = Timer(const Duration(seconds: 3), () {
      slow = true;
      // Keep an existing offline warning visible until reachability succeeds.
      if (status != ConnectionStatus.offline) _setStatus(ConnectionStatus.slow);
    });
    try {
      await _probe().timeout(const Duration(seconds: 10));
      _setStatus(slow ? ConnectionStatus.slow : ConnectionStatus.online);
    } on TimeoutException {
      // A timeout alone cannot prove the device is offline.
      _setStatus(ConnectionStatus.slow);
    } catch (_) {
      _setStatus(ConnectionStatus.offline);
    } finally {
      _slowTimer?.cancel();
      isChecking = false;
      if (!_disposed) notifyListeners();
    }
  }

  void _setStatus(ConnectionStatus value) {
    if (_disposed) return;
    status = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    _slowTimer?.cancel();
    super.dispose();
  }
}
