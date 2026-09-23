import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_screen.dart';
import '../../features/auth/state/auth_notifier.dart';
import '../../features/citizen/presentation/citizen_home_screen.dart';
import '../../features/worker/presentation/worker_dashboard_screen.dart';
import '../../features/admin/presentation/admin_dashboard_screen.dart';
import '../../shared/models/user_model.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/auth',
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
    redirect: (context, state) {
      final user = authState.user;
      final isAuthPath = state.uri.toString() == '/auth';

      if (user == null) {
        return isAuthPath ? null : '/auth';
      }

      // Role-based routing
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
    },
  );
});
