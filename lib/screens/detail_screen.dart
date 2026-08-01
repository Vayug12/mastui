import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/ui_design.dart';
import '../services/analytics_service.dart';
import '../services/design_downloader.dart';
import '../theme/app_colors.dart';
import '../widgets/design_preview.dart';
import '../widgets/feedback_sheet.dart';
import 'fullscreen_viewer_screen.dart';

/// Detail view for one design or a whole style pack — same layout for both,
/// so the app has a single detail experience. For packs the preview is a
/// carousel: swiping updates the title, tags, prompt and actions to match
/// the visible screen.
class DetailScreen extends StatefulWidget {
  const DetailScreen({super.key, required this.screens, this.initialIndex = 0});

  DetailScreen.single({Key? key, required UiDesign design})
      : this(key: key, screens: [design]);

  final List<UiDesign> screens;
  final int initialIndex;

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late final PageController _controller;
  late int _index;
  late DateTime _screenOpenedAt;
  String _lastDwellId = '';
  String _lastDwellCategory = '';

  UiDesign get _current => widget.screens[_index];

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: _index);
    _screenOpenedAt = DateTime.now();
    _lastDwellId = _current.id;
    _lastDwellCategory = _current.category;
    // Track view event (best-effort, fire-and-forget)
    AnalyticsService.instance.trackView(
      designId: _current.id,
      category: _current.category,
    );
  }

  void _sendDwell() {
    final seconds = DateTime.now().difference(_screenOpenedAt).inSeconds;
    if (_lastDwellId.isNotEmpty) {
      AnalyticsService.instance.trackDwell(
        designId: _lastDwellId,
        category: _lastDwellCategory,
        seconds: seconds,
      );
    }
  }

  @override
  void dispose() {
    _sendDwell();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _copyPrompt() async {
    await Clipboard.setData(ClipboardData(text: _current.prompt));
    // Track copy event (best-effort)
    AnalyticsService.instance.trackCopy(
      designId: _current.id,
      category: _current.category,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Prompt copied — paste it into your AI tool'),
        ),
      );
  }

  void _showFeedbackSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => FeedbackSheet(
        designId: _current.id,
        category: _current.category,
      ),
    );
  }

  Future<void> _openFullscreen() async {
    final result = await Navigator.of(context).push<int>(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            FullscreenViewerScreen(
          screens: widget.screens,
          initialIndex: _index,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 150),
      ),
    );
    if (!mounted || result == null || result == _index) return;
    setState(() => _index = result);
    _controller.jumpToPage(result);
  }

  Future<void> _downloadImage() async {
    try {
      await DesignDownloader.download(_current);
      AnalyticsService.instance.trackDownload(
        designId: _current.id,
        category: _current.category,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image saved to Downloads/MastUI')),
      );
    } on DesignDownloadException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final screens = widget.screens;
    final isPack = screens.length > 1;
    // Cap the mockup instead of rendering it at full native height — at
    // 390x844 it alone would fill the viewport and hide everything else
    // below the fold, forcing a scroll before users see the prompt at all.
    final previewHeight =
        (MediaQuery.of(context).size.height * 0.4).clamp(260.0, 420.0);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 22),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(_current.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.feedback_outlined, size: 22),
            tooltip: 'Send feedback',
            onPressed: () => _showFeedbackSheet(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          SizedBox(
            height: previewHeight,
            child: PageView.builder(
              controller: _controller,
              itemCount: screens.length,
              onPageChanged: (index) {
                _sendDwell();
                setState(() => _index = index);
                _screenOpenedAt = DateTime.now();
                _lastDwellId = widget.screens[index].id;
                _lastDwellCategory = widget.screens[index].category;
                AnalyticsService.instance.trackView(
                  designId: widget.screens[index].id,
                  category: widget.screens[index].category,
                );
              },
              itemBuilder: (context, index) {
                final isWeb = screens[index].platforms.contains('web');
                return Center(
                  child: AspectRatio(
                    aspectRatio: isWeb ? 16 / 9 : 390 / 844,
                    child: GestureDetector(
                      onTap: _openFullscreen,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          border: Border.all(color: AppColors.border),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            DesignPreview(
                              design: screens[index],
                              alignment: Alignment.center,
                              fit: isWeb ? BoxFit.cover : BoxFit.contain,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (isPack) ...[
            const SizedBox(height: 12),
            _Dots(count: screens.length, active: _index),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Tag(label: _current.category, emphasized: true),
              for (final platform in _current.platforms)
                _Tag(label: platform == 'web' ? 'Web app' : 'Mobile app'),
              for (final tag in _current.styleTags) _Tag(label: tag),
            ],
          ),
          const SizedBox(height: 20),
          Text('Prompt', style: textTheme.titleLarge),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.border),
            ),
            child: SelectableText(_current.prompt, style: textTheme.bodyMedium),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _downloadImage,
                    icon: const Icon(Icons.file_download_outlined, size: 20),
                    label: const Text('Download', maxLines: 1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _copyPrompt,
                    icon: const Icon(Icons.copy_outlined, size: 20),
                    label: const Text('Copy prompt'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'For best results, provide the image and the prompt to the AI',
              style: textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == active ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == active ? AppColors.primary : AppColors.border,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, this.emphasized = false});

  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: emphasized ? AppColors.primary.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.button),
        border: Border.all(
          color: emphasized
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.border,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: emphasized ? AppColors.primary : AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
