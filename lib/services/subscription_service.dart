import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/subscription_plan.dart';

/// Service managing Remove-Ads subscriptions and Google Play In-App Purchases.
/// Strictly follows mastui/AGENT.md rules (no God files, decoupled from UI).
class SubscriptionService {
  SubscriptionService._();
  static final SubscriptionService instance = SubscriptionService._();

  static const String _prefKeyIsAdFree = 'getlead_is_ad_free';
  static const String _prefKeySubId = 'getlead_subscription_id';

  // Standard Google Play In-App Purchase product IDs
  static const String idWeekly = 'getlead_remove_ads_weekly';
  static const String idMonthly = 'getlead_remove_ads_monthly';
  static const String idYearly = 'getlead_remove_ads_yearly';

  static const Set<String> _productIds = {
    idWeekly,
    idMonthly,
    idYearly,
  };

  InAppPurchase? _iapOverride;
  InAppPurchase get _iap => _iapOverride ?? InAppPurchase.instance;

  @visibleForTesting
  void setIapForTesting(InAppPurchase? mock) {
    _iapOverride = mock;
  }

  StreamSubscription<List<PurchaseDetails>>? _subscription;

  final ValueNotifier<bool> isAdFreeNotifier = ValueNotifier<bool>(false);
  bool get isAdFree => isAdFreeNotifier.value;

  final ValueNotifier<bool> isLoadingPlans = ValueNotifier<bool>(false);
  final ValueNotifier<List<SubscriptionPlan>> plansNotifier =
      ValueNotifier<List<SubscriptionPlan>>([]);

  final Map<String, ProductDetails> _storeProductMap = {};

  /// Initialize the service, restore local cached status, and listen for purchase updates.
  Future<void> init({bool enableStore = true}) async {
    await _loadCachedStatus();

    if (enableStore) {
      try {
        final purchaseUpdated = _iap.purchaseStream;
        _subscription = purchaseUpdated.listen(
          _onPurchaseUpdate,
          onDone: () {
            _subscription?.cancel();
          },
          onError: (error) {
            debugPrint('[SubscriptionService] Purchase stream error: $error');
          },
        );
      } catch (e) {
        debugPrint('[SubscriptionService] Stream listen error: $e');
      }
      await fetchPlans();
    } else {
      plansNotifier.value = _buildDefaultPlans();
    }
  }

