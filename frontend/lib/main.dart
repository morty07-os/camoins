import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'login_page.dart';
import 'pages/register_page.dart';
import 'pages/profile_page.dart';
import 'pages/driver_home_page.dart';
import 'pages/customer_home_page.dart';
import 'providers/auth_provider.dart';

void main() {
  runApp(const ProviderScope(child: BackhaulApp()));
}

class BackhaulApp extends ConsumerWidget {
  const BackhaulApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = GoRouter(
      initialLocation: '/',
      redirect: (context, state) {
        final authState = ref.read(authProvider);
        final isLoading = authState.isLoading;
        final isAuthenticated = authState.isAuthenticated;
        final user = authState.currentUser;

        // Still loading
        if (isLoading) {
          return null;
        }

        final isAuthRoute = state.matchedLocation == '/login' ||
                           state.matchedLocation == '/register';

        // Not authenticated and trying to access protected route
        if (!isAuthenticated && !isAuthRoute) {
          return '/login';
        }

        // Authenticated and on auth route, redirect to home
        if (isAuthenticated && isAuthRoute) {
          if (user?.isDriver ?? false) {
            return '/driver-home';
          } else {
            return '/customer-home';
          }
        }

        // Authenticated and on root, redirect to appropriate home
        if (isAuthenticated && state.matchedLocation == '/') {
          if (user?.isDriver ?? false) {
            return '/driver-home';
          } else {
            return '/customer-home';
          }
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginPage(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterPage(),
        ),
        GoRoute(
          path: '/driver-home',
          builder: (context, state) => const DriverHomePage(),
        ),
        GoRoute(
          path: '/customer-home',
          builder: (context, state) => const CustomerHomePage(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfilePage(),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const LoginPage(),
        ),
      ],
    );

    // Listen to auth changes to trigger router rebuild
    ref.listen<AuthState>(authProvider, (previous, next) {
      router.refresh();
    });

    return MaterialApp.router(
      title: 'Backhaul',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.light,
        ),
      ),
      routerConfig: router,
    );
  }
}
