import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_screen.dart';
import '../../features/auth/state/auth_notifier.dart';
import '../../features/citizen/presentation/citizen_home_screen.dart';
import '../../features/worker/presentation/worker_dashboard_screen.dart';
import '../../features/admin/presentation/admin_dashboard_screen.dart';
import '../../shared/models/user_model.dart';

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final user = _ref.read(authProvider).user;
    final isAuthPath = state.uri.toString() == '/auth';

    if (user == null) {
      return isAuthPath ? null : '/auth';
    }

    if (isAuthPath) {
      switch (user.role) {
        case UserRole.CITIZEN:
          return '/citizen';
        case UserRole.WORKER:
          return '/worker';
        case UserRole.ADMIN:
          return '/admin';
      }
    }
    return null;
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) => RouterNotifier(ref));

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: '/auth',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/citizen',
        builder: (context, state) => const CitizenHomeScreen(),
      ),
      GoRoute(
        path: '/worker',
        builder: (context, state) => const WorkerDashboardScreen(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
    ],
  );
});
