import 'dart:async';

import 'package:flutter/material.dart';

import '../services/app_review_service.dart';
import '../theme/app_colors.dart';
import 'generate_prompt_screen.dart';
import 'home_screen.dart';

/// Two-tab shell: the design gallery and the prompt generator.
///
/// Everything to do with the subscription lives inside the Generate tab —
/// that is the only place a paid limit is ever reached, so it is where people
/// look for their plan.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    unawaited(AppReviewService.instance.trackLaunch());
    AppReviewService.instance.scheduleReturningUserPrompt();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // IndexedStack, not a swap: switching tabs must not throw away the
      // gallery's scroll position or a screenshot already picked.
      body: IndexedStack(
        index: _index,
        children: const [HomeScreen(), GeneratePromptScreen()],
      ),
      bottomNavigationBar: _BottomNav(
        index: _index,
        onChanged: (index) => setState(() => _index = index),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.grid_view_outlined,
                activeIcon: Icons.grid_view_rounded,
                label: 'Designs',
                selected: index == 0,
                onTap: () => onChanged(0),
              ),
              _NavItem(
                icon: Icons.auto_awesome_outlined,
                activeIcon: Icons.auto_awesome,
                label: 'Generate',
                selected: index == 1,
                onTap: () => onChanged(1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textMuted;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        child: AnimatedContainer(
          duration: AppMotion.duration,
          curve: AppMotion.curve,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(selected ? activeIcon : icon, size: 22, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
