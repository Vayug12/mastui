import 'package:flutter/material.dart';

import '../services/subscription_service.dart';
import '../theme/app_colors.dart';
import 'remove_ads_paywall_sheet.dart';

/// Minimalist AppBar capsule for "Remove Ads".
/// Strictly follows mastui/design.md (Inter font, minimal text, 8pt grid, 14px radius).
class RemoveAdsCapsule extends StatelessWidget {
  const RemoveAdsCapsule({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: SubscriptionService.instance.isAdFreeNotifier,
      builder: (context, isAdFree, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.button),
              onTap: () => RemoveAdsPaywallSheet.show(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isAdFree
                      ? AppColors.secondaryGreenSubtle
                      : AppColors.secondaryBackground,
                  borderRadius: BorderRadius.circular(AppRadius.button),
                  border: Border.all(
                    color: isAdFree
                        ? AppColors.secondaryGreen.withAlpha(50)
                        : AppColors.border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isAdFree ? Icons.check_rounded : Icons.block_rounded,
                      size: 13,
                      color: isAdFree
                          ? AppColors.secondaryGreen
                          : AppColors.textPrimary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isAdFree ? 'Ad-Free' : 'Remove Ads',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isAdFree
                            ? AppColors.secondaryGreen
                            : AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
