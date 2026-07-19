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

  // Debug builds always use Google's sample unit — clicking real ads on a
  // dev device risks an AdMob account ban. The real unit serves only in
  // release.
  static const _bannerUnitId = kDebugMode
      ? 'ca-app-pub-3940256099942544/9214589741'
      : 'ca-app-pub-2359959043864469/2653514229';

  String get bannerUnitId => _bannerUnitId;

  Future<void> init() async {
    if (!supported) return;
    await MobileAds.instance.initialize();
  }
}
