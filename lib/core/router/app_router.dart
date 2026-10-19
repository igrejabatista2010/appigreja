import 'package:church_app/core/router/app_shell.dart';
import 'package:church_app/core/router/placeholder_page.dart';
import 'package:go_router/go_router.dart';

abstract final class AppRoutes {
  static const home = '/inicio';
  static const schedule = '/agenda';
  static const announcements = '/comunicados';
  static const prayer = '/oracao';
  static const more = '/mais';
}

/// Rotas do app. Os guardas de sessão, status e role entram com o `AuthBloc`
/// (plano do app, A2.5).
GoRouter createAppRouter() {
  return GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          _branch(AppRoutes.home, (l10n) => l10n.navHome),
          _branch(AppRoutes.schedule, (l10n) => l10n.navSchedule),
          _branch(AppRoutes.announcements, (l10n) => l10n.navAnnouncements),
          _branch(AppRoutes.prayer, (l10n) => l10n.navPrayer),
          _branch(AppRoutes.more, (l10n) => l10n.navMore),
        ],
      ),
    ],
  );
}

StatefulShellBranch _branch(String path, PlaceholderTitle titleOf) {
  return StatefulShellBranch(
    routes: [
      GoRoute(
        path: path,
        builder: (context, state) => PlaceholderPage(titleOf: titleOf),
      ),
    ],
  );
}
