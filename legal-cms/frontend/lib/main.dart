import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/theme/app_theme.dart';
import 'core/api/api_client.dart';
import 'core/utils/local_notifications.dart';
import 'shared/widgets/offline_banner.dart';
import 'shared/widgets/responsive_layout.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/dashboard/screens/dashboard_screen.dart';
import 'features/cases/screens/cases_list_screen.dart';
import 'features/cases/screens/case_detail_screen.dart';
import 'features/cases/screens/case_form_screen.dart';
import 'features/clients/screens/clients_list_screen.dart';
import 'features/clients/screens/client_detail_screen.dart';
import 'features/clients/screens/client_form_screen.dart';
import 'features/hearings/screens/hearings_screen.dart';
import 'features/documents/screens/document_upload_screen.dart';
import 'features/documents/screens/documents_list_screen.dart';
import 'features/search/screens/search_screen.dart';
import 'features/profile/screens/profile_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);

GoRouter _router(WidgetRef ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final isAuth = auth.status == AuthStatus.authenticated;
      final onLogin = state.matchedLocation == '/login';
      final onRegister = state.matchedLocation == '/register';

      if (!isAuth && !onLogin && !onRegister) return '/login';
      if (isAuth && (onLogin || onRegister)) return '/';
      return null;
    },
    routes: [
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => _Shell(child: child),
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: DashboardScreen(),
            ),
          ),
          GoRoute(
            path: '/cases',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: CasesListScreen(),
            ),
            routes: [
              GoRoute(
                path: 'new',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) => const CaseFormScreen(),
              ),
              GoRoute(
                path: ':id',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) {
                  final id = int.parse(state.pathParameters['id']!);
                  return CaseDetailScreen(caseId: id);
                },
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) {
                      final id = int.parse(state.pathParameters['id']!);
                      return CaseFormScreen(caseId: id);
                    },
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/clients',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ClientsListScreen(),
            ),
            routes: [
              GoRoute(
                path: 'new',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) => const ClientFormScreen(),
              ),
              GoRoute(
                path: ':id',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) {
                  final id = int.parse(state.pathParameters['id']!);
                  return ClientDetailScreen(clientId: id);
                },
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) {
                      final id = int.parse(state.pathParameters['id']!);
                      return ClientFormScreen(clientId: id);
                    },
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/hearings',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HearingsScreen(),
            ),
          ),
          GoRoute(
            path: '/documents',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: DocumentsListScreen(),
            ),
          ),
          GoRoute(
            path: '/search',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SearchScreen(),
            ),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ProfileScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginScreen(
          onLoginSuccess: () => context.go('/'),
        ),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
    ],
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('recent_searches');

  await initLocalNotifications();

  runApp(const ProviderScope(child: LegalCMSApp()));
}

class LegalCMSApp extends ConsumerWidget {
  const LegalCMSApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final router = _router(ref);
    return MaterialApp.router(
      key: ValueKey(themeMode),
      title: 'Legal CMS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) => OfflineBanner(child: child!),
    );
  }
}

class _Shell extends ConsumerWidget {
  final Widget child;
  const _Shell({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final sel = _selectedIndex(context);

    final navDestinations = const [
      NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
      NavigationDestination(icon: Icon(Icons.folder_outlined), selectedIcon: Icon(Icons.folder), label: 'Cases'),
      NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Clients'),
      NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Hearings'),
      NavigationDestination(icon: Icon(Icons.description_outlined), selectedIcon: Icon(Icons.description), label: 'Docs'),
    ];

    final railDestinations = <NavigationRailDestination>[
      const NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: Text('Dashboard')),
      const NavigationRailDestination(icon: Icon(Icons.folder_outlined), selectedIcon: Icon(Icons.folder), label: Text('Cases')),
      const NavigationRailDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: Text('Clients')),
      const NavigationRailDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: Text('Hearings')),
      const NavigationRailDestination(icon: Icon(Icons.description_outlined), selectedIcon: Icon(Icons.description), label: Text('Docs')),
    ];

    void onNav(int i) {
      switch (i) {
        case 0: context.go('/');
        case 1: context.go('/cases');
        case 2: context.go('/clients');
        case 3: context.go('/hearings');
        case 4: context.go('/documents');
      }
    }

    if (isDesktop(context) || isTablet(context)) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: sel,
              onDestinationSelected: onNav,
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.balance, color: AppColors.courtGold, size: 32),
                    const SizedBox(height: 4),
                    Text('Legal CMS', style: TextStyle(fontSize: 10, color: AppColors.courtGold, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              trailing: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined),
                      onPressed: () {},
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.person_outline),
                          onPressed: () => context.push('/profile'),
                          tooltip: 'Profile',
                        ),
                        Text('Profile', style: TextStyle(fontSize: 9, color: Colors.white54)),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.logout, color: AppColors.error),
                      onPressed: () => ref.read(authProvider.notifier).logout(),
                      tooltip: 'Logout',
                    ),
                  ],
                ),
              ),
              destinations: railDestinations,
              backgroundColor: const Color(0xFF0D1B2A),
              unselectedIconTheme: const IconThemeData(color: Colors.white54),
              selectedIconTheme: const IconThemeData(color: AppColors.courtGold),
              unselectedLabelTextStyle: const TextStyle(color: Colors.white54, fontSize: 11),
              selectedLabelTextStyle: const TextStyle(color: AppColors.courtGold, fontSize: 11, fontWeight: FontWeight.w600),
              minWidth: 80,
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.courtDarkBrown, AppColors.courtNavy],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          child: AppBar(
            title: Text(auth.user?.fullName ?? 'Legal CMS',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            actions: [
              IconButton(
                icon: const Icon(Icons.person_outline),
                onPressed: () => context.push('/profile'),
                tooltip: 'Profile',
              ),
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {},
              ),
              Container(
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.logout, color: AppColors.error),
                  onPressed: () => ref.read(authProvider.notifier).logout(),
                  tooltip: 'Logout',
                ),
              ),
            ],
          ),
        ),
      ),
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 20, offset: const Offset(0, -4)),
          ],
        ),
        child: NavigationBar(
          selectedIndex: sel,
          onDestinationSelected: onNav,
          destinations: navDestinations,
        ),
      ),
    );
  }

  int _selectedIndex(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    if (loc == '/') return 0;
    if (loc.startsWith('/cases')) return 1;
    if (loc.startsWith('/clients')) return 2;
    if (loc.startsWith('/hearings')) return 3;
    if (loc.startsWith('/documents')) return 4;
    return 0;
  }
}

class _PlaceholderScreen extends StatelessWidget {
  final String label;
  final IconData icon;

  const _PlaceholderScreen({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Theme.of(context).colorScheme.primary.withAlpha(128)),
          const SizedBox(height: 16),
          Text(label, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('Coming soon', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
        ],
      ),
    );
  }
}
