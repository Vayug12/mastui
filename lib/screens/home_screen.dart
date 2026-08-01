import 'package:flutter/material.dart';

import '../data/design_repository.dart';
import '../models/ui_design.dart';
import '../services/analytics_service.dart';
import '../services/design_downloader.dart';
import '../theme/app_colors.dart';
import '../widgets/ad_banner.dart';
import '../widgets/design_preview.dart';
import 'customer_center_screen.dart';
import 'detail_screen.dart';
import 'generate_prompt_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _repository = DesignRepository();
  late Future<List<UiDesign>> _designs;

  String _query = '';
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  bool _showSearch = false;

  String _selectedCategory = 'All';
  String _selectedPlatform = 'All';

  static const _pageSize = 20;
  int _visibleCount = _pageSize;
  bool _isLoadingMore = false;
  final _scrollController = ScrollController();

  String _lastTrackedSearch = '';
  DateTime? _lastSearchTime;

  @override
  void initState() {
    super.initState();
    _designs = _repository.load();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _onRefresh() async {
    _repository.refresh();
    setState(() {
      _designs = _repository.load();
      _visibleCount = _pageSize;
    });
    await _designs;
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;
    final snapshot = await _designs;
    final allItems = DesignRepository.itemsOf(snapshot);
    final items = _visibleItems(allItems);
    if (_visibleCount >= items.length) return;
    setState(() {
      _isLoadingMore = true;
    });
    // Simulate a short delay for smooth UX
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() {
      _visibleCount += _pageSize;
      _isLoadingMore = false;
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _openSearch() {
    setState(() => _showSearch = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  // Free users get a few generations a day, so the screen opens for everyone;
  // the paywall appears only once someone actually runs out.
  void _openPromptGenerator() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const GeneratePromptScreen()),
    );
  }

  void _trackSearchDebounced(String query) {
    final now = DateTime.now();
    final trimmed = query.trim().toLowerCase();
    if (trimmed.length < 2) return;
    if (trimmed == _lastTrackedSearch) return;
    if (_lastSearchTime != null && now.difference(_lastSearchTime!).inSeconds < 3) return;
    _lastTrackedSearch = trimmed;
    _lastSearchTime = now;
    AnalyticsService.instance.trackSearch(query: trimmed);
  }

  bool get _hasActiveFilter =>
      _selectedCategory != 'All' || _selectedPlatform != 'All';

  void _openFilterSheet(List<String> categories) {
    var tempCategory = _selectedCategory;
    var tempPlatform = _selectedPlatform;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(top: 12),
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Filter',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Category',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: categories.map((cat) {
                        final sel = tempCategory == cat;
                        return GestureDetector(
                          onTap: () => setSheetState(() => tempCategory = cat),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: sel
                                  ? AppColors.primary
                                  : AppColors.surfaceSubtle,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: sel ? AppColors.primary : AppColors.border,
                              ),
                            ),
                            child: Text(
                              cat,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: sel
                                        ? Colors.white
                                        : AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Platform',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['All', 'Mobile', 'Web'].map((plat) {
                        final sel = tempPlatform == plat;
                        return GestureDetector(
                          onTap: () => setSheetState(() => tempPlatform = plat),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: sel
                                  ? AppColors.primary
                                  : AppColors.surfaceSubtle,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: sel ? AppColors.primary : AppColors.border,
                              ),
                            ),
                            child: Text(
                              plat,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: sel
                                        ? Colors.white
                                        : AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedCategory = tempCategory;
                            _selectedPlatform = tempPlatform;
                            _visibleCount = _pageSize;
                          });
                          Navigator.of(ctx).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Apply',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<Object> _visibleItems(List<Object> items) {
    final q = _query.trim().toLowerCase();
    return items.where((item) {
      if (item is StylePack) {
        if (_selectedCategory != 'All') {
          final hasCategory = item.screens.any(
            (s) => s.category.toLowerCase() == _selectedCategory.toLowerCase(),
          );
          if (!hasCategory) return false;
        }
        if (_selectedPlatform != 'All') {
          if (!item.platforms.contains(_selectedPlatform.toLowerCase())) return false;
        }
        if (q.isNotEmpty) {
          return item.name.toLowerCase().contains(q) ||
              item.tags.any((t) => t.toLowerCase().contains(q)) ||
              item.platforms.any((platform) => platform.contains(q));
        }
        return true;
      } else if (item is UiDesign) {
        if (_selectedCategory != 'All') {
          if (item.category.toLowerCase() != _selectedCategory.toLowerCase()) return false;
        }
        if (_selectedPlatform != 'All') {
          if (!item.platforms.contains(_selectedPlatform.toLowerCase())) return false;
        }
        if (q.isNotEmpty) {
          return item.title.toLowerCase().contains(q) ||
              item.category.toLowerCase().contains(q) ||
              item.styleTags.any((t) => t.toLowerCase().contains(q)) ||
              item.platforms.any((platform) => platform.contains(q));
        }
        return true;
      }
      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: const AdBanner(),
      body: SafeArea(
        child: FutureBuilder<List<UiDesign>>(
          future: _designs,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 32, color: AppColors.textHint),
                      const SizedBox(height: 14),
                      Text('Could not load designs',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 6),
                      Text(
                        '${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _repository.refresh();
                            _designs = _repository.load();
                          });
                        },
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              );
            }

            final allItems = DesignRepository.itemsOf(snapshot.data!);
            final items = _visibleItems(allItems);
            final totalScreens = items.fold<int>(0, (sum, item) {
              if (item is StylePack) return sum + item.screens.length;
              return sum + 1;
            });

            final visibleCount = _visibleCount.clamp(0, items.length);
            final hasMore = visibleCount < items.length;

            return RefreshIndicator(
              onRefresh: _onRefresh,
              color: AppColors.primary,
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 12, 4),
                    child: Row(
                      children: [
                        if (!_showSearch) ...[
                          Text(
                            'MastUI',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5,
                                ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const CustomerCenterScreen()),
                            ),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceSubtle,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.person_outline_rounded,
                                size: 20,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: _openPromptGenerator,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceSubtle,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.auto_awesome_outlined,
                                size: 20,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: _openSearch,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceSubtle,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.search_rounded,
                                size: 20,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => _openFilterSheet(
                              DesignRepository.categoriesOf(snapshot.data!),
                            ),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: _hasActiveFilter
                                    ? AppColors.primary
                                    : AppColors.surfaceSubtle,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.tune_rounded,
                                size: 20,
                                color: _hasActiveFilter
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ] else ...[
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              onChanged: (v) {
                                    setState(() {
                                      _query = v;
                                      _visibleCount = _pageSize;
                                    });
                                    _trackSearchDebounced(v);
                                  },
                              onSubmitted: (_) => _searchFocusNode.unfocus(),
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                              decoration: InputDecoration(
                                hintText: 'Search…',
                                hintStyle: TextStyle(color: AppColors.textHint),
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 14),
                                filled: true,
                                fillColor: AppColors.surfaceSubtle,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: AppColors.primary,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _showSearch = false;
                                _query = '';
                                _visibleCount = _pageSize;
                                _searchController.clear();
                              });
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceSubtle,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 20,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Subtitle
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Text(
                      '$totalScreens designs',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ),
                ),

                // One grid: style packs first, then standalone screens.
                if (items.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _Message(
                      icon: Icons.search_off,
                      title: 'No matches',
                      body: _selectedCategory != 'All' || _selectedPlatform != 'All'
                          ? 'Try adjusting your filters or search.'
                          : 'Try a different search.',
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 9 / 16,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final item = items[index];
                          return item is StylePack
                              ? _PackCard(pack: item)
                              : _DesignCard(design: item as UiDesign);
                        },
                        childCount: visibleCount,
                      ),
                    ),
                  ),

                // Loading / end-of-list footer
                if (items.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _isLoadingMore
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          )
                        : !hasMore
                            ? Padding(
                                padding: const EdgeInsets.symmetric(vertical: 24),
                                child: Center(
                                  child: Text(
                                    "You've seen all designs",
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: AppColors.textHint,
                                        ),
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                  ),
              ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PackCard extends StatelessWidget {
  const _PackCard({required this.pack});

  final StylePack pack;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('pack-card-${pack.id}'),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DetailScreen(screens: pack.screens)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: DesignPreview(
                design: pack.cover,
                alignment: Alignment.topCenter,
              ),
            ),
            // Download icon top-right
            Positioned(
              top: 10,
              right: 10,
              child: _DownloadButton(
                design: pack.cover,
                title: '${pack.name} (cover)',
              ),
            ),
            // Gradient overlay at bottom for text readability
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 72,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Title + screen count
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pack.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${pack.screens.length} screens',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 11,
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
}

class _DesignCard extends StatelessWidget {
  const _DesignCard({required this.design});

  final UiDesign design;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DetailScreen.single(design: design)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: DesignPreview(
                design: design,
                alignment: Alignment.topCenter,
              ),
            ),
            // Download icon top-right
            Positioned(
              top: 10,
              right: 10,
              child: _DownloadButton(design: design),
            ),
            // Gradient overlay at bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.65),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Title + category
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    design.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    design.category,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 10.5,
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
}

class _DownloadButton extends StatelessWidget {
  const _DownloadButton({required this.design, this.title});

  final UiDesign design;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final label = title ?? design.title;
    return Tooltip(
      message: 'Download $label',
      child: SizedBox(
        width: 44,
        height: 44,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkResponse(
            onTap: () async {
              try {
                await DesignDownloader.download(design);
                AnalyticsService.instance.trackDownload(
                  designId: design.id,
                  category: design.category,
                );
              } on DesignDownloadException catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error.message)),
                );
                return;
              }
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Image saved to Downloads/MastUI')),
              );
            },
            radius: 24,
            child: Center(
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.textPrimary.withValues(alpha: 0.42),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                ),
                child: const Icon(
                  Icons.file_download_outlined,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: AppColors.textHint),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
