import 'package:flutter/material.dart';

import '../models/lead_model.dart';
import '../models/search_history_session.dart';
import '../services/lead_storage_service.dart';
import '../services/search_history_service.dart';
import '../theme/app_colors.dart';
import '../widgets/lead_card.dart';

/// Screen displaying the full leads list of a saved search session.
/// Allows restoring leads to active search, exporting to CSV/PDF, and inspecting leads.
class HistoryDetailScreen extends StatefulWidget {
  final SearchHistorySession session;

  const HistoryDetailScreen({
    super.key,
    required this.session,
  });

  @override
  State<HistoryDetailScreen> createState() => _HistoryDetailScreenState();
}

class _HistoryDetailScreenState extends State<HistoryDetailScreen> {
  late SearchHistorySession _session;
  late List<Lead> _leads;
  String _filterQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _leads = List.from(widget.session.leads);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Lead> get _filteredLeads {
    if (_filterQuery.trim().isEmpty) return _leads;
    final q = _filterQuery.trim().toLowerCase();
    return _leads.where((l) {
      final name = l.displayName.toLowerCase();
      final email = (l.email ?? '').toLowerCase();
      final phone = (l.phone ?? '').toLowerCase();
      final role = (l.decisionMakerRole ?? '').toLowerCase();
      return name.contains(q) ||
          email.contains(q) ||
          phone.contains(q) ||
          role.contains(q);
    }).toList();
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  void _restoreToSearch() {
    // Pop back to HistoryScreen, passing this session with instructions to restore in HomeScreen
    Navigator.of(context).pop(_session.copyWith(leads: _leads));
  }

  Future<void> _exportCsv() async {
    if (_leads.isEmpty) return;
    final success = await LeadStorageService.instance.exportAndDownloadCsv(
      _leads,
      niche: _session.niche,
    );
    if (mounted && !success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('CSV copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _exportPdf() async {
    if (_leads.isEmpty) return;
    final success = await LeadStorageService.instance.exportAndDownloadPdf(
      _leads,
      niche: _session.niche,
    );
    if (mounted && !success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to generate PDF report'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _confirmDeleteSession() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.dialog),
        ),
        title: const Text(
          'Delete this session?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        content: const Text(
          'This will permanently remove this search session from your history.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.button),
              ),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await SearchHistoryService.instance.deleteSession(_session.id);
              if (mounted) {
                Navigator.of(context).pop('deleted');
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateLead(Lead updated) async {
    final idx = _leads.indexWhere((l) => l.id == updated.id);
    if (idx != -1) {
      setState(() {
        _leads[idx] = updated;
      });
      _session = _session.copyWith(leads: _leads);
      await _persistSessionChanges();
    }
  }

  Future<void> _removeLead(Lead lead) async {
    setState(() {
      _leads.removeWhere((l) => l.id == lead.id);
    });
    _session = _session.copyWith(leads: _leads);
    await _persistSessionChanges();
  }

  Future<void> _persistSessionChanges() async {
    final allSessions = await SearchHistoryService.instance.loadHistory();
    final idx = allSessions.indexWhere((s) => s.id == _session.id);
    if (idx != -1) {
      allSessions[idx] = _session;
      await SearchHistoryService.instance.saveHistory(allSessions);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredLeads;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _session.niche,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              size: 20,
              color: AppColors.textSecondary,
            ),
            tooltip: 'Delete session',
            onPressed: _confirmDeleteSession,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: AppColors.divider,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Metadata & Primary Action Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: const BoxDecoration(
                color: AppColors.background,
                border: Border(
                  bottom: BorderSide(color: AppColors.divider),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Lead count badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryGreenSubtle,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${_leads.length} leads',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondaryGreen,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Location badge if available
                      if (_session.location != null &&
                          _session.location!.trim().isNotEmpty) ...[
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.secondaryBackground,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.divider),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 12,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    _session.location!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      const Spacer(),
                      // Timestamp
                      Text(
                        _formatDate(_session.updatedAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Action Buttons Row: Restore to Search (Primary CTA) & Export buttons
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primaryCta,
                              foregroundColor: AppColors.onPrimaryCta,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.button),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                            ),
                            onPressed: _leads.isNotEmpty ? _restoreToSearch : null,
                            icon: const Icon(
                              Icons.restore_rounded,
                              size: 18,
                            ),
                            label: const Text(
                              'Restore to Search',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // CSV export button
                      SizedBox(
                        height: 44,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            minimumSize: const Size(0, 44),
                            side: const BorderSide(color: AppColors.divider),
                            backgroundColor: AppColors.secondaryBackground,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.button),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          onPressed: _leads.isNotEmpty ? _exportCsv : null,
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.file_download_outlined,
                                size: 16,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'CSV',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // PDF export button
                      SizedBox(
                        height: 44,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            minimumSize: const Size(0, 44),
                            side: const BorderSide(color: AppColors.divider),
                            backgroundColor: AppColors.secondaryBackground,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.button),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          onPressed: _leads.isNotEmpty ? _exportPdf : null,
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.picture_as_pdf_outlined,
                                size: 16,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'PDF',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // In-session search/filter if leads count > 4
            if (_leads.length > 4)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.inputBackground,
                    borderRadius: BorderRadius.circular(AppRadius.input),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {
                        _filterQuery = val;
                      });
                    },
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Filter leads...',
                      hintStyle: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textHint,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: AppColors.textMuted,
                      ),
                      suffixIcon: _filterQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: AppColors.textMuted,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _filterQuery = '';
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 12,
                      ),
                    ),
                  ),
                ),
              ),

            // Leads list
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 40,
                            color: AppColors.textDisabled,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _leads.isEmpty
                                ? 'No leads in this session'
                                : 'No leads match "$_filterQuery"',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final lead = filtered[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: LeadCard(
                            lead: lead,
                            onDelete: () => _removeLead(lead),
                            onLeadUpdated: (updated) => _updateLead(updated),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
