import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../services/prompt_generator_service.dart';
import '../services/revenue_cat_service.dart';
import '../theme/app_colors.dart';
import 'customer_center_screen.dart';
import 'paywall_screen.dart';

/// Upload any UI screenshot and get back a prompt that recreates it.
class GeneratePromptScreen extends StatefulWidget {
  const GeneratePromptScreen({super.key});

  @override
  State<GeneratePromptScreen> createState() => _GeneratePromptScreenState();
}

/// Display only — the Worker enforces the real cap. Keep in sync with
/// `FREE_DAILY_LIMIT` in worker/src/index.js.
const _freeDailyLimit = 4;

class _GeneratePromptScreenState extends State<GeneratePromptScreen> {
  File? _image;
  String _platform = 'mobile';
  bool _isGenerating = false;
  GeneratedPrompt? _result;
  String? _error;
  bool _isPro = false;

  /// Free generations left today. Null until the Worker tells us — it owns the
  /// counter, so guessing locally would only ever disagree with it.
  int? _remaining;

  @override
  void initState() {
    super.initState();
    _checkEntitlement();
  }

  Future<void> _checkEntitlement() async {
    final isPro = await RevenueCatService.instance.isPro();
    if (!mounted) return;
    setState(() => _isPro = isPro);
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      // The Worker rejects anything over 4 MB, and the vision model gains
      // nothing from a larger image than this.
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 90,
    );
    if (picked == null || !mounted) return;

    setState(() {
      _image = File(picked.path);
      _result = null;
      _error = null;
    });
  }

  Future<void> _generate() async {
    final image = _image;
    if (image == null || _isGenerating) return;

    setState(() {
      _isGenerating = true;
      _error = null;
    });

    try {
      final result = await PromptGeneratorService.instance.generate(
        image: image,
        platform: _platform,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _remaining = result.remaining;
        _isPro = result.isPro;
      });
    } on PromptGenerationException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        if (error.isQuotaExhausted) _remaining = 0;
      });

      // Out of free generations is the one moment the paywall is genuinely
      // useful, so offer it here rather than gating the whole screen.
      if (error.canUpgrade) await _offerUpgrade();
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _offerUpgrade() async {
    final subscribed = await showPaywall(context);
    if (!subscribed || !mounted) return;

    setState(() {
      _isPro = true;
      _error = null;
      _remaining = null;
    });
    await _generate();
  }

  /// Opened from the plan card — plans, restore, cancel and support all live
  /// behind it, so the entitlement can have changed by the time we come back.
  Future<void> _openSubscription() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CustomerCenterScreen()),
    );
    if (!mounted) return;
    await _checkEntitlement();
  }

  Future<void> _copyPrompt() async {
    final result = _result;
    if (result == null) return;

    await Clipboard.setData(ClipboardData(text: result.prompt));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Prompt copied — paste it into your AI tool'),
        ),
      );
  }

  void _reset() {
    setState(() {
      _image = null;
      _result = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final image = _image;
    final result = _result;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Screenshot to prompt'),
        actions: [
          IconButton(
            onPressed: _openSubscription,
            icon: const Icon(Icons.person_outline_rounded, size: 22),
            tooltip: 'Subscription',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
            'Upload any UI image and get a prompt that rebuilds it.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          _PlanCard(
            isPro: _isPro,
            remaining: _remaining,
            onUpgrade: _offerUpgrade,
            onManage: _openSubscription,
          ),
          const SizedBox(height: 20),
          if (image == null)
            _UploadTarget(onTap: _pickImage)
          else
            _ImagePreview(image: image, onReplace: _pickImage),
          const SizedBox(height: 20),
          Text('Target', style: textTheme.titleMedium),
          const SizedBox(height: 10),
          Row(
            children: [
              _PlatformChip(
                label: 'Mobile app',
                selected: _platform == 'mobile',
                onTap: () => setState(() => _platform = 'mobile'),
              ),
              const SizedBox(width: 8),
              _PlatformChip(
                label: 'Web app',
                selected: _platform == 'web',
                onTap: () => setState(() => _platform = 'web'),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 20),
            _ErrorNotice(message: _error!),
          ],
          if (result != null) ...[
            const SizedBox(height: 24),
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
              child: SelectableText(result.prompt, style: textTheme.bodyMedium),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text('Try another screenshot'),
            ),
          ],
        ],
      ),
      // The app's own tab bar sits below this Scaffold, so the CTA only needs
      // plain padding — a SafeArea here would inset twice.
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (result == null)
              FilledButton.icon(
                onPressed: image == null || _isGenerating ? null : _generate,
                icon: _isGenerating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_awesome_outlined, size: 20),
                label: Text(
                  _isGenerating ? 'Reading screenshot…' : 'Generate prompt',
                ),
              )
            else
              FilledButton.icon(
                onPressed: _copyPrompt,
                icon: const Icon(Icons.copy_outlined, size: 20),
                label: const Text('Copy prompt'),
              ),
          ],
        ),
      ),
    );
  }
}

/// Plan status and the way into everything paid — plans, restore, cancel.
/// It lives on this tab because the daily cap is the only thing the
/// subscription changes.
class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.isPro,
    required this.remaining,
    required this.onUpgrade,
    required this.onManage,
  });

  final bool isPro;
  final int? remaining;
  final VoidCallback onUpgrade;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isPro ? Colors.white : AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPro ? 'Mast UI Pro' : 'Free plan',
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(_status(), style: textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: isPro ? onManage : onUpgrade,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              minimumSize: const Size(44, 44),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: Text(isPro ? 'Manage' : 'Upgrade'),
          ),
        ],
      ),
    );
  }

  String _status() {
    if (isPro) return '50 prompts a day · no ads';

    final remaining = this.remaining;
    if (remaining == null) return '$_freeDailyLimit prompts a day';
    if (remaining == 0) return 'Out of prompts — resets at midnight';
    return '$remaining of $_freeDailyLimit prompts left today';
  }
}

class _UploadTarget extends StatelessWidget {
  const _UploadTarget({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          color: AppColors.surfaceSubtle,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.add_photo_alternate_outlined,
              size: 34,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 12),
            Text(
              'Choose a UI image',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.image, required this.onReplace});

  final File image;
  final VoidCallback onReplace;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 300,
          decoration: BoxDecoration(
            color: AppColors.surfaceSubtle,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.file(image, fit: BoxFit.contain),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: onReplace,
          icon: const Icon(Icons.swap_horiz_rounded, size: 18),
          label: const Text('Replace image'),
          style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _PlatformChip extends StatelessWidget {
  const _PlatformChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.duration,
        curve: AppMotion.curve,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.button),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppColors.textHint),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
