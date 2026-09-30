import 'package:flutter/material.dart';

import '../services/connection_service.dart';

class ConnectionBanner extends StatefulWidget {
  const ConnectionBanner({
    super.key,
    required this.child,
    required this.service,
  });

  final Widget child;
  final ConnectionService service;

  @override
  State<ConnectionBanner> createState() => _ConnectionBannerState();
}

class _ConnectionBannerState extends State<ConnectionBanner>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.service.resume();
    } else {
      widget.service.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.service,
      builder: (context, _) {
        final offline = widget.service.status == ConnectionStatus.offline;
        final visible =
            offline || widget.service.status == ConnectionStatus.slow;
        return Column(
          children: [
            if (visible)
              Material(
                color: Theme.of(context).colorScheme.errorContainer,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                    child: Row(
                      children: [
                        Icon(offline ? Icons.wifi_off : Icons.network_check),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              offline
                                  ? ConnectionService.offlineMessage
                                  : ConnectionService.slowMessage,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: widget.service.isChecking
                              ? null
                              : widget.service.check,
                          child: Text(
                            widget.service.isChecking ? 'Checking…' : 'Retry',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Expanded(child: widget.child),
          ],
        );
      },
    );
  }
}
