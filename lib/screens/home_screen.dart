import 'dart:async';
import 'package:flutter/material.dart';

import '../models/lead_model.dart';
import '../services/lead_discovery_service.dart';
import '../services/lead_storage_service.dart';
import '../theme/app_colors.dart';
import '../widgets/lead_card.dart';

/// Main Lead Generation Agent Screen.
/// Strictly follows mastui/design.md (Linear + Apple HIG + ChatGPT aesthetics).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _nicheController = TextEditingController();
  final _locationController = TextEditingController();

  final List<String> _availablePlatforms = [
    'All',
    'Instagram',
    'LinkedIn',
    'Facebook',
    'X',
  ];
  String _selectedPlatform = 'All';

  final List<Lead> _leads = [];
  bool _isSearching = false;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  String _searchStatus = '';
  StreamSubscription<Lead>? _searchSubscription;

  @override
  void initState() {
    super.initState();
    _loadSavedLeads();
  }

  @override
  void dispose() {
    _searchSubscription?.cancel();
    _nicheController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  int get _activeFilterCount {
    var count = 0;
    if (_locationController.text.trim().isNotEmpty) count++;
    if (_selectedPlatform != 'All') count++;
    return count;
  }

  Future<void> _loadSavedLeads() async {
    final saved = await LeadStorageService.instance.loadLeads();
    if (mounted && saved.isNotEmpty) {
      setState(() {
        _leads.clear();
        _leads.addAll(saved);
      });
    }
  }

  Future<void> _startDiscovery({bool isLoadMore = false}) async {
    var niche = _nicheController.text.trim();
    final location = _locationController.text.trim();

    // Auto-detect niche from active leads if input is empty when loading more
    if (niche.isEmpty && isLoadMore && _leads.isNotEmpty && _leads.first.niche != null) {
      niche = _leads.first.niche!;
      _nicheController.text = niche;
    }

    if (niche.isEmpty) {
      _showToast('Please enter a target niche or business type.');
      return;
    }

    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    await _searchSubscription?.cancel();

    if (!isLoadMore) {
      _currentPage = 1;
    } else {
      _currentPage++;
    }

    setState(() {
      _isSearching = true;
      _isLoadingMore = isLoadMore;
      _searchStatus = isLoadMore
          ? 'Fetching page $_currentPage leads for $niche...'
          : 'Connecting to multi-engine discovery pipeline...';
    });

    final platforms = _selectedPlatform == 'All'
        ? ['Instagram', 'LinkedIn', 'Facebook', 'X']
        : [_selectedPlatform];

    final config = LeadDiscoveryConfig(
      niche: niche,
      location: location,
      platforms: platforms,
      extractEmails: true,
      extractPhones: true,
      maxResults: 50,
      page: _currentPage,
    );

    var count = 0;
    _searchSubscription = LeadDiscoveryService.instance
        .discoverLeadsStream(config)
        .listen(
      (lead) {
        if (!mounted) return;
        setState(() {
          // Avoid duplicate leads in active list
          final exists = _leads.any((l) =>
              (l.email != null && l.email == lead.email) ||
              (l.phone != null && l.phone == lead.phone) ||
              l.profileUrl == lead.profileUrl);

          if (!exists) {
            if (isLoadMore) {
              _leads.add(lead); // Append cleanly to bottom for pagination
            } else {
              _leads.insert(0, lead);
            }
            count++;
            _searchStatus = isLoadMore
                ? 'Added $count more leads from ${lead.platform}...'
                : 'Discovered $count leads from ${lead.platform}...';
          }
        });
      },
      onError: (err) {
        if (!mounted) return;
        setState(() {
          _isSearching = false;
          _isLoadingMore = false;
          _searchStatus = 'Search completed with partial results.';
        });
        _persistCurrentLeads();
      },
      onDone: () {
        if (!mounted) return;
        setState(() {
          _isSearching = false;
          _isLoadingMore = false;
          _searchStatus = count > 0
              ? (isLoadMore
                  ? 'Loaded $count additional leads (Page $_currentPage).'
                  : 'Discovery finished. Found $count new leads.')
              : (isLoadMore
                  ? 'No more leads found. Try modifying filters.'
                  : 'No leads found for this query. Try broader keywords.');
        });
        _persistCurrentLeads();
      },
    );
  }

  void _stopDiscovery() {
    _searchSubscription?.cancel();
    setState(() {
      _isSearching = false;
      _isLoadingMore = false;
      _searchStatus = 'Discovery paused.';
    });
    _persistCurrentLeads();
  }

  Future<void> _persistCurrentLeads() async {
    await LeadStorageService.instance.saveLeads(_leads);
  }

  void _clearAllLeads() {
    if (_leads.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.dialog),
        ),
        title: const Text(
          'Clear all leads?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        content: const Text(
          'This will remove all currently discovered leads from your device.',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await LeadStorageService.instance.clearLeads();
              setState(() {
                _leads.clear();
                _currentPage = 1;
                _isLoadingMore = false;
                _searchStatus = '';
              });
              _showToast('All leads cleared');
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportCsv() async {
    if (_leads.isEmpty) {
      _showToast('No leads to export.');
      return;
    }

    final niche = _nicheController.text.trim();
    final success = await LeadStorageService.instance.exportAndDownloadCsv(
      _leads,
      niche: niche.isNotEmpty ? niche : 'leads',
    );

    if (success) {
      _showToast('CSV downloaded / shared (${_leads.length} leads)');
    } else {
      _showToast('Export failed. Please try again.');
    }
  }

  Future<void> _copyAllEmails() async {
    if (_leads.isEmpty) {
      _showToast('No leads available.');
      return;
    }

    final count =
        await LeadStorageService.instance.copyAllEmailsToClipboard(_leads);
    if (count > 0) {
      _showToast('$count email addresses copied to clipboard');
    } else {
      _showToast('No emails found in current leads');
    }
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 13, color: Colors.white),
        ),
        backgroundColor: AppColors.textPrimary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _applyQuickSuggestion(String niche, [String location = '']) {
    _nicheController.text = niche;
    _locationController.text = location;
    _startDiscovery();
  }

  void _openFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.bottomSheet),
        ),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              top: false,
              bottom: true,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 12,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Subtle Apple HIG Drag Handle
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
                      const SizedBox(height: 16),

                      // Header Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Filters',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          if (_activeFilterCount > 0)
                            TextButton(
                              onPressed: () {
                                setModalState(() {
                                  _locationController.clear();
                                  _selectedPlatform = 'All';
                                });
                                setState(() {});
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.textSecondary,
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(50, 30),
                              ),
                              child: const Text('Reset', style: TextStyle(fontSize: 14)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Location Field (Optional)
                      const Text(
                        'Location',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 52,
                        child: TextField(
                          controller: _locationController,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: 'City or Region (Optional - e.g. Mumbai, NY)',
                            prefixIcon: const Icon(
                              Icons.location_on_outlined,
                              size: 20,
                              color: AppColors.textMuted,
                            ),
                            suffixIcon: _locationController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.close_rounded, size: 18),
                                    color: AppColors.textMuted,
                                    onPressed: () {
                                      setModalState(() => _locationController.clear());
                                      setState(() {});
                                    },
                                  )
                                : null,
                          ),
                          onChanged: (_) {
                            setModalState(() {});
                            setState(() {});
                          },
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Platform Filter Chips
                      const Text(
                        'Platform',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _availablePlatforms.map((platform) {
                            final isSelected = _selectedPlatform == platform;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ChoiceChip(
                                label: Text(platform),
                                selected: isSelected,
                                onSelected: (selected) {
                                  if (selected) {
                                    setModalState(() => _selectedPlatform = platform);
                                    setState(() => _selectedPlatform = platform);
                                  }
                                },
                                labelStyle: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                  color: isSelected ? Colors.white : AppColors.textSecondary,
                                ),
                                selectedColor: AppColors.textPrimary,
                                backgroundColor: AppColors.secondaryBackground,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                side: BorderSide.none,
                                showCheckmark: false,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Apply CTA Button
                      SizedBox(
                        height: 52,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.button),
                            ),
                          ),
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text(
                            'Apply Filters',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeFilters = _activeFilterCount;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'GetLead Agent',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.4,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert_rounded,
              size: 22,
              color: AppColors.textPrimary,
            ),
            color: AppColors.surface,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              side: const BorderSide(color: AppColors.divider),
            ),
            onSelected: (value) {
              if (value == 'copy_emails') {
                _copyAllEmails();
              } else if (value == 'export_csv') {
                _exportCsv();
              } else if (value == 'clear_leads') {
                _clearAllLeads();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'copy_emails',
                enabled: _leads.isNotEmpty,
                child: const Row(
                  children: [
                    Icon(Icons.mail_outline_rounded, size: 18, color: AppColors.textPrimary),
                    SizedBox(width: 12),
                    Text(
                      'Copy Emails',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'export_csv',
                enabled: _leads.isNotEmpty,
                child: const Row(
                  children: [
                    Icon(Icons.download_rounded, size: 18, color: AppColors.textPrimary),
                    SizedBox(width: 12),
                    Text(
                      'Export CSV',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'clear_leads',
                enabled: _leads.isNotEmpty,
                child: const Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
                    SizedBox(width: 12),
                    Text(
                      'Clear Leads',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Clean Search Bar (Only Niche here, keeping screen uncluttered)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              child: SizedBox(
                height: 52,
                child: TextField(
                  controller: _nicheController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _startDiscovery(),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search niche (e.g. Real Estate, Gym, Cafe)',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: AppColors.textMuted,
                    ),
                    suffixIcon: _nicheController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            color: AppColors.textMuted,
                            onPressed: () {
                              _nicheController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ),

            // Search Status & Tight Lead Count Pill at Corner
            if (_isSearching || _leads.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_isSearching)
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _searchStatus,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    if (_leads.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.divider, width: 1),
                          boxShadow: AppShadows.softCard,
                        ),
                        child: Text(
                          '${_leads.length} leads',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            // Lead Results List or Empty State
            Expanded(
              child: _leads.isEmpty && !_isSearching
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      itemCount: _leads.length + (_leads.isNotEmpty ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _leads.length) {
                          return _buildLoadMoreSection();
                        }
                        final lead = _leads[index];
                        return LeadCard(
                          lead: lead,
                          onDelete: () {
                            setState(() {
                              _leads.removeAt(index);
                            });
                            _persistCurrentLeads();
                          },
                        );
                      },
                    ),
            ),

            // Pinned Bottom Actions Bar: Filter button adjacent to Generate Leads button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: Row(
                children: [
                  // Adjacent Filter Button
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      SizedBox(
                        height: 52,
                        width: 52,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: activeFilters > 0
                                ? AppColors.secondaryBackground
                                : AppColors.surface,
                            side: const BorderSide(color: AppColors.divider),
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.button),
                            ),
                          ),
                          onPressed: _openFilterBottomSheet,
                          child: const Icon(
                            Icons.tune_rounded,
                            size: 20,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (activeFilters > 0)
                        Positioned(
                          top: -3,
                          right: -3,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$activeFilters',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 10),

                  // Main Generate Leads Button (52px height, 14px radius, #10A37F)
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: _isSearching ? AppColors.danger : AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.button),
                          ),
                        ),
                        onPressed: _isSearching ? _stopDiscovery : _startDiscovery,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isSearching) ...[
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Stop Searching',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ] else ...[
                              const Icon(Icons.bolt_rounded, size: 20, color: Colors.white),
                              const SizedBox(width: 8),
                              const Text(
                                'Generate Leads',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppColors.secondaryBackground,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.people_outline_rounded,
              size: 30,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Discover Business Leads',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter any niche to extract verified emails & phone numbers in 1 click.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Quick Suggestions:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildSuggestionChip('Real Estate'),
              _buildSuggestionChip('Interior Designers'),
              _buildSuggestionChip('Fitness Coaches'),
              _buildSuggestionChip('Digital Marketing'),
              _buildSuggestionChip('Cafes & Restaurants'),
              _buildSuggestionChip('Dentists'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String niche, [String location = '']) {
    return ActionChip(
      backgroundColor: AppColors.secondaryBackground,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      label: Text(
        niche,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
      onPressed: () => _applyQuickSuggestion(niche, location),
    );
  }

  Widget _buildLoadMoreSection() {
    if (_isLoadingMore) {
      return Container(
        margin: const EdgeInsets.only(top: 8, bottom: 20),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.secondaryBackground,
          borderRadius: BorderRadius.circular(AppRadius.button),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Fetching next 50 leads (Page $_currentPage)...',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (_isSearching) {
      return const SizedBox(height: 16);
    }

    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 20),
      height: 48,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surface,
          side: const BorderSide(color: AppColors.divider, width: 1.2),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
        onPressed: () => _startDiscovery(isLoadMore: true),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.add_circle_outline_rounded,
              size: 18,
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            const Text(
              'Load More Leads',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.secondaryBackground,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                '+50',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

