import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Central place for ads SDK setup and ad unit IDs.
class AdService {
  AdService._();

  static final AdService instance = AdService._();

  /// google_mobile_ads only supports Android and iOS.
  static bool get supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Google official test Rewarded Ad Unit ID for Android (Account ban se bachane ke liye):
  /// 'ca-app-pub-3940256099942544/5224354917'
  ///
  /// Production release Rewarded Ad Unit ID (AdMob se generated):
  /// 'ca-app-pub-2359959043864469/6574583914'
  static const _rewardedUnitId = kDebugMode
      ? 'ca-app-pub-3940256099942544/5224354917' // Debug/testing: Always safe Google test ad
      : 'ca-app-pub-2359959043864469/6574583914'; // Production release: Real AdMob ad

  String get rewardedUnitId => _rewardedUnitId;

  RewardedAd? _rewardedAd;
  bool _isRewardedAdLoading = false;

  Future<void> init() async {
    if (!supported) return;
    try {
      await MobileAds.instance.initialize();
      preloadRewardedAd();
    } catch (e) {
      debugPrint('[AdService] Init error: $e');
    }
  }

  /// Preloads a Rewarded Ad so it is ready when the user taps Generate.
  void preloadRewardedAd() {
    if (!supported || _isRewardedAdLoading || _rewardedAd != null) return;

    _isRewardedAdLoading = true;
    RewardedAd.load(
      adUnitId: _rewardedUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          debugPrint('[AdService] Rewarded ad successfully loaded.');
          _rewardedAd = ad;
          _isRewardedAdLoading = false;
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('[AdService] Rewarded ad failed to load: $error');
          _rewardedAd = null;
          _isRewardedAdLoading = false;
        },
      ),
    );
  }

  /// Shows the Rewarded Ad if available.
  /// If the ad is not ready or fails, this returns immediately without blocking.
  void showRewardedAd({
    void Function(RewardItem reward)? onUserEarnedReward,
    VoidCallback? onDismissed,
  }) {
    if (!supported) return;

    if (_rewardedAd == null) {
      debugPrint('[AdService] Rewarded ad not ready yet. Preloading for next time.');
      preloadRewardedAd();
      return;
    }

    final ad = _rewardedAd!;
    _rewardedAd = null; // Clear reference before showing

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        debugPrint('[AdService] Rewarded ad showed full screen.');
      },
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('[AdService] Rewarded ad dismissed.');
        ad.dispose();
        onDismissed?.call();
        preloadRewardedAd(); // Preload next ad
      },
      onAdFailedToShowFullScreenContent: (ad, AdError error) {
        debugPrint('[AdService] Rewarded ad failed to show: $error');
        ad.dispose();
        onDismissed?.call();
        preloadRewardedAd();
      },
    );

    try {
      ad.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
          debugPrint('[AdService] User earned reward: ${reward.amount} ${reward.type}');
          onUserEarnedReward?.call(reward);
        },
      );
    } catch (e) {
      debugPrint('[AdService] Error presenting ad: $e');
      preloadRewardedAd();
    }
  }

  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
  }
}
