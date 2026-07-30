import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../models/ui_design.dart';

/// Black fullscreen gallery: pinch or double-tap to zoom, swipe horizontally
/// between a pack's screens. Pops with the index the user ended on so the
/// detail carousel can stay in sync.
class FullscreenViewerScreen extends StatefulWidget {
  const FullscreenViewerScreen({
    super.key,
    required this.screens,
    this.initialIndex = 0,
  });

  final List<UiDesign> screens;
  final int initialIndex;

  @override
  State<FullscreenViewerScreen> createState() =>
      _FullscreenViewerScreenState();
}

class _FullscreenViewerScreenState extends State<FullscreenViewerScreen> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  PhotoViewGalleryPageOptions _buildPage(BuildContext context, int index) {
    final design = widget.screens[index];
    final url = design.imageUrl;
    if (url != null) {
      return PhotoViewGalleryPageOptions(
        imageProvider: NetworkImage(url),
        initialScale: PhotoViewComputedScale.contained,
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 4,
      );
    }

    final asset = design.imageAsset;
    if (asset != null) {
      return PhotoViewGalleryPageOptions(
        imageProvider: AssetImage(asset),
        initialScale: PhotoViewComputedScale.contained,
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 4,
      );
    }

    return PhotoViewGalleryPageOptions.customChild(
      child: Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: const Icon(Icons.image_outlined, color: Colors.white24, size: 48),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = widget.screens;
    final isPack = screens.length > 1;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_index);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(
              child: PhotoViewGallery.builder(
                pageController: _controller,
                itemCount: screens.length,
                builder: _buildPage,
                backgroundDecoration:
                    const BoxDecoration(color: Colors.black),
                onPageChanged: (index) => setState(() => _index = index),
                scrollPhysics: const BouncingScrollPhysics(),
                loadingBuilder: (context, event) => const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
            // Close button + page counter overlay.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        color: Colors.white,
                        style: IconButton.styleFrom(
                          backgroundColor:
                              Colors.black.withValues(alpha: 0.4),
                        ),
                        onPressed: () =>
                            Navigator.of(context).pop(_index),
                        tooltip: 'Close',
                      ),
                      const Spacer(),
                      if (isPack)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            '${_index + 1} / ${screens.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      if (isPack) const Spacer() else const SizedBox.shrink(),
                    ],
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
