import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../models/lead_model.dart';
import '../services/app_review_service.dart';
import '../services/lead_discovery_service.dart';
import '../services/lead_storage_service.dart';
import '../theme/app_colors.dart';
import '../widgets/lead_card.dart';

/// Main Lead Generation Agent Screen.
/// Strictly follows Apple HIG + Linear + ChatGPT minimal design principles (mastui/design.md).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  /// Allows tests to disable infinite repeat animations so pumpAndSettle can settle cleanly.
  static bool enablePulseAnimation = true;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final _nicheController = TextEditingController();
  final _locationController = TextEditingController();

  late final AnimationController _searchBarController;
  late final Animation<double> _searchBarAnimation;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  final ScrollController _scrollController = ScrollController();
  bool _isSearchBarVisible = true;

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
  String _searchedNiche = '';
  StreamSubscription<Lead>? _searchSubscription;

  @override
  void initState() {
    super.initState();
    _searchBarController = AnimationController(
      vsync: this,
      duration: AppMotion.duration,
      value: 1.0,
    );
    _searchBarAnimation = CurvedAnimation(
      parent: _searchBarController,
      curve: AppMotion.curve,
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );

    _scrollController.addListener(_onScroll);
    _loadSavedLeads();
  }

  void _startPulseAnimation() {
    if (HomeScreen.enablePulseAnimation && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    }
  }

  void _stopPulseAnimation() {
    if (_pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  void _onScroll() {
    if (_scrollController.hasClients && _scrollController.offset <= 10) {
      if (!_isSearchBarVisible) {
        setState(() {
          _isSearchBarVisible = true;
        });
        _searchBarController.forward();
      }
    }
  }

  @override
  void dispose() {
    _searchSubscription?.cancel();
    _nicheController.dispose();
    _locationController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchBarController.dispose();
    _stopPulseAnimation();
    _pulseController.dispose();
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
        _searchedNiche = saved.first.niche ?? '';
      });
    }
  }

  Future<void> _startDiscovery({bool isLoadMore = false}) async {
    var niche = _nicheController.text.trim();
    final location = _locationController.text.trim();

    if (niche.isEmpty &&
        isLoadMore &&
        _leads.isNotEmpty &&
        _leads.first.niche != null) {
      niche = _leads.first.niche!;
      _nicheController.text = niche;
    }

    if (niche.isEmpty) {
      _showToast('Please enter a target niche or business.');
      return;
    }

    FocusScope.of(context).unfocus();
    await _searchSubscription?.cancel();

    if (!isLoadMore) {
      _currentPage = 1;
      _searchedNiche = niche;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      await LeadStorageService.instance.clearLeads();
    } else {
      _currentPage++;
    }

    if (!_isSearchBarVisible) {
      _isSearchBarVisible = true;
      _searchBarController.forward();
    }

    setState(() {
      if (!isLoadMore) {
        _leads.clear();
        _startPulseAnimation();
      }
      _isSearching = true;
      _isLoadingMore = isLoadMore;
      _searchStatus = isLoadMore
          ? 'Fetching page $_currentPage leads...'
          : 'Searching verified leads for $niche...';
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
      page: _currentPage,
    );

    var count = 0;
    _searchSubscription = LeadDiscoveryService.instance
        .discoverLeadsStream(config)
        .listen(
          (lead) {
            if (!mounted) return;
            setState(() {
              final exists = _leads.any(
                (l) =>
                    (l.email != null && l.email == lead.email) ||
                    (l.phone != null && l.phone == lead.phone) ||
                    l.profileUrl == lead.profileUrl,
              );

              if (!exists) {
                _leads.add(lead);
                if (_leads.isNotEmpty) {
                  _stopPulseAnimation();
                }
                count++;
                _searchStatus = isLoadMore
                    ? 'Added $count more leads (${lead.platform})...'
                    : 'Found $count leads from ${lead.platform}...';
              }
            });
          },
          onError: (err) {
            if (!mounted) return;
            _stopPulseAnimation();
            setState(() {
              _isSearching = false;
              _isLoadingMore = false;
              _searchStatus = 'Search completed with partial results.';
            });
            _persistCurrentLeads();
          },
          onDone: () {
            if (!mounted) return;
            _stopPulseAnimation();
            setState(() {
              _isSearching = false;
              _isLoadingMore = false;
              _searchStatus = count > 0
                  ? (isLoadMore
                        ? 'Loaded $count additional leads.'
                        : 'Found $count leads for $niche.')
                  : (isLoadMore
                        ? 'No more leads found.'
                        : 'No leads found for "$niche".');
            });
            _persistCurrentLeads();
          },
        );
  }

  void _stopDiscovery() {
    _searchSubscription?.cancel();
    _stopPulseAnimation();
    setState(() {
      _isSearching = false;
      _isLoadingMore = false;
      _searchStatus = _leads.isNotEmpty
          ? 'Discovery paused (${_leads.length} leads).'
          : 'Discovery paused.';
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
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.dialog),
        ),
        title: const Text(
          'Clear all leads?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
        content: const Text(
          'This will remove all currently discovered leads from your device.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            child: const Text('Cancel', style: TextStyle(fontSize: 14)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.button),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
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
            child: const Text('Clear', style: TextStyle(fontWeight: FontWeight.w600)),
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
      _showToast('CSV downloaded (${_leads.length} leads)');
    } else {
      _showToast('Export failed. Please try again.');
    }
  }

  Future<void> _exportPdf() async {
    if (_leads.isEmpty) {
      _showToast('No leads to export.');
      return;
    }

    final niche = _nicheController.text.trim();
    final success = await LeadStorageService.instance.exportAndDownloadPdf(
      _leads,
      niche: niche.isNotEmpty ? niche : 'leads',
    );

    if (success) {
      _showToast('PDF exported (${_leads.length} leads)');
    } else {
      _showToast('PDF export failed. Please try again.');
    }
  }

  void _openExportBottomSheet() {
    if (_leads.isEmpty) {
      _showToast('No leads to export.');
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.bottomSheet),
        ),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.88,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Export Leads',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.secondaryBackground,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Text(
                            '${_leads.length} leads',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildExportOptionTile(
                      icon: Icons.table_chart_rounded,
                      title: 'Export as CSV',
                      subtitle: 'Open in Excel, Google Sheets, or CRM software',
                      badge: '.csv',
                      onTap: () {
                        Navigator.pop(ctx);
                        _exportCsv();
                      },
                    ),
                    const SizedBox(height: 10),
                    _buildExportOptionTile(
                      icon: Icons.picture_as_pdf_rounded,
                      title: 'Export as PDF',
                      subtitle: 'Formatted document report ready to print & share',
                      badge: '.pdf',
                      onTap: () {
                        Navigator.pop(ctx);
                        _exportPdf();
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildExportOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String badge,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.secondaryBackground,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.divider),
              ),
              child: Icon(icon, size: 20, color: AppColors.secondaryBlue),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.divider),
              ),
              child: Text(
                badge,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyAllEmails() async {
    if (_leads.isEmpty) {
      _showToast('No leads available.');
      return;
    }

    final count = await LeadStorageService.instance.copyAllEmailsToClipboard(
      _leads,
    );
    if (count > 0) {
      _showToast('$count emails copied');
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
          style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500),
        ),
        backgroundColor: AppColors.textPrimary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.input)),
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
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.88,
                ),
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 12,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
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
                                child: const Text(
                                  'Reset',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                ),
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
                              hintText: 'City or Region (e.g. Mumbai, New York)',
                              prefixIcon: const Icon(
                                Icons.location_on_outlined,
                                size: 20,
                                color: AppColors.textMuted,
                              ),
                              suffixIcon: _locationController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        size: 18,
                                      ),
                                      color: AppColors.textMuted,
                                      onPressed: () {
                                        setModalState(
                                          () => _locationController.clear(),
                                        );
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
                          physics: const BouncingScrollPhysics(),
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
                                      setModalState(
                                        () => _selectedPlatform = platform,
                                      );
                                      setState(
                                        () => _selectedPlatform = platform,
                                      );
                                    }
                                  },
                                  labelStyle: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? Colors.white
                                        : AppColors.textSecondary,
                                  ),
                                  selectedColor: AppColors.textPrimary,
                                  backgroundColor: AppColors.secondaryBackground,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  side: BorderSide.none,
                                  showCheckmark: false,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
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
                              backgroundColor: AppColors.primaryCta,
                              foregroundColor: AppColors.onPrimaryCta,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.button,
                                ),
                              ),
                            ),
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text(
                              'Apply Filters',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.onPrimaryCta,
                              ),
                            ),
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
          Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              IconButton(
                tooltip: 'Filters',
                splashRadius: 22,
                icon: Icon(
                  Icons.tune_rounded,
                  size: 22,
                  color: activeFilters > 0
                      ? AppColors.secondaryGreen
                      : AppColors.textPrimary,
                ),
                onPressed: _openFilterBottomSheet,
              ),
              if (activeFilters > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppColors.secondaryGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
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
              } else if (value == 'rate_us') {
                AppReviewService.instance.openStoreListing();
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
                    Icon(
                      Icons.mail_outline_rounded,
                      size: 18,
                      color: AppColors.textPrimary,
                    ),
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
                value: 'rate_us',
                child: const Row(
                  children: [
                    Icon(
                      Icons.star_outline_rounded,
                      size: 18,
                      color: AppColors.secondaryGreen,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Rate Us',
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
                    Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: AppColors.danger,
                    ),
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
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Collapsible Top Search Bar & Status Container on Scroll
            SizeTransition(
              sizeFactor: _searchBarAnimation,
              axisAlignment: -1.0,
              child: FadeTransition(
                opacity: _searchBarAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20.0,
                        vertical: 8.0,
                      ),
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
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                    ),
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

                    if (_isSearching || _leads.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (_isSearching)
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.secondaryGreen,
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.card,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppColors.divider,
                                    width: 1,
                                  ),
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
                  ],
                ),
              ),
            ),

            // Lead Results List, Searching State, or Empty State
            Expanded(
              child: _leads.isEmpty
                  ? (_isSearching
                        ? _buildSearchingState(
                            _nicheController.text.trim().isNotEmpty
                                ? _nicheController.text.trim()
                                : _searchedNiche,
                          )
                        : _buildEmptyState())
                  : NotificationListener<UserScrollNotification>(
                      onNotification: (notification) {
                        if (notification.direction == ScrollDirection.reverse) {
                          if (_isSearchBarVisible) {
                            setState(() {
                              _isSearchBarVisible = false;
                            });
                            _searchBarController.reverse();
                          }
                        } else if (notification.direction ==
                            ScrollDirection.forward) {
                          if (!_isSearchBarVisible) {
                            setState(() {
                              _isSearchBarVisible = true;
                            });
                            _searchBarController.forward();
                          }
                        }
                        return false;
                      },
                      child: ListView.builder(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
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
            ),

            // Pinned Bottom Actions Bar (Apple HIG Luxury Glass/Surface Bar)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: SizedBox(
                      height: 52,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: _isSearching
                              ? AppColors.danger
                              : AppColors.primaryCta,
                          foregroundColor: AppColors.onPrimaryCta,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppRadius.button,
                            ),
                          ),
                        ),
                        onPressed: _isSearching
                            ? _stopDiscovery
                            : _startDiscovery,
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
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AppColors.surface,
                          side: const BorderSide(color: AppColors.divider),
                          padding: EdgeInsets.zero,
                          alignment: Alignment.center,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppRadius.button,
                            ),
                          ),
                        ),
                        onPressed: _openExportBottomSheet,
                        child: const Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.download_rounded,
                                size: 18,
                                color: AppColors.secondaryBlue,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Export',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
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

  Widget _buildSearchingState(String niche) {
    final queryText = niche.isNotEmpty ? niche : 'leads';
    return ListView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.secondaryBackground,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.divider, width: 1),
          ),
          child: Row(
            children: [
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.secondaryGreen.withValues(
                        alpha: 0.12 + (_pulseAnimation.value * 0.12),
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: AppColors.secondaryGreen,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.secondaryGreen.withValues(
                                alpha: 0.3 + (_pulseAnimation.value * 0.3),
                              ),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Searching leads for "$queryText"...',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Scanning Instagram, LinkedIn, Facebook, X',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.secondaryGreen,
                ),
              ),
            ],
          ),
        ),
        _buildSkeletonCard(),
        const SizedBox(height: 12),
        _buildSkeletonCard(),
        const SizedBox(height: 12),
        _buildSkeletonCard(),
      ],
    );
  }

  Widget _buildSkeletonCard() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final opacity = 0.45 + (_pulseAnimation.value * 0.45);
        return Opacity(
          opacity: opacity,
          child: Container(
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 80,
                      height: 22,
                      decoration: BoxDecoration(
                        color: AppColors.secondaryBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: AppColors.secondaryBackground,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: 180,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.secondaryBackground,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 240,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.secondaryBackground,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 86,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.secondaryBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 86,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.secondaryBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 86,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.secondaryBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    final hasSearched = _searchedNiche.isNotEmpty;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: [
          if (hasSearched) ...[
            Text(
              'No Leads Found for "$_searchedNiche"',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try broader keywords, adjust platform filters, or select a suggestion below.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ] else ...[
            const Text(
              'Enter any niche to extract verified emails & phone numbers in 1 click.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 20),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                color: AppColors.secondaryGreen,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Fetching next leads (Page $_currentPage)...',
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
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_circle_outline_rounded,
              size: 18,
              color: AppColors.secondaryGreen,
            ),
            SizedBox(width: 8),
            Text(
              'Load More Leads',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
