import 'package:flutter/material.dart';

import '../models/ui_design.dart';
import '../widgets/design_preview.dart';

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
  State<FullscreenViewerScreen> createState() => _FullscreenViewerScreenState();
}

class _FullscreenViewerScreenState extends State<FullscreenViewerScreen> {
  late final PageController _controller;
  final _transform = TransformationController();
  late int _index;
  bool _zoomed = false;
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    _transform.dispose();
    super.dispose();
  }

  void _syncZoomState() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
  }

  void _resetZoom() {
    _transform.value = Matrix4.identity();
    if (_zoomed) setState(() => _zoomed = false);
  }

  void _handleDoubleTap() {
    if (_zoomed) {
      _resetZoom();
      return;
    }
    final position = _doubleTapDetails?.localPosition;
    if (position == null) return;
    const scale = 2.5;
    _transform.value = Matrix4.identity()
      ..translateByDouble(
          -position.dx * (scale - 1), -position.dy * (scale - 1), 0, 1)
      ..scaleByDouble(scale, scale, scale, 1);
    setState(() => _zoomed = true);
  }

  @override
  Widget build(BuildContext context) {
    final screens = widget.screens;
    final isPack = screens.length > 1;

    // System back must also report the final index, not just the close button.
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
              child: PageView.builder(
                controller: _controller,
                // While zoomed, one-finger drags pan the image instead of
                // switching pages.
                physics: _zoomed
                    ? const NeverScrollableScrollPhysics()
                    : const PageScrollPhysics(),
                itemCount: screens.length,
                onPageChanged: (index) {
                  _resetZoom();
                  setState(() => _index = index);
                },
                itemBuilder: (context, index) => GestureDetector(
                  onDoubleTapDown: (details) => _doubleTapDetails = details,
                  onDoubleTap: _handleDoubleTap,
                  child: InteractiveViewer(
                    // Neighbouring pages are pre-built; only the visible one
                    // may own the shared transform.
                    transformationController:
                        index == _index ? _transform : null,
                    minScale: 1.0,
                    maxScale: 5.0,
                    onInteractionEnd: (_) => _syncZoomState(),
                    child: Center(
                      child: DesignPreview(
                        design: screens[index],
                        fit: BoxFit.contain,
                        alignment: Alignment.center,
                      ),
                    ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        color: Colors.white,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.4),
                        ),
                        onPressed: () => Navigator.of(context).pop(_index),
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
                      // Balances the close button so the counter stays centred.
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
