import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/ui_design.dart';
import '../theme/app_colors.dart';

/// Renders a design's screenshot, wherever it lives.
///
/// Prefers the bundled asset (instant, offline) over the network URL, and falls
/// back to a neutral placeholder so a missing image never breaks the grid.
class DesignPreview extends StatelessWidget {
  const DesignPreview({
    super.key,
    required this.design,
    this.alignment = Alignment.topCenter,
    this.fit = BoxFit.cover,
  });

  final UiDesign design;
  final Alignment alignment;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final asset = design.imageAsset;
    if (asset != null) {
      return Image.asset(
        asset,
        fit: fit,
        alignment: alignment,
        width: double.infinity,
        errorBuilder: (context, error, stack) => const _Placeholder(),
      );
    }

    final url = design.imageUrl;
    if (url != null) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: fit,
        alignment: alignment,
        width: double.infinity,
        placeholder: (context, url) => const _Placeholder(),
        errorWidget: (context, url, error) => const _Placeholder(),
        memCacheWidth: 400,
      );
    }

    return const _Placeholder();
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceSubtle,
      alignment: Alignment.center,
      child: const Icon(Icons.image_outlined, color: AppColors.textHint, size: 32),
    );
  }
}
