import 'package:church_app/core/l10n/generated/app_localizations.dart';
import 'package:church_app/core/utils/breakpoints.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Casca de navegação responsiva: `NavigationBar` embaixo no celular e
/// `NavigationRail` na lateral no tablet (largura ≥ [kTabletBreakpoint]).
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _onSelected(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = <({IconData icon, IconData selectedIcon, String label})>[
      (
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        label: l10n.navHome,
      ),
      (
        icon: Icons.calendar_month_outlined,
        selectedIcon: Icons.calendar_month,
        label: l10n.navSchedule,
      ),
      (
        icon: Icons.campaign_outlined,
        selectedIcon: Icons.campaign,
        label: l10n.navAnnouncements,
      ),
      (
        icon: Icons.volunteer_activism_outlined,
        selectedIcon: Icons.volunteer_activism,
        label: l10n.navPrayer,
      ),
      (icon: Icons.menu, selectedIcon: Icons.menu_open, label: l10n.navMore),
    ];

    final isTablet = MediaQuery.sizeOf(context).width >= kTabletBreakpoint;
    if (isTablet) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _onSelected,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final item in items)
                  NavigationRailDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.selectedIcon),
                    label: Text(item.label),
                  ),
              ],
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
        onDestinationSelected: _onSelected,
        destinations: [
          for (final item in items)
            NavigationDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.selectedIcon),
              label: item.label,
            ),
        ],
      ),
    );
  }
}
