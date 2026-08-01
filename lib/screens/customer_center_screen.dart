import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_links.dart';
import '../services/revenue_cat_service.dart';
import '../theme/app_colors.dart';
import 'paywall_screen.dart';

class CustomerCenterScreen extends StatefulWidget {
  const CustomerCenterScreen({super.key});

  @override
  State<CustomerCenterScreen> createState() => _CustomerCenterScreenState();
}

class _CustomerCenterScreenState extends State<CustomerCenterScreen> {
  CustomerInfo? _customerInfo;
  bool _isLoading = true;
  String? _version;

  @override
  void initState() {
    super.initState();
    _loadCustomerInfo();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _version = '${info.version} (${info.buildNumber})');
  }

  Future<void> _loadCustomerInfo() async {
    try {
      final info = await RevenueCatService.instance.getCustomerInfo();
      if (!mounted) return;
      setState(() {
        _customerInfo = info;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Subscription')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _customerInfo == null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 32, color: AppColors.textHint),
            const SizedBox(height: 14),
            Text('Could not load your subscription',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                setState(() => _isLoading = true);
                _loadCustomerInfo();
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final pro = _customerInfo!
        .entitlements.active[RevenueCatService.proEntitlementId];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (pro == null) _buildFreeCard() else _ProCard(entitlement: pro),
        const SizedBox(height: 28),
        if (pro != null) ...[
          // RevenueCat cannot cancel for the user — only the store can, so this
          // deep-links there. Both stores require the link to exist in-app.
          _Option(
            icon: Icons.open_in_new,
            title: 'Change or cancel plan',
            subtitle: Platform.isAndroid ? 'Opens Google Play' : 'Opens the App Store',
            onTap: _openStoreSubscriptions,
          ),
          const SizedBox(height: 8),
        ],
        _Option(
          icon: Icons.restore,
          title: 'Restore purchases',
          subtitle: 'Already paid on another device?',
          onTap: _restorePurchases,
        ),
        const SizedBox(height: 8),
        _Option(
          icon: Icons.mail_outline,
          title: 'Contact support',
          subtitle: AppLinks.supportEmail,
          onTap: _openSupport,
        ),
        const SizedBox(height: 8),
        _Option(
          icon: Icons.description_outlined,
          title: 'Terms of Service',
          onTap: () => _openUrl(AppLinks.terms),
        ),
        const SizedBox(height: 8),
        _Option(
          icon: Icons.privacy_tip_outlined,
          title: 'Privacy Policy',
          onTap: () => _openUrl(AppLinks.privacy),
        ),
        const SizedBox(height: 32),
        Text(
          _version == null ? '' : 'Mast UI $_version',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.textHint),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFreeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text('Free plan', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            '4 prompts a day. Upgrade for 50 a day, ad-free.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _openPaywall,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
              ),
              child: const Text('See plans'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openPaywall() async {
    final subscribed = await showPaywall(context);
    if (subscribed && mounted) _loadCustomerInfo();
  }

  Future<void> _restorePurchases() async {
    try {
      final info = await RevenueCatService.instance.restorePurchases();
      if (!mounted) return;

      setState(() => _customerInfo = info);
      _snack(
        info.entitlements.active.containsKey(RevenueCatService.proEntitlementId)
            ? 'Pro restored'
            : 'Nothing to restore on this account',
      );
    } catch (e) {
      if (mounted) _snack('Could not restore. Please try again.');
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openStoreSubscriptions() => _openUrl(
        Platform.isAndroid
            ? AppLinks.androidManageSubscriptions
            : AppLinks.iosManageSubscriptions,
      );

  Future<void> _openSupport() async {
    final uri = Uri(
      scheme: 'mailto',
      path: AppLinks.supportEmail,
      queryParameters: {'subject': 'Mast UI support'},
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      _snack('No email app found. Write to ${AppLinks.supportEmail}');
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      _snack('Could not open the link');
    }
  }
}

class _ProCard extends StatelessWidget {
  const _ProCard({required this.entitlement});

  final EntitlementInfo entitlement;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.primary, width: 2),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mast UI Pro',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  _statusLine(),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _statusLine() {
    final expiry = entitlement.expirationDate;
    if (expiry == null) return 'Lifetime access';

    final date = DateTime.tryParse(expiry);
    if (date == null) return 'Active';

    final formatted = '${date.day}/${date.month}/${date.year}';
    // `willRenew` is false once the user cancels but before the term ends —
    // that difference is exactly what people open this screen to check.
    return entitlement.willRenew
        ? 'Renews on $formatted'
        : 'Ends on $formatted';
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.textPrimary),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.textHint),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  size: 20, color: AppColors.textHint),
            ],
          ),
        ),
      ),
    );
  }
}
