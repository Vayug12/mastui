import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/lead_model.dart';
import '../services/decision_maker_service.dart';
import '../services/duckduckgo_search_service.dart';
import '../services/email_verification_service.dart';
import '../theme/app_colors.dart';

/// Modal bottom sheet displaying complete, untruncated details of a lead.
/// Adheres strictly to mastui/design.md (Apple HIG / ChatGPT monochrome elegance).
class LeadDetailBottomSheet extends StatefulWidget {
  final Lead lead;
  final VoidCallback? onDelete;
  final ValueChanged<Lead>? onLeadUpdated;

  const LeadDetailBottomSheet({
    super.key,
    required this.lead,
    this.onDelete,
    this.onLeadUpdated,
  });

  /// Static helper to display the sheet with standard styling.
  static Future<void> show(
    BuildContext context, {
    required Lead lead,
    VoidCallback? onDelete,
    ValueChanged<Lead>? onLeadUpdated,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.bottomSheet),
        ),
      ),
      builder: (ctx) => LeadDetailBottomSheet(
        lead: lead,
        onDelete: onDelete,
        onLeadUpdated: onLeadUpdated,
      ),
    );
  }

  @override
  State<LeadDetailBottomSheet> createState() => _LeadDetailBottomSheetState();
}

class _LeadDetailBottomSheetState extends State<LeadDetailBottomSheet> {
  late Lead _currentLead;
  bool _isEnriching = false;

  @override
  void initState() {
    super.initState();
    _currentLead = widget.lead;
  }

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

