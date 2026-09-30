import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/lead_model.dart';
import '../services/decision_maker_service.dart';
import '../services/duckduckgo_search_service.dart';
import '../services/email_verification_service.dart';
import '../theme/app_colors.dart';
import 'lead_detail_bottom_sheet.dart';

/// Clean, minimal lead item card adhering to mastui/design.md.
/// Soft 18px corners, white background, #10A37F subtle accent, no heavy borders.
class LeadCard extends StatefulWidget {
  final Lead lead;
  final VoidCallback? onDelete;
  final ValueChanged<Lead>? onLeadUpdated;

  const LeadCard({
    super.key,
    required this.lead,
    this.onDelete,
    this.onLeadUpdated,
  });

  @override
  State<LeadCard> createState() => _LeadCardState();
}

class _LeadCardState extends State<LeadCard> {
  bool _isEnriching = false;

  Lead get lead => widget.lead;

  Future<void> _launchUrl(String urlString) async {
    final cleanUrl = DuckDuckGoSearchService.instance.cleanRedirectUrl(urlString);
    final uri = Uri.tryParse(cleanUrl);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String? _getWhatsAppDigits(String? phone) {
    if (phone == null || phone.trim().isEmpty) return null;
    var digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;
    if (digits.length == 10) {
      if (RegExp(r'^[6-9]').hasMatch(digits)) {
        digits = '91$digits';
      } else {
        digits = '1$digits';
      }
    }
    return digits.length >= 10 ? digits : null;
  }

  Future<void> _openWhatsApp(String phone) async {
    final digits = _getWhatsAppDigits(phone);
    if (digits == null) return;
    final uri = Uri.parse('https://wa.me/$digits');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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

  Future<void> _enrichDecisionMaker() async {
    if (_isEnriching) return;
    setState(() => _isEnriching = true);

    try {
      final result = await DecisionMakerService.instance.enrichDecisionMaker(lead);
      if (!mounted) return;

      if (result != null) {
        final updatedLead = lead.copyWith(
          decisionMakerName: result.name,
          decisionMakerRole: result.role,
          decisionMakerLinkedIn: result.linkedInUrl,
          decisionMakerEmail: result.email,
        );
        widget.onLeadUpdated?.call(updatedLead);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Found: ${result.name} (${result.role})',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: AppColors.secondaryGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'No verified Founder/CEO profile found for this business.',
              style: TextStyle(color: Colors.white, fontSize: 13),
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Search lookup error. Please try again.',
              style: TextStyle(color: Colors.white, fontSize: 13),
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
    } finally {
      if (mounted) {
        setState(() => _isEnriching = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasEmail = lead.email != null && lead.email!.trim().isNotEmpty;
    final hasPhone = lead.phone != null && lead.phone!.trim().isNotEmpty;
    final hasWhatsApp = _getWhatsAppDigits(lead.phone) != null;
    final hasWebsite = lead.website != null && lead.website!.trim().isNotEmpty;
    final hasContactInfo = hasEmail || hasPhone || hasWebsite;
    final hasDecisionMaker = lead.decisionMakerName != null && lead.decisionMakerName!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.divider, width: 1),
        boxShadow: AppShadows.softCard,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: () => LeadDetailBottomSheet.show(
            context,
            lead: lead,
            onDelete: widget.onDelete,
            onLeadUpdated: widget.onLeadUpdated,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row: Clickable Platform Badge (opens profile) + Expand Cue + Delete button
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
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: AppColors.textDisabled,
                    ),
                    if (widget.onDelete != null) ...[
                      const SizedBox(width: 2),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 16),
                        color: AppColors.textMuted,
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        splashRadius: 16,
                        tooltip: 'Remove',
                        onPressed: widget.onDelete,
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
                      color: AppColors.secondaryBlue,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
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
                          const SizedBox(width: 6),
                          _EmailVerifiedBadge(
                            email: lead.email!.trim(),
                            isWorkEmail: lead.isWorkEmail,
                            emailStatus: lead.emailStatus,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
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
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _copyToClipboard(context, lead.phone!.trim(), 'Phone'),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.phone_outlined,
                            size: 15,
                            color: AppColors.secondaryGreen,
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
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.copy_rounded,
                            size: 13,
                            color: AppColors.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (hasWhatsApp) ...[
                  const SizedBox(width: 8),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _openWhatsApp(lead.phone!),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryBackground,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.divider, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 12,
                              color: AppColors.secondaryGreen,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'WhatsApp',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
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
                    color: AppColors.secondaryBlue,
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

          // Decision Maker / Founder Section (Method 2 On-Demand CEO Enrichment)
          const SizedBox(height: 10),
          if (hasDecisionMaker) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.secondaryBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.divider, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        '👑',
                        style: TextStyle(fontSize: 13),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${lead.decisionMakerName!} (${lead.decisionMakerRole ?? "Founder & CEO"})',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (lead.decisionMakerLinkedIn != null &&
                          lead.decisionMakerLinkedIn!.isNotEmpty) ...[
                        InkWell(
                          onTap: () => _launchUrl(lead.decisionMakerLinkedIn!),
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Row(
                              children: const [
                                Text(
                                  'LinkedIn',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.secondaryBlue,
                                  ),
                                ),
                                SizedBox(width: 2),
                                Icon(
                                  Icons.arrow_outward_rounded,
                                  size: 11,
                                  color: AppColors.secondaryBlue,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (lead.decisionMakerEmail != null &&
                      lead.decisionMakerEmail!.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () => _copyToClipboard(
                        context,
                        lead.decisionMakerEmail!.trim(),
                        'Founder Email',
                      ),
                      borderRadius: BorderRadius.circular(6),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.mail_outline_rounded,
                            size: 13,
                            color: AppColors.secondaryGreen,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              lead.decisionMakerEmail!.trim(),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.divider, width: 1),
                            ),
                            child: const Text(
                              'Direct Work',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: AppColors.secondaryGreen,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.copy_rounded,
                            size: 12,
                            color: AppColors.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ] else ...[
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isEnriching ? null : _enrichDecisionMaker,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.divider, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isEnriching) ...[
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.textPrimary),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Finding Decision Maker...',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ] else ...[
                        const Text(
                          '👑',
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          'Find Founder / CEO',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 3),
                        const Icon(
                          Icons.search_rounded,
                          size: 12,
                          color: AppColors.textMuted,
                        ),
                      ],
                    ],
                  ),
                ),
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
    ),
  ),
),
    );
  }
}

/// Minimal email verification badge adhering to mastui/design.md.
class _EmailVerifiedBadge extends StatelessWidget {
  final String email;
  final bool isWorkEmail;
  final String? emailStatus;

  const _EmailVerifiedBadge({
    required this.email,
    this.isWorkEmail = false,
    this.emailStatus,
  });

  @override
  Widget build(BuildContext context) {
    if (isWorkEmail && emailStatus == 'verified') {
      return _buildBadge(
        label: 'Verified Work',
        icon: Icons.verified_rounded,
        color: AppColors.secondaryGreen,
      );
    }

    final cached = EmailVerificationService.instance.isTrustedOrCached(email);
    if (cached == true) {
      return _buildBadge(
        label: 'Verified',
        icon: Icons.check_circle_outline_rounded,
        color: AppColors.secondaryGreen,
      );
    }
    if (cached == false) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<bool>(
      future: EmailVerificationService.instance.isEmailValid(email),
      builder: (context, snapshot) {
        if (snapshot.data == true) {
          return _buildBadge(
            label: 'Verified',
            icon: Icons.check_circle_outline_rounded,
            color: AppColors.secondaryGreen,
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildBadge({
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 11,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
