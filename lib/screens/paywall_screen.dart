import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_links.dart';
import '../services/revenue_cat_service.dart';
import '../theme/app_colors.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  List<Package> _packages = const [];
  Package? _selected;
  bool _isLoading = true;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    final offerings = await RevenueCatService.instance.fetchOfferings();
    if (!mounted) return;

    final packages = _sorted(offerings?.current?.availablePackages ?? const []);
    setState(() {
      _packages = packages;
      _selected = packages.isEmpty ? null : packages.first;
      _isLoading = false;
    });
  }

  /// Longest plan first — the yearly deal is what we want people to land on.
  static List<Package> _sorted(List<Package> packages) {
    const rank = {
      PackageType.annual: 0,
      PackageType.sixMonth: 1,
      PackageType.threeMonth: 2,
      PackageType.twoMonth: 3,
      PackageType.monthly: 4,
      PackageType.weekly: 5,
      PackageType.lifetime: 6,
    };
    return [...packages]..sort(
        (a, b) => (rank[a.packageType] ?? 9).compareTo(rank[b.packageType] ?? 9),
      );
  }

  Future<void> _purchase() async {
    final package = _selected;
    if (package == null || _isBusy) return;

    setState(() => _isBusy = true);
    final result = await RevenueCatService.instance.purchasePackage(package);
    if (!mounted) return;
    setState(() => _isBusy = false);

    switch (result.outcome) {
      case PurchaseOutcome.success:
        _close(subscribed: true, message: 'You\'re on Mast UI Pro 🎉');
      case PurchaseOutcome.cancelled:
        break; // The user backed out on purpose — stay quiet.
      case PurchaseOutcome.failed:
        _snack(result.message ?? 'Purchase could not be completed');
    }
  }

  Future<void> _restore() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);

    try {
      final info = await RevenueCatService.instance.restorePurchases();
      if (!mounted) return;
      if (info.entitlements.active
          .containsKey(RevenueCatService.proEntitlementId)) {
        _close(subscribed: true, message: 'Pro restored');
      } else {
        _snack('Nothing to restore on this account');
      }
    } catch (_) {
      if (mounted) _snack('Could not restore. Please try again.');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Shows the snackbar on the app-level messenger *before* popping, so it
  /// survives this route going away.
  void _close({required bool subscribed, required String message}) {
    _snack(message);
    Navigator.of(context).pop(subscribed);
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.close, size: 24),
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : _packages.isEmpty
                      ? _buildError()
                      : _buildContent(),
            ),
          ],
        ),
      ),
      bottomNavigationBar:
          _isLoading || _packages.isEmpty ? null : _buildFooter(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 32, color: AppColors.textHint),
            const SizedBox(height: 14),
            Text('Plans didn\'t load',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Check your connection and try again.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                setState(() => _isLoading = true);
                _loadOfferings();
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final monthlyMatches =
        _packages.where((p) => p.packageType == PackageType.monthly);
    final monthly = monthlyMatches.isEmpty ? null : monthlyMatches.first;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      children: [
        Center(
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Mast UI Pro',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Turn any screenshot into an AI prompt.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        // Deliberately not "unlimited" — the Worker caps Pro at 50/day to
        // protect the shared AI budget, so claiming otherwise would be false.
        const _Perk('50 prompts a day, up from 4'),
        const _Perk('No ads'),
        const _Perk('New features first'),
        const SizedBox(height: 24),
        for (final package in _packages) ...[
          _PlanTile(
            package: package,
            monthlyReference: monthly,
            isSelected: package.identifier == _selected?.identifier,
            onTap: _isBusy ? null : () => setState(() => _selected = package),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildFooter() {
    final selected = _selected;
    final isLifetime = selected?.packageType == PackageType.lifetime;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isBusy || selected == null ? null : _purchase,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
              ),
              child: _isBusy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(isLifetime ? 'Buy Lifetime' : 'Start Pro'),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isLifetime
                ? 'One-time payment. Yours forever.'
                : 'Renews automatically. Cancel anytime.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textHint),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _FooterLink('Restore', onTap: _isBusy ? null : _restore),
              const _FooterDot(),
              _FooterLink('Terms', onTap: () => _openUrl(AppLinks.terms)),
              const _FooterDot(),
              _FooterLink('Privacy', onTap: () => _openUrl(AppLinks.privacy)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Perk extends StatelessWidget {
  const _Perk(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({
    required this.package,
    required this.monthlyReference,
    required this.isSelected,
    required this.onTap,
  });

  final Package package;

  /// Used to work out the "Save X%" badge on longer plans.
  final Package? monthlyReference;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final product = package.storeProduct;
    final badge = _badge();

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.duration,
        curve: AppMotion.curve,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 22,
              color: isSelected ? AppColors.primary : AppColors.textHint,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _title(),
                          style: textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge,
                            style: textTheme.bodySmall?.copyWith(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _subtitle(),
                    style: textTheme.bodySmall
                        ?.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              product.priceString,
              style: textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  String _title() {
    switch (package.packageType) {
      case PackageType.annual:
        return 'Yearly';
      case PackageType.sixMonth:
        return '6 months';
      case PackageType.threeMonth:
        return '3 months';
      case PackageType.twoMonth:
        return '2 months';
      case PackageType.monthly:
        return 'Monthly';
      case PackageType.weekly:
        return 'Weekly';
      case PackageType.lifetime:
        return 'Lifetime';
      default:
        return package.storeProduct.title;
    }
  }

  /// Everything is normalised to a per-month figure so the plans are directly
  /// comparable without the user doing the division themselves.
  String _subtitle() {
    final months = _months();
    if (months == null) return 'Pay once, keep forever';

    final perMonth = package.storeProduct.price / months;
    return '${_withPrice(package.storeProduct.priceString, perMonth)} per month';
  }

  String? _badge() {
    if (package.packageType == PackageType.lifetime) return 'One-time';

    final months = _months();
    final reference = monthlyReference?.storeProduct.price;
    if (months == null || months <= 1 || reference == null || reference <= 0) {
      return null;
    }

    final saving =
        1 - (package.storeProduct.price / months) / reference;
    if (saving < 0.05) return null;
    return 'Save ${(saving * 100).round()}%';
  }

  int? _months() {
    switch (package.packageType) {
      case PackageType.annual:
        return 12;
      case PackageType.sixMonth:
        return 6;
      case PackageType.threeMonth:
        return 3;
      case PackageType.twoMonth:
        return 2;
      case PackageType.monthly:
        return 1;
      default:
        return null; // Lifetime / weekly / custom — no monthly equivalent.
    }
  }

  /// Swaps the number inside a store-formatted price ("US$79.98") so the
  /// derived figure keeps the store's currency symbol and placement.
  static String _withPrice(String priceString, double value) {
    final match = RegExp(r'\d[\d.,\s]*').firstMatch(priceString);
    final formatted = value.toStringAsFixed(2);
    if (match == null) return formatted;
    return priceString.replaceRange(match.start, match.end, formatted);
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink(this.label, {required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        minimumSize: Size.zero,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: AppColors.textMuted),
      ),
    );
  }
}

class _FooterDot extends StatelessWidget {
  const _FooterDot();

  @override
  Widget build(BuildContext context) {
    return const Text('·', style: TextStyle(color: AppColors.textHint));
  }
}

/// Shows the paywall and returns true if the user came out of it with Pro.
Future<bool> showPaywall(BuildContext context) async {
  final result = await Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => const PaywallScreen()),
  );
  return result == true;
}
