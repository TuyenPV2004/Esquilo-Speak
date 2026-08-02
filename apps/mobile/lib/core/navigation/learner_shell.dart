import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';

class LearnerShell extends StatelessWidget {
  const LearnerShell({
    required this.navigationShell,
    this.onBranchChanged,
    super.key,
  });

  final StatefulNavigationShell navigationShell;
  final Future<void> Function(int previousIndex, int nextIndex)?
  onBranchChanged;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final destinations = [
      NavigationDestination(
        icon: const Icon(Icons.home_outlined),
        selectedIcon: const Icon(Icons.home),
        label: strings.todayNav,
      ),
      NavigationDestination(
        icon: const Icon(Icons.school_outlined),
        selectedIcon: const Icon(Icons.school),
        label: strings.learnNav,
      ),
      NavigationDestination(
        icon: const Icon(Icons.event_repeat_outlined),
        selectedIcon: const Icon(Icons.event_repeat),
        label: strings.reviewNav,
      ),
      NavigationDestination(
        icon: const Icon(Icons.person_outline),
        selectedIcon: const Icon(Icons.person),
        label: strings.profileNav,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 840) {
          return Scaffold(
            body: Row(
              children: [
                SafeArea(
                  child: NavigationRail(
                    selectedIndex: navigationShell.currentIndex,
                    labelType: NavigationRailLabelType.all,
                    onDestinationSelected: _goToBranch,
                    destinations: destinations
                        .map(
                          (item) => NavigationRailDestination(
                            icon: item.icon,
                            selectedIcon: item.selectedIcon,
                            label: Text(item.label),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: navigationShell),
              ],
            ),
          );
        }
        return Scaffold(
          body: navigationShell,
          bottomNavigationBar: NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _goToBranch,
            destinations: destinations,
          ),
        );
      },
    );
  }

  Future<void> _goToBranch(int index) async {
    await onBranchChanged?.call(navigationShell.currentIndex, index);
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}
