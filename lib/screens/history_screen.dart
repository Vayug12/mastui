import 'package:flutter/material.dart';

import '../models/search_history_session.dart';
import '../services/search_history_service.dart';
import '../theme/app_colors.dart';
import 'history_detail_screen.dart';

/// Screen listing all past search sessions with lead counts, timestamps, and quick restore/export.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<SearchHistorySession> _sessions = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchFilterController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _searchFilterController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final list = await SearchHistoryService.instance.loadHistory();
    if (mounted) {
      setState(() {
        _sessions = list;
        _isLoading = false;
      });
    }
  }

  List<SearchHistorySession> get _filteredSessions {
    if (_searchQuery.trim().isEmpty) return _sessions;
    final q = _searchQuery.trim().toLowerCase();
    return _sessions.where((s) {
      final niche = s.niche.toLowerCase();
      final loc = (s.location ?? '').toLowerCase();
      return niche.contains(q) || loc.contains(q);
    }).toList();
  }

  String _formatRelativeTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Future<void> _deleteSession(SearchHistorySession session) async {
    await SearchHistoryService.instance.deleteSession(session.id);
    if (mounted) {
      setState(() {
        _sessions.removeWhere((s) => s.id == session.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed "${session.niche}" from history'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _confirmClearAll() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.dialog),
        ),
        title: const Text(
          'Clear all history?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        content: const Text(
          'This will permanently delete all saved search sessions and leads.',
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
              await SearchHistoryService.instance.clearHistory();
              if (mounted) {
                setState(() {
                  _sessions.clear();
                });
              }
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  Future<void> _openSession(SearchHistorySession session) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => HistoryDetailScreen(session: session),
      ),
    );

    if (result is SearchHistorySession) {
      // Restore this session to HomeScreen
      if (mounted) {
        Navigator.of(context).pop(result);
      }
    } else {
      // Reload history to reflect any lead updates or deletion
      _loadHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredSessions;

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
        title: const Text(
          'Search History',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          if (_sessions.isNotEmpty)
            IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 20,
                color: AppColors.textSecondary,
              ),
              tooltip: 'Clear All History',
              onPressed: _confirmClearAll,
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
        child: _isLoading
            ? const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
              )
            : _sessions.isEmpty
                ? _buildEmptyState()
                : Column(
                    children: [
                      // Filter input when history has multiple sessions
                      if (_sessions.length > 3)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.inputBackground,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.input),
                            ),
                            child: TextField(
                              controller: _searchFilterController,
                              onChanged: (val) {
                                setState(() {
                                  _searchQuery = val;
                                });
                              },
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Search history...',
                                hintStyle: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textHint,
                                ),
                                prefixIcon: const Icon(
                                  Icons.search_rounded,
                                  size: 18,
                                  color: AppColors.textMuted,
                                ),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(
                                          Icons.close_rounded,
                                          size: 16,
                                          color: AppColors.textMuted,
                                        ),
                                        onPressed: () {
                                          _searchFilterController.clear();
                                          setState(() {
                                            _searchQuery = '';
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

                      Expanded(
                        child: filtered.isEmpty
                            ? Center(
                                child: Text(
                                  'No results match "$_searchQuery"',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final session = filtered[index];
                                  return _buildSessionCard(session);
                                },
                              ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildSessionCard(SearchHistorySession session) {
    return Dismissible(
      key: ValueKey(session.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
      onDismissed: (_) => _deleteSession(session),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: () => _openSession(session),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.border),
              boxShadow: AppShadows.softCard,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Niche and Lead Count Badge
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              session.niche,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
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
                              '${session.leadCount} leads',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.secondaryGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Location (if present) + Timestamp
                      Row(
                        children: [
                          if (session.location != null &&
                              session.location!.trim().isNotEmpty) ...[
                            const Icon(
                              Icons.location_on_outlined,
                              size: 13,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                session.location!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              width: 3,
                              height: 3,
                              decoration: const BoxDecoration(
                                color: AppColors.divider,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            _formatRelativeTime(session.updatedAt),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.secondaryBackground,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.history_rounded,
                size: 32,
                color: AppColors.textDisabled,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No Search History',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your discovered leads from searches will appear here automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryCta,
                  foregroundColor: AppColors.onPrimaryCta,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Start Searching',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