  Future<void> _loadCachedStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final adFree = prefs.getBool(_prefKeyIsAdFree) ?? false;
      isAdFreeNotifier.value = adFree;
    } catch (e) {
      debugPrint('[SubscriptionService] Error loading cached status: $e');
    }
  }

  Future<void> _persistStatus(bool adFree, {String? subId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeyIsAdFree, adFree);
      if (subId != null) {
        await prefs.setString(_prefKeySubId, subId);
      }
      isAdFreeNotifier.value = adFree;
    } catch (e) {
      debugPrint('[SubscriptionService] Error persisting status: $e');
    }
  }

  /// Fetches real localized country pricing from Google Play Billing.
  /// Falls back to regional defaults if offline or running in simulator.
  Future<void> fetchPlans() async {
    isLoadingPlans.value = true;
    try {
      bool isAvailable = false;
      try {
        isAvailable = await _iap.isAvailable();
      } catch (e) {
        debugPrint('[SubscriptionService] Store check error: $e');
        isAvailable = false;
      }
      if (!isAvailable) {
        debugPrint('[SubscriptionService] Store unavailable, using regional defaults');
        plansNotifier.value = _buildDefaultPlans();
        return;
      }

      final response = await _iap.queryProductDetails(_productIds);
      if (response.error != null) {
        debugPrint('[SubscriptionService] Query error: ${response.error!.message}');
        plansNotifier.value = _buildDefaultPlans();
        return;
      }

      if (response.productDetails.isEmpty) {
        plansNotifier.value = _buildDefaultPlans();
        return;
      }

      _storeProductMap.clear();
      for (final p in response.productDetails) {
        _storeProductMap[p.id] = p;
      }

      // Map Google Play localized products to our immutable models
      final plans = <SubscriptionPlan>[];

      // Weekly
      final weeklyProd = _storeProductMap[idWeekly];
      plans.add(
        SubscriptionPlan(
          id: idWeekly,
          title: 'Weekly',
          price: weeklyProd?.price ?? '₹99',
          billingPeriod: '/ week',
          currencyCode: weeklyProd?.currencyCode ?? 'INR',
        ),
      );

      // Monthly
      final monthlyProd = _storeProductMap[idMonthly];
      plans.add(
        SubscriptionPlan(
          id: idMonthly,
          title: 'Monthly',
          price: monthlyProd?.price ?? '₹299',
          billingPeriod: '/ month',
          currencyCode: monthlyProd?.currencyCode ?? 'INR',
        ),
      );

      // Yearly (Best value)
      final yearlyProd = _storeProductMap[idYearly];
      plans.add(
        SubscriptionPlan(
          id: idYearly,
          title: 'Yearly',
          price: yearlyProd?.price ?? '₹1,999',
          billingPeriod: '/ year',
          badge: 'Save 60%',
          isPopular: true,
          currencyCode: yearlyProd?.currencyCode ?? 'INR',
        ),
      );

      plansNotifier.value = plans;
    } catch (e) {
      debugPrint('[SubscriptionService] fetchPlans error: $e');
      plansNotifier.value = _buildDefaultPlans();
    } finally {
      isLoadingPlans.value = false;
    }
  }

  /// Regional fallback plans (Purchasing Power Parity for India).
  List<SubscriptionPlan> _buildDefaultPlans() {
    return const [
      SubscriptionPlan(
        id: idWeekly,
        title: 'Weekly',
        price: '₹99',
        billingPeriod: '/ week',
      ),
      SubscriptionPlan(
        id: idMonthly,
        title: 'Monthly',
        price: '₹299',
        billingPeriod: '/ month',
      ),
      SubscriptionPlan(
        id: idYearly,
        title: 'Yearly',
        price: '₹1,999',
        billingPeriod: '/ year',
        badge: 'Save 60%',
        isPopular: true,
      ),
    ];
  }

  /// Initiate subscription purchase through Google Play Billing.
  /// Returns null on success or when billing starts, or an error message string on failure.
  Future<String?> subscribe(SubscriptionPlan plan) async {
    try {
      final productDetails = _storeProductMap[plan.id];
      if (productDetails == null) {
        // In debug mode, simulate instant activation for developer testing
        if (kDebugMode) {
          await _persistStatus(true, subId: plan.id);
          return null;
        }
        return "Subscription product '${plan.id}' is not yet active in Google Play Console. Please configure it in your Play Console dashboard.";
      }

      final purchaseParam = PurchaseParam(productDetails: productDetails);
      final launched = await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      if (!launched) {
        return 'Unable to start Google Play checkout. Please try again.';
      }
      return null;
    } catch (e) {
      debugPrint('[SubscriptionService] Buy error: $e');
      return 'Billing error: $e';
    }
  }

  /// Restore existing purchases from Google Play.
  Future<bool> restorePurchases() async {
    try {
      final isAvailable = await _iap.isAvailable();
      if (!isAvailable) return false;
      await _iap.restorePurchases();
      return true;
    } catch (e) {
      debugPrint('[SubscriptionService] Restore error: $e');
      return false;
    }
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        debugPrint('[SubscriptionService] Purchase pending...');
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          debugPrint('[SubscriptionService] Purchase error: ${purchaseDetails.error}');
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          debugPrint('[SubscriptionService] Success: ${purchaseDetails.productID}');
          _persistStatus(true, subId: purchaseDetails.productID);
        }

        if (purchaseDetails.pendingCompletePurchase) {
          _iap.completePurchase(purchaseDetails);
        }
      }
    }
  }

  void dispose() {
    _subscription?.cancel();
    isAdFreeNotifier.dispose();
    isLoadingPlans.dispose();
    plansNotifier.dispose();
  }
}
