import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mastui/services/connection_service.dart';
import 'package:mastui/widgets/connection_banner.dart';

void main() {
  testWidgets('offline feedback supports retry and disappears on recovery', (
    tester,
  ) async {
    var offline = true;
    final service = ConnectionService(
      probe: () async {
        if (offline) throw const SocketException('Network unavailable');
      },
    );
    addTearDown(service.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ConnectionBanner(
          service: service,
          child: const Scaffold(body: Text('Saved leads')),
        ),
      ),
    );
    await service.check();
    await tester.pump();
    expect(find.text(ConnectionService.offlineMessage), findsOneWidget);
    expect(find.text('Saved leads'), findsOneWidget);
    offline = false;
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(find.text(ConnectionService.offlineMessage), findsNothing);
    expect(service.status, ConnectionStatus.online);
  });

  testWidgets('slow feedback appears while waiting and checks do not overlap', (
    tester,
  ) async {
    final pending = Completer<void>();
    var calls = 0;
    final service = ConnectionService(
      probe: () {
        calls++;
        return pending.future;
      },
    );
    addTearDown(service.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ConnectionBanner(
          service: service,
          child: const SizedBox.expand(),
        ),
      ),
    );
    final check = service.check();
    await service.check();
    expect(calls, 1);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text(ConnectionService.slowMessage), findsOneWidget);
    expect(find.text('Checking…'), findsOneWidget);
    pending.complete();
    await check;
    await tester.pump();
    expect(find.text('Retry'), findsOneWidget);
    await service.check();
    await tester.pump();
    expect(find.text(ConnectionService.slowMessage), findsNothing);
  });

  testWidgets('timeout is slow and disposal during a check is safe', (
    tester,
  ) async {
    final service = ConnectionService(probe: () => Completer<void>().future);
    final check = service.check();
    await tester.pump(const Duration(seconds: 10));
    await check;
    expect(service.status, ConnectionStatus.slow);
    final next = service.check();
    service.dispose();
    await tester.pump(const Duration(seconds: 10));
    await next;
  });
}
