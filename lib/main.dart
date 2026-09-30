import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/main_shell.dart';
import 'services/ad_service.dart';
import 'services/connection_service.dart';
import 'services/in_app_web_search_service.dart';
import 'theme/app_theme.dart';
import 'widgets/connection_banner.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ConnectionService.instance.start();

  // Start the ads SDK without blocking first frame.
  unawaited(AdService.instance.init());
  // Pre-initialize in-app web search browser engine
  unawaited(InAppWebSearchService.instance.initialize());

  // Let the white Flutter canvas extend behind Android's 3-button/gesture area.
  // Android 10+ otherwise adds a dark contrast scrim behind transparent nav bars.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarContrastEnforced: false,
    ),
  );
  runApp(const MastUiApp());
}

class MastUiApp extends StatelessWidget {
  const MastUiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GetLead Agent',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      builder: (context, child) =>
          ConnectionBanner(service: ConnectionService.instance, child: child!),
      home: const MainShell(),
    );
  }
}