  Future<void> _callPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _sendEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _copyToClipboard(String text, String label) {
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

  void _shareLead() {
    final buffer = StringBuffer();
    buffer.writeln('📋 ${_currentLead.displayName}');
    if (_currentLead.businessName != null &&
        _currentLead.name.isNotEmpty &&
        _currentLead.name != _currentLead.businessName) {
      buffer.writeln('Contact: ${_currentLead.name}');
    }
    if (_currentLead.email != null && _currentLead.email!.isNotEmpty) {
      buffer.writeln('Email: ${_currentLead.email}');
    }
    if (_currentLead.phone != null && _currentLead.phone!.isNotEmpty) {
      buffer.writeln('Phone: ${_currentLead.phone}');
    }
    if (_currentLead.website != null && _currentLead.website!.isNotEmpty) {
      buffer.writeln('Website: ${_currentLead.website}');
    }
    if (_currentLead.location != null && _currentLead.location!.isNotEmpty) {
      buffer.writeln('Location: ${_currentLead.location}');
    }
    if (_currentLead.niche != null && _currentLead.niche!.isNotEmpty) {
      buffer.writeln('Niche: ${_currentLead.niche}');
    }
    if (_currentLead.decisionMakerName != null &&
        _currentLead.decisionMakerName!.isNotEmpty) {
      buffer.writeln(
          'Decision Maker: ${_currentLead.decisionMakerName} (${_currentLead.decisionMakerRole ?? "CEO"})');
      if (_currentLead.decisionMakerEmail != null &&
          _currentLead.decisionMakerEmail!.isNotEmpty) {
        buffer.writeln('Founder Email: ${_currentLead.decisionMakerEmail}');
      }
    }
    if (_currentLead.bioSnippet != null &&
        _currentLead.bioSnippet!.trim().isNotEmpty) {
      buffer.writeln('\nAbout:\n${_currentLead.bioSnippet!.trim()}');
    }

    SharePlus.instance.share(
      ShareParams(
        text: buffer.toString(),
        subject: _currentLead.displayName,
      ),
    );
  }

  Future<void> _enrichDecisionMaker() async {
    if (_isEnriching) return;
    setState(() => _isEnriching = true);

    try {
      final result =
          await DecisionMakerService.instance.enrichDecisionMaker(_currentLead);
      if (!mounted) return;

      if (result != null) {
        final updated = _currentLead.copyWith(
          decisionMakerName: result.name,
          decisionMakerRole: result.role,
          decisionMakerLinkedIn: result.linkedInUrl,
          decisionMakerEmail: result.email,
        );
        setState(() {
          _currentLead = updated;
        });
        widget.onLeadUpdated?.call(updated);

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
    final lead = _currentLead;
    final hasEmail = lead.email != null && lead.email!.trim().isNotEmpty;
    final hasPhone = lead.phone != null && lead.phone!.trim().isNotEmpty;
    final hasWhatsApp = _getWhatsAppDigits(lead.phone) != null;
    final hasWebsite = lead.website != null && lead.website!.trim().isNotEmpty;
    final hasProfile = lead.profileUrl.isNotEmpty;
    final hasBio = lead.bioSnippet != null && lead.bioSnippet!.trim().isNotEmpty;
    final hasLocation = lead.location != null && lead.location!.trim().isNotEmpty;
    final hasNiche = lead.niche != null && lead.niche!.trim().isNotEmpty;
    final hasDecisionMaker =
        lead.decisionMakerName != null && lead.decisionMakerName!.isNotEmpty;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Apple HIG Drag Handle
            const SizedBox(height: 12),
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
            const SizedBox(height: 12),

            // Top Header: Platform Tag + Extracted date + Share & Close Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  // Platform Chip
                  InkWell(
                    onTap: hasProfile ? () => _launchUrl(lead.profileUrl) : null,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                          if (hasProfile) ...[
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
                  const Spacer(),
                  // Share Button
                  IconButton(
                    icon: const Icon(Icons.share_outlined, size: 18),
                    color: AppColors.textSecondary,
                    tooltip: 'Share Lead',
                    splashRadius: 18,
                    onPressed: _shareLead,
                  ),
                  // Close Button
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: AppColors.textMuted,
                    tooltip: 'Close',
                    splashRadius: 18,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            const Divider(height: 16, color: AppColors.divider),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Business / Title Name (Selectable, Full text, no ellipsis)
                    SelectableText(
                      lead.displayName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.4,
                        height: 1.25,
                      ),
                    ),

                    if (lead.businessName != null &&
                        lead.name.isNotEmpty &&
                        lead.name != lead.businessName) ...[
                      const SizedBox(height: 4),
                      SelectableText(
                        'Contact: ${lead.name}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],

                    // Tags row (Location, Niche)
                    if (hasLocation || hasNiche) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (hasLocation)
                            _buildMetaBadge(
                              icon: Icons.location_on_outlined,
                              label: lead.location!,
                              color: AppColors.secondaryBlue,
                            ),
                          if (hasNiche)
                            _buildMetaBadge(
                              icon: Icons.label_outline_rounded,
                              label: lead.niche!,
                              color: AppColors.secondaryGreen,
                            ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 12),

                    // Full Bio Snippet / Description Section
                    if (hasBio) ...[
                      _buildSectionTitle('About / Description'),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryBackground,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.divider, width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SelectableText(
                              lead.bioSnippet!.trim(),
                              style: const TextStyle(
                                fontSize: 13.5,
                                color: AppColors.textPrimary,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: InkWell(
                                onTap: () => _copyToClipboard(
                                    lead.bioSnippet!.trim(), 'Description'),
                                borderRadius: BorderRadius.circular(6),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 3),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(
                                        Icons.copy_rounded,
                                        size: 12,
                                        color: AppColors.textMuted,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Copy text',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Contact Details Section
                    _buildSectionTitle('Contact Details'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.divider, width: 1),
                      ),
                      child: Column(
                        children: [
                          if (hasEmail)
                            _buildContactRow(
                              icon: Icons.mail_outline_rounded,
                              iconColor: AppColors.secondaryBlue,
                              title: 'Email',
                              value: lead.email!.trim(),
                              badge: _EmailVerifiedBadge(
                                email: lead.email!.trim(),
                                isWorkEmail: lead.isWorkEmail,
                                emailStatus: lead.emailStatus,
                              ),
                              onCopy: () => _copyToClipboard(
                                  lead.email!.trim(), 'Email'),
                              onAction: () => _sendEmail(lead.email!.trim()),
                              actionTooltip: 'Send email',
                              actionIcon: Icons.send_rounded,
                            ),
                          if (lead.alternativeEmails != null &&
                              lead.alternativeEmails!.isNotEmpty) ...[
                            for (final altEmail in lead.alternativeEmails!)
                              _buildContactRow(
                                icon: Icons.alternate_email_rounded,
                                iconColor: AppColors.secondaryBlue,
                                title: 'Alternative Email',
                                value: altEmail.trim(),
                                onCopy: () => _copyToClipboard(
                                    altEmail.trim(), 'Alternative Email'),
                                onAction: () => _sendEmail(altEmail.trim()),
                                actionTooltip: 'Send email',
                                actionIcon: Icons.send_rounded,
                              ),
                          ],
                          if (hasPhone) ...[
                            if (hasEmail) const Divider(height: 16, color: AppColors.divider),
                            _buildContactRow(
                              icon: Icons.phone_outlined,
                              iconColor: AppColors.secondaryGreen,
                              title: 'Phone',
                              value: lead.phone!.trim(),
                              onCopy: () => _copyToClipboard(
                                  lead.phone!.trim(), 'Phone'),
                              onAction: () => _callPhone(lead.phone!.trim()),
                              actionTooltip: 'Call',
                              actionIcon: Icons.call_rounded,
                            ),
                          ],
                          if (hasWebsite) ...[
                            if (hasEmail || hasPhone)
                              const Divider(height: 16, color: AppColors.divider),
                            _buildContactRow(
                              icon: Icons.language_rounded,
                              iconColor: AppColors.secondaryBlue,
                              title: 'Website',
                              value: lead.website!.trim(),
                              onCopy: () => _copyToClipboard(
                                  lead.website!.trim(), 'Website'),
                              onAction: () => _launchUrl(lead.website!.trim()),
                              actionTooltip: 'Open website',
                              actionIcon: Icons.open_in_new_rounded,
                            ),
                          ],
                          if (hasProfile) ...[
                            if (hasEmail || hasPhone || hasWebsite)
                              const Divider(height: 16, color: AppColors.divider),
                            _buildContactRow(
                              icon: Icons.account_circle_outlined,
                              iconColor: AppColors.textSecondary,
                              title: 'Profile URL',
                              value: lead.profileUrl.trim(),
                              onCopy: () => _copyToClipboard(
                                  lead.profileUrl.trim(), 'Profile URL'),
                              onAction: () => _launchUrl(lead.profileUrl.trim()),
                              actionTooltip: 'Open profile',
                              actionIcon: Icons.open_in_new_rounded,
                            ),
                          ],
                          if (!hasEmail && !hasPhone && !hasWebsite && !hasProfile)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'No direct contact details available',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Decision Maker / Founder Section
                    _buildSectionTitle('Decision Maker (Founder / CEO)'),
                    const SizedBox(height: 8),
                    if (hasDecisionMaker) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryBackground,
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: AppColors.divider, width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text('👑', style: TextStyle(fontSize: 16)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      SelectableText(
                                        lead.decisionMakerName!,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        lead.decisionMakerRole ?? 'Founder & CEO',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (lead.decisionMakerLinkedIn != null &&
                                    lead.decisionMakerLinkedIn!.isNotEmpty) ...[
                                  InkWell(
                                    onTap: () => _launchUrl(
                                        lead.decisionMakerLinkedIn!),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.secondaryBlueSubtle,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Text(
                                            'LinkedIn',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.secondaryBlue,
                                            ),
                                          ),
                                          SizedBox(width: 3),
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
                              const SizedBox(height: 10),
                              InkWell(
                                onTap: () => _copyToClipboard(
                                  lead.decisionMakerEmail!.trim(),
                                  'Founder Email',
                                ),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: AppColors.divider, width: 1),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.mail_outline_rounded,
                                        size: 14,
                                        color: AppColors.secondaryGreen,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          lead.decisionMakerEmail!.trim(),
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                            Icons.send_rounded,
                                            size: 14),
                                        color: AppColors.secondaryGreen,
                                        tooltip: 'Send Email',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                            minWidth: 24, minHeight: 24),
                                        onPressed: () => _sendEmail(
                                            lead.decisionMakerEmail!.trim()),
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
                          ],
                        ),
                      ),
                    ] else ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryBackground,
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: AppColors.divider, width: 1),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Discover the key Decision Maker (Founder, CEO, Managing Director) with verified direct contact details.',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 38,
                              child: ElevatedButton.icon(
                                onPressed: _isEnriching
                                    ? null
                                    : _enrichDecisionMaker,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryCta,
                                  foregroundColor: AppColors.onPrimaryCta,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                ),
                                icon: _isEnriching
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      )
                                    : const Text(
                                        '👑',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                label: Text(
                                  _isEnriching
                                      ? 'Searching Executive Database...'
                                      : 'Find Founder / CEO Profile',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Delete lead button (if onDelete callback provided)
                    if (widget.onDelete != null) ...[
                      Center(
                        child: TextButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            widget.onDelete?.call();
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                          ),
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 16),
                          label: const Text(
                            'Remove this lead',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildMetaBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildContactRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    Widget? badge,
    required VoidCallback onCopy,
    VoidCallback? onAction,
    String? actionTooltip,
    IconData? actionIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textMuted,
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 6),
                      badge,
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                SelectableText(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (onAction != null && actionIcon != null) ...[
            IconButton(
              icon: Icon(actionIcon, size: 16),
              color: iconColor,
              tooltip: actionTooltip,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              splashRadius: 16,
              onPressed: onAction,
            ),
          ],
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 15),
            color: AppColors.textMuted,
            tooltip: 'Copy',
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            splashRadius: 16,
            onPressed: onCopy,
          ),
        ],
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
            size: 10,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
