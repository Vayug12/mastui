import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../services/prompt_generator_service.dart';
import '../services/revenue_cat_service.dart';
import '../theme/app_colors.dart';
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

  String _footerNote() {
    if (_isPro) {
      return 'Tip: AI works best when you share this prompt + screenshot';
    }

    final remaining = _remaining;
    if (remaining == null) {
      return '$_freeDailyLimit free prompts a day';
    }
    if (remaining == 0) {
      return 'Out of free prompts — resets at midnight';
    }
    return '$remaining of $_freeDailyLimit free prompts left today';
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 22),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            const Text('Screenshot to prompt'),
            if (_isPro) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'PRO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
            'Upload any app screenshot and get a prompt that rebuilds it.',
            style: textTheme.bodyMedium,
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
            Row(
              children: [
                Text('Prompt', style: textTheme.titleLarge),
                const Spacer(),
                if (!result.isPro)
                  Text(
                    '${result.remaining} left today',
                    style: textTheme.bodySmall,
                  ),
              ],
            ),
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
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
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
            const SizedBox(height: 8),
            Text(
              _footerNote(),
              textAlign: TextAlign.center,
              style: textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
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
              'Choose a screenshot',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'PNG, JPEG/JPG or WebP',
              style: Theme.of(context).textTheme.bodySmall,
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
