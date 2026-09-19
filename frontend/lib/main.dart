import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'login_page.dart';
import 'pages/register_page.dart';
import 'pages/profile_page.dart';
import 'pages/customer_home_page.dart';
import 'pages/driver_navigation.dart';
import 'pages/add_truck_page.dart';
import 'pages/edit_truck_page.dart';
import 'pages/truck_details_page.dart';
import 'pages/publish_return_trip_page.dart';
import 'pages/edit_return_trip_page.dart';
import 'pages/return_trip_details_page.dart';
import 'pages/trip_search_page.dart';
import 'pages/trip_search_results_page.dart';
import 'pages/search_trip_details_page.dart';
import 'pages/request_form_page.dart';
import 'pages/driver_requests_page.dart';
import 'pages/messages_page.dart';
import 'pages/chat_page.dart';
import 'models/trip.dart';
import 'providers/auth_provider.dart';
import 'theme/app_theme.dart';
import 'config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Resolve the backend URL (runtime override / platform default) before the
  // first network or socket call.
  await AppConfig.load();
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

        final location = state.matchedLocation;
        final isAuthRoute = location == '/login' || location == '/register';

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
        if (isAuthenticated && location == '/') {
          if (user?.isDriver ?? false) {
            return '/driver-home';
          } else {
            return '/customer-home';
          }
        }

        final isDriverRoute = location.startsWith('/driver') ||
            location.startsWith('/add-truck') ||
            location.startsWith('/edit-truck') ||
            location.startsWith('/edit-return-trip') ||
            location.startsWith('/publish-return-trip');

        // A customer must not access driver (truck management) screens
        if (isAuthenticated && user?.isCustomer == true && isDriverRoute) {
          return '/customer-home';
        }

        // A driver must not access customer screens
        if (isAuthenticated && user?.isDriver == true && location.startsWith('/customer')) {
          return '/driver-home';
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
          builder: (context, state) => const DriverNavigation(),
        ),
        GoRoute(
          path: '/driver-trucks',
          builder: (context, state) => const DriverNavigation(),
        ),
        GoRoute(
          path: '/driver-profile',
          builder: (context, state) => const DriverNavigation(),
        ),
        GoRoute(
          path: '/driver-trips',
          builder: (context, state) => const DriverNavigation(),
        ),
        GoRoute(
          path: '/publish-return-trip',
          builder: (context, state) => const PublishReturnTripPage(),
        ),
        GoRoute(
          path: '/edit-return-trip/:id',
          builder: (context, state) {
            final tripId = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
            return EditReturnTripPage(tripId: tripId);
          },
        ),
        GoRoute(
          path: '/driver-return-trip-details/:id',
          builder: (context, state) {
            final tripId = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
            return ReturnTripDetailsPage(tripId: tripId);
          },
        ),
        GoRoute(
          path: '/add-truck',
          builder: (context, state) => const AddTruckPage(),
        ),
        GoRoute(
          path: '/edit-truck/:id',
          builder: (context, state) {
            final truckId = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
            return EditTruckPage(truckId: truckId);
          },
        ),
        GoRoute(
          path: '/driver-truck-details/:id',
          builder: (context, state) {
            final truckId = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
            return TruckDetailsPage(truckId: truckId);
          },
        ),
        GoRoute(
          path: '/customer-home',
          builder: (context, state) => const CustomerHomePage(),
        ),
        GoRoute(
          path: '/search-trips',
          builder: (context, state) => const TripSearchPage(),
        ),
        GoRoute(
          path: '/search-results',
          builder: (context, state) {
            final results = state.extra as List? ?? [];
            return TripSearchResultsPage(results: results);
          },
        ),
        GoRoute(
          path: '/search-trip-details/:id',
          builder: (context, state) {
            final tripId = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
            final result = state.extra;
            return SearchTripDetailsPage(
              tripId: tripId,
              initialResult: result,
            );
          },
        ),
        GoRoute(
          path: '/request-form/:tripId',
          builder: (context, state) {
            final tripId = int.tryParse(state.pathParameters['tripId'] ?? '') ?? 0;
            final trip = state.extra as Trip?;
            if (trip == null) {
              return Scaffold(
                appBar: AppBar(title: const Text('Erreur')),
                body: const Center(child: Text('Trajet non disponible')),
              );
            }
            return RequestFormPage(
              tripId: tripId,
              trip: trip,
            );
          },
        ),
        GoRoute(
          path: '/driver-requests',
          builder: (context, state) => const DriverRequestsPage(),
        ),
        GoRoute(
          path: '/driver-messages',
          builder: (context, state) => const DriverNavigation(),
        ),
        GoRoute(
          path: '/messages',
          builder: (context, state) => const MessagesPage(),
        ),
        GoRoute(
          path: '/chat/:id',
          builder: (context, state) {
            final conversationId = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
            return ChatPage(conversationId: conversationId);
          },
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
      title: 'Camoins',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}