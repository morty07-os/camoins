import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../pages/driver_navigation.dart';
import '../pages/driver_trucks_page.dart';

class TruckDetailsPage extends StatelessWidget {
  final int? truckId;
  const TruckDetailsPage({super.key, this.truckId});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Truck Details')),
    body: Center(child: Text('Truck ID: $truckId')),
  );
}

class AddTruckPage extends StatelessWidget {
  const AddTruckPage({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
    appBar: null,
    body: Center(child: Text('Add Truck')),
  );
}

class EditTruckPage extends StatelessWidget {
  final int? truckId;
  const EditTruckPage({super.key, this.truckId});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Edit Truck')),
    body: Center(child: Text('Edit Truck ID: $truckId')),
  );
}

// Main navigation routes
final _appRouter = GoRouter(
  routes: [
    // Public routes
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterPage(),
    ),

    // Driver routes (protected)
    GoRoute(
      path: '/driver-home',
      builder: (context, state) => const DriverNavigation(),
    ),
    GoRoute(
      path: '/driver-trucks',
      builder: (context, state) => const DriverTrucksPage(),
    ),
    GoRoute(
      path: '/driver-truck-details/:id',
      builder: (context, state) {
        final truckId = int.tryParse(state.pathParameters['id'] ?? '');
        return TruckDetailsPage(truckId: truckId);
      },
    ),
    GoRoute(
      path: '/add-truck',
      builder: (context, state) => const AddTruckPage(),
    ),
    GoRoute(
      path: '/edit-truck/:id',
      builder: (context, state) {
        final truckId = int.tryParse(state.pathParameters['id'] ?? '');
        return EditTruckPage(truckId: truckId);
      },
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfilePage(),
    ),

    // Customer routes (protected)
    GoRoute(
      path: '/customer-home',
      builder: (context, state) => const CustomerHomePage(),
    ),

    // Default route
    GoRoute(
      path: '/',
      redirect: (context, state) => '/login',
    ),
  ],
);

// Navigation widgets (stubs for router compilation)
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.local_shipping, size: 64, color: Colors.blue),
      const SizedBox(height: 16),
      const Text('Login Page'),
    ])),
  );
}

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.person_add, size: 64, color: Colors.grey),
      const SizedBox(height: 16),
      const Text('Register Page'),
    ])),
  );
}

class CustomerHomePage extends StatelessWidget {
  const CustomerHomePage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Customer Home'), backgroundColor: Theme.of(context).colorScheme.inversePrimary),
    body: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.shopping_cart, size: 64, color: Colors.green),
      SizedBox(height: 16),
      Text('Customer Home Page'),
    ])),
  );
}

// Export the router
final routerProvider = Provider<GoRouter>((ref) => _appRouter);
