import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppReviewService {
  AppReviewService._();

  static final AppReviewService instance = AppReviewService._();

  static const _promptAttemptedKey = 'play_review_prompt_attempted';
  static const _launchCountKey = 'app_launch_count';
  static const _reviewPromptDelay = Duration(seconds: 45);

  Future<void> requestForReturningUser() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_promptAttemptedKey) ?? false) return;

    final launchCount = prefs.getInt(_launchCountKey) ?? 0;
    if (launchCount < 2) return;

    try {
      final review = InAppReview.instance;
      if (!await review.isAvailable()) return;

      await prefs.setBool(_promptAttemptedKey, true);
      await review.requestReview();
    } catch (_) {
      // Play services can reject the request on non-Play installs or test devices.
    }
  }

  Future<void> trackLaunch() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    final prefs = await SharedPreferences.getInstance();
    final launchCount = prefs.getInt(_launchCountKey) ?? 0;
    await prefs.setInt(_launchCountKey, launchCount + 1);
  }

  void scheduleReturningUserPrompt() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(Future<void>.delayed(
        _reviewPromptDelay,
        requestForReturningUser,
      ));
    });
  }
}
