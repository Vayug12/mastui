import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/lead_model.dart';
import '../theme/app_colors.dart';

/// Clean, minimal lead item card adhering to mastui/design.md.
/// Soft 18px corners, white background, #10A37F subtle accent, no heavy borders.
class LeadCard extends StatelessWidget {
  final Lead lead;
  final VoidCallback? onDelete;

  const LeadCard({
    super.key,
    required this.lead,
    this.onDelete,
  });

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.tryParse(urlString);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$label copied to clipboard',
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.textPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasEmail = lead.email != null && lead.email!.trim().isNotEmpty;
    final hasPhone = lead.phone != null && lead.phone!.trim().isNotEmpty;
    final hasWebsite = lead.website != null && lead.website!.trim().isNotEmpty;
    final hasContactInfo = hasEmail || hasPhone || hasWebsite;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.divider, width: 1),
        boxShadow: AppShadows.softCard,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Clickable Platform Badge (opens profile) + Delete button
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: lead.profileUrl.isNotEmpty
                          ? () => _launchUrl(lead.profileUrl)
                          : null,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryBackground,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.divider, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              lead.platform,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                                letterSpacing: 0.2,
                              ),
                            ),
                            if (lead.profileUrl.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.arrow_outward_rounded,
                                size: 11,
                                color: AppColors.textMuted,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (onDelete != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  color: AppColors.textMuted,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  splashRadius: 16,
                  tooltip: 'Remove',
                  onPressed: onDelete,
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),

          // Business / Title Name
          Text(
            lead.displayName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              letterSpacing: -0.2,
            ),
          ),

          if (lead.businessName != null &&
              lead.name.isNotEmpty &&
              lead.name != lead.businessName) ...[
            const SizedBox(height: 2),
            Text(
              lead.name,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary,
              ),
            ),
          ],

          // Contact Details Divider (only shown if at least one contact field exists)
          if (hasContactInfo) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 10),
          ],

          // Contact Items: Email (only shown if present in this specific lead)
          if (hasEmail) ...[
            InkWell(
              onTap: () => _copyToClipboard(context, lead.email!.trim(), 'Email'),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.mail_outline_rounded,
                      size: 15,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        lead.email!.trim(),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(
                      Icons.copy_rounded,
                      size: 13,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Contact Items: Phone (only shown if present in this specific lead)
          if (hasPhone) ...[
            const SizedBox(height: 4),
            InkWell(
              onTap: () => _copyToClipboard(context, lead.phone!.trim(), 'Phone'),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.phone_outlined,
                      size: 15,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        lead.phone!.trim(),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(
                      Icons.copy_rounded,
                      size: 13,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Contact Items: Website (only shown if present with IconButton link)
          if (hasWebsite) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  const Icon(
                    Icons.language_rounded,
                    size: 15,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () => _launchUrl(lead.website!.trim()),
                      borderRadius: BorderRadius.circular(4),
                      child: Text(
                        lead.website!.trim(),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.divider,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.open_in_new_rounded, size: 15),
                    color: AppColors.textMuted,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    splashRadius: 14,
                    tooltip: 'Open website',
                    onPressed: () => _launchUrl(lead.website!.trim()),
                  ),
                ],
              ),
            ),
          ],

          // Bio Snippet (only shown if present)
          if (lead.bioSnippet != null && lead.bioSnippet!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              lead.bioSnippet!.trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
