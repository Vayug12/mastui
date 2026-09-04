import 'dart:async';

import 'package:flutter/material.dart';

import '../services/app_review_service.dart';
import '../theme/app_colors.dart';
import 'home_screen.dart';

/// Main container shell for the application.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  @override
  void initState() {
    super.initState();
    unawaited(AppReviewService.instance.trackLaunch());
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: HomeScreen(),
    );
  }
}
