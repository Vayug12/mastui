import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/home_screen.dart';
import 'services/ad_service.dart';
import 'services/revenue_cat_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Start the ads SDK without blocking first frame.
  unawaited(AdService.instance.init());

  // Initialize RevenueCat SDK.
  unawaited(RevenueCatService.instance.init());

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
      title: 'MastUI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const HomeScreen(),
    );
  }
}
