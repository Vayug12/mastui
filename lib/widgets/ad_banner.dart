import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../services/ad_service.dart';
import '../services/revenue_cat_service.dart';

/// Anchored adaptive banner that collapses to zero height until an ad loads,
/// so the layout never shows an empty ad-sized gap.
class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _ad;
  bool _loaded = false;
  bool _requested = false;

  @override
  void initState() {
    super.initState();
    // Pro is an ad-free plan, so drop the banner the moment someone upgrades
    // (or downgrades) without needing a restart.
    RevenueCatService.instance.addCustomerInfoUpdateListener(_onCustomerInfo);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AdService.supported) _load();
  }

  void _onCustomerInfo(CustomerInfo info) {
    if (!mounted) return;
    if (info.entitlements.active
        .containsKey(RevenueCatService.proEntitlementId)) {
      _ad?.dispose();
      setState(() {
        _ad = null;
        _loaded = false;
        _requested = true; // Never reload for this Pro session.
      });
    }
  }

  Future<void> _load() async {
    // `didChangeDependencies` can fire repeatedly; the flag has to be set
    // before the first await or two loads race through.
    if (_requested) return;
    _requested = true;

    if (await RevenueCatService.instance.isPro() || !mounted) return;

    final width = MediaQuery.sizeOf(context).width.truncate();
    final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
    if (size == null || !mounted) return;

    _ad = BannerAd(
      adUnitId: AdService.instance.bannerUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint(
            'AdMob banner failed to load: ${error.code} ${error.domain} ${error.message}',
          );
          ad.dispose();
          if (mounted) setState(() => _ad = null);
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    RevenueCatService.instance.removeCustomerInfoUpdateListener(_onCustomerInfo);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null || !_loaded) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: SizedBox(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }
}
