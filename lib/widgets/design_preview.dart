import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/ui_design.dart';
import '../theme/app_colors.dart';

/// Renders a design's screenshot from Cloudflare, with a bundled asset fallback
/// for local development catalogs.
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
    final url = design.imageUrl;
    if (url != null) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: fit,
        alignment: alignment,
        width: double.infinity,
        placeholder: (context, url) => const _Placeholder(),
        errorWidget: (context, url, error) => const _Placeholder(),

      );
    }

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
