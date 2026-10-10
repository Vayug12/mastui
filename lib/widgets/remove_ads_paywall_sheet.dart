import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_links.dart';
import '../models/subscription_plan.dart';
import '../services/subscription_service.dart';
import '../theme/app_colors.dart';

/// Minimalist, 100% scroll-safe BottomSheet for Ad-Free subscriptions.
/// Strictly adheres to Google Play Subscriptions Policy & mastui/design.md.
class RemoveAdsPaywallSheet extends StatefulWidget {
  const RemoveAdsPaywallSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.bottomSheet),
        ),
      ),
      builder: (_) => const RemoveAdsPaywallSheet(),
    );
  }

  @override
  State<RemoveAdsPaywallSheet> createState() => _RemoveAdsPaywallSheetState();
}

class _RemoveAdsPaywallSheetState extends State<RemoveAdsPaywallSheet> {
  String? _selectedPlanId;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    final plans = SubscriptionService.instance.plansNotifier.value;
    if (plans.isNotEmpty) {
      final best = plans.firstWhere(
        (p) => p.isPopular,
        orElse: () => plans.first,
      );
      _selectedPlanId = best.id;
    }
  }

  Future<void> _handleSubscribe(List<SubscriptionPlan> plans) async {
    if (plans.isEmpty || _isProcessing) return;

    final plan = plans.firstWhere(
      (p) => p.id == _selectedPlanId,
      orElse: () => plans.first,
    );

    setState(() => _isProcessing = true);
    final error = await SubscriptionService.instance.subscribe(plan);
    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (error == null) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ads removed successfully.'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          duration: const Duration(seconds: 4),
          backgroundColor: AppColors.textPrimary,
        ),
      );
    }
  }

  Future<void> _handleRestore() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    final restored = await SubscriptionService.instance.restorePurchases();
    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (restored) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Purchases restored.'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active subscription found.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Apple HIG Drag Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Scrollable Content
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      const Text(
                        'Remove Ads',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Clear Policy Disclosure: App is free, subscription is only for removing ads
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryBackground,
                          borderRadius: BorderRadius.circular(AppRadius.input),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 16,
                              color: AppColors.secondaryGreen,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'GetLead is completely free. All lead searches, filters, and exports are included. This optional prepaid plan removes all advertisements.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: AppColors.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Plan Cards
                      ValueListenableBuilder<List<SubscriptionPlan>>(
                        valueListenable:
                            SubscriptionService.instance.plansNotifier,
                        builder: (context, plans, _) {
                          if (plans.isEmpty) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24.0),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            );
                          }

                          if (_selectedPlanId == null && plans.isNotEmpty) {
                            _selectedPlanId = plans.first.id;
                          }

                          return Column(
                            children: plans.map((plan) {
                              final isSelected = plan.id == _selectedPlanId;
                              return _buildPlanCard(plan, isSelected);
                            }).toList(),
                          );
                        },
                      ),
                      const SizedBox(height: 6),

                      // Explicit Prepaid Billing Information (Google Play Policy)
                      const Center(
                        child: Text(
                          'Prepaid plan • No recurring auto-debit • Valid for selected duration',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Pinned Primary CTA Button
              ValueListenableBuilder<List<SubscriptionPlan>>(
                valueListenable: SubscriptionService.instance.plansNotifier,
                builder: (context, plans, _) {
                  return SizedBox(
                    height: 52,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryCta,
                        foregroundColor: AppColors.onPrimaryCta,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.button),
                        ),
                      ),
                      onPressed: _isProcessing ? null : () => _handleSubscribe(plans),
                      child: _isProcessing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Remove Ads',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.onPrimaryCta,
                              ),
                            ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 10),

              // Policy Links Row: Terms of Use • Privacy Policy • Restore
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => _openLink(AppLinks.terms),
                    child: const Text(
                      'Terms of Use',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textMuted,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '•',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _openLink(AppLinks.privacy),
                    child: const Text(
                      'Privacy Policy',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textMuted,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '•',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ),
                  GestureDetector(
                    onTap: _isProcessing ? null : _handleRestore,
                    child: const Text(
                      'Restore',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard(SubscriptionPlan plan, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: () {
          setState(() => _selectedPlanId = plan.id);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.surfaceSubtle
                : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              // Radio selection indicator
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textMuted,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Center(
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),

              // Plan title & badge
              Expanded(
                child: Row(
                  children: [
                    Text(
                      '${plan.title} Prepaid',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (plan.badge != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryGreenSubtle,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          plan.badge!,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondaryGreen,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Price
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: plan.price,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    TextSpan(
                      text: ' ${plan.billingPeriod}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
