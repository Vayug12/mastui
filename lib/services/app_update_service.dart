import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';

import '../theme/app_colors.dart';

/// Service managing non-blocking in-app updates using Google Play In-App Updates API.
class AppUpdateService {
  AppUpdateService._();

  static final AppUpdateService instance = AppUpdateService._();

  bool _isChecking = false;
  StreamSubscription<InstallStatus>? _installStatusSubscription;

  /// Checks for available updates and initiates a flexible (background) update
  /// if one is available.
  ///
  /// This operation is completely non-blocking:
  /// - Downloads run in the background via Google Play.
  /// - The user continues using the app uninterrupted.
  /// - Once downloaded, a non-intrusive floating SnackBar notifies the user
  ///   with a "RESTART" action to finalize installation.
  /// - [showFeedbackIfNoUpdate] is true only when manually triggered by the user
  ///   (e.g., from Settings or More menu) so they receive visual feedback.
  Future<void> checkForFlexibleUpdate(
    BuildContext context, {
    bool showFeedbackIfNoUpdate = false,
  }) async {
    // In-App Updates are only supported on Android Play Store installations.
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      if (showFeedbackIfNoUpdate && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Updates are managed via Google Play.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (_isChecking) return;
    _isChecking = true;

    try {
      final updateInfo = await InAppUpdate.checkForUpdate();
      if (!context.mounted) return;

      // Case 1: An update was already downloaded in a previous session
      if (updateInfo.installStatus == InstallStatus.downloaded) {
        _showRestartSnackBar(context);
        return;
      }

      // Case 2: An update is available and flexible update is allowed
      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable &&
          updateInfo.flexibleUpdateAllowed) {
        // Listen for download completion
        _listenForDownloadCompletion(context);

        // Request Google Play to begin the flexible download
        final result = await InAppUpdate.startFlexibleUpdate();
        if (result != AppUpdateResult.success) {
          _installStatusSubscription?.cancel();
          _installStatusSubscription = null;
        }
      } else if (showFeedbackIfNoUpdate) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You are using the latest version.'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // In-app updates fail gracefully when running on debug builds,
      // non-Google Play installations (sideloaded), or if network is unavailable.
      debugPrint('AppUpdateService.checkForFlexibleUpdate error: $e');
      if (showFeedbackIfNoUpdate && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not check for updates. Please check your connection.'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      _isChecking = false;
    }
  }

  void _listenForDownloadCompletion(BuildContext context) {
    _installStatusSubscription?.cancel();
    _installStatusSubscription = InAppUpdate.installUpdateListener.listen(
      (status) {
        if (status == InstallStatus.downloaded) {
          _installStatusSubscription?.cancel();
          _installStatusSubscription = null;

          if (context.mounted) {
            _showRestartSnackBar(context);
          }
        }
      },
      onError: (e) {
        debugPrint('AppUpdateService install status error: $e');
        _installStatusSubscription?.cancel();
        _installStatusSubscription = null;
      },
      cancelOnError: true,
    );
  }

  /// Displays an unobtrusive floating SnackBar notifying the user that
  /// the update is downloaded and ready to apply.
  void _showRestartSnackBar(BuildContext context) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.showSnackBar(
      SnackBar(
        content: const Text(
          'An update has been downloaded.',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primaryCta,
        duration: const Duration(seconds: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
        action: SnackBarAction(
          label: 'RESTART',
          textColor: AppColors.secondaryGreen,
          onPressed: () async {
            try {
              await InAppUpdate.completeFlexibleUpdate();
            } catch (e) {
              debugPrint('Error completing flexible update: $e');
            }
          },
        ),
      ),
    );
  }

  /// Cancels any active listeners.
  void dispose() {
    _installStatusSubscription?.cancel();
    _installStatusSubscription = null;
  }
}
