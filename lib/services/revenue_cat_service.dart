import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// How a purchase attempt ended, so the UI can tell "user backed out" apart
/// from "something actually broke" — the two need very different treatment.
enum PurchaseOutcome { success, cancelled, failed }

class PurchaseResult {
  const PurchaseResult(this.outcome, {this.customerInfo, this.message});

  final PurchaseOutcome outcome;
  final CustomerInfo? customerInfo;
  final String? message;
}

class RevenueCatService {
  RevenueCatService._();
  static final RevenueCatService instance = RevenueCatService._();

  /// RevenueCat Test Store key — works on both platforms, debug builds only.
  static const _testApiKey = 'test_DNzaAoysoGxflcgSmJKNfGfIjgc';

  // Public SDK keys from RevenueCat → Project settings → API keys.
  // Android keys start with `goog_`, iOS keys with `appl_`; they are NOT
  // interchangeable — using the iOS key on Android fails every call.
  // TODO(mastui): paste the real keys before building a release.
  static const _androidApiKey = 'goog_YOUR_ANDROID_KEY';
  static const _iosApiKey = 'appl_YOUR_IOS_KEY';

  static String get _apiKey {
    if (kDebugMode) return _testApiKey;
    return Platform.isAndroid ? _androidApiKey : _iosApiKey;
  }

  static const proEntitlementId = 'mast_ui_pro';

  Future<void>? _initFuture;

  /// Safe to call more than once; every later call awaits the first one.
  Future<void> init({String? appUserId}) =>
      _initFuture ??= _configure(appUserId);

  Future<void> _configure(String? appUserId) async {
    await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.info);

    final config = PurchasesConfiguration(_apiKey);
    if (appUserId != null) {
      config.appUserID = appUserId;
    }
    await Purchases.configure(config);

    // A reinstall gets a brand-new anonymous app user id, so a paying customer
    // would look free until they found the Restore button. Play can be asked
    // silently for purchases it already knows about, which fixes that without
    // any user action. iOS is left out on purpose — restoring there can pop an
    // Apple ID sign-in prompt, so it stays behind the explicit button.
    if (Platform.isAndroid) {
      try {
        await Purchases.syncPurchases();
      } catch (e) {
        debugPrint('RevenueCat: syncPurchases failed – $e');
      }
    }
  }

  /// `main()` kicks off [init] without awaiting it, so every call below has to
  /// wait for configuration itself — otherwise an early `isPro()` throws
  /// "singleton instance not configured" and silently reports "not Pro".
  Future<void> _ready() => _initFuture ??= _configure(null);

  Future<Offerings?> fetchOfferings() async {
    try {
      await _ready();
      return await Purchases.getOfferings();
    } catch (e) {
      // Not just PlatformException: where the plugin is absent altogether
      // (widget tests, unsupported platforms) the channel throws
      // MissingPluginException, and an offerings failure must never be fatal.
      debugPrint('RevenueCat: Failed to fetch offerings – $e');
      return null;
    }
  }

  Future<PurchaseResult> purchasePackage(Package package) async {
    try {
      await _ready();
      final result = await Purchases.purchase(PurchaseParams.package(package));
      return PurchaseResult(
        PurchaseOutcome.success,
        customerInfo: result.customerInfo,
      );
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        return const PurchaseResult(PurchaseOutcome.cancelled);
      }
      debugPrint('RevenueCat: Purchase failed – $code ${e.message}');
      return PurchaseResult(
        PurchaseOutcome.failed,
        message: _messageFor(code),
      );
    }
  }

  String _messageFor(PurchasesErrorCode code) {
    switch (code) {
      case PurchasesErrorCode.networkError:
        return 'No internet connection. Please try again.';
      case PurchasesErrorCode.paymentPendingError:
        return 'Payment is pending. Pro unlocks once it clears.';
      case PurchasesErrorCode.productAlreadyPurchasedError:
        return 'You already own this — tap Restore.';
      case PurchasesErrorCode.storeProblemError:
        return 'The store is unavailable right now. Please try again.';
      case PurchasesErrorCode.purchaseNotAllowedError:
        return 'Purchases are not allowed on this device.';
      default:
        return 'Purchase could not be completed. Please try again.';
    }
  }

  Future<CustomerInfo> restorePurchases() async {
    await _ready();
    return Purchases.restorePurchases();
  }

  Future<LogInResult> logIn(String appUserId) async {
    await _ready();
    return Purchases.logIn(appUserId);
  }

  Future<CustomerInfo> logOut() async {
    await _ready();
    return Purchases.logOut();
  }

  Future<CustomerInfo> getCustomerInfo() async {
    await _ready();
    return Purchases.getCustomerInfo();
  }

  /// The id the Worker uses to verify entitlements with RevenueCat's REST API.
  Future<String?> appUserId() async {
    try {
      await _ready();
      return await Purchases.appUserID;
    } catch (e) {
      debugPrint('RevenueCat: Could not read appUserID – $e');
      return null;
    }
  }

  /// Never throws — the Generate tab checks this while it is being built, so a
  /// failure here has to degrade to "free", not take the frame down with it.
  Future<bool> isPro() async {
    try {
      final customerInfo = await getCustomerInfo();
      return customerInfo.entitlements.active.containsKey(proEntitlementId);
    } catch (e) {
      debugPrint('RevenueCat: Entitlement check failed – $e');
      return false;
    }
  }

  void addCustomerInfoUpdateListener(CustomerInfoUpdateListener listener) {
    Purchases.addCustomerInfoUpdateListener(listener);
  }

  void removeCustomerInfoUpdateListener(CustomerInfoUpdateListener listener) {
    Purchases.removeCustomerInfoUpdateListener(listener);
  }
}
