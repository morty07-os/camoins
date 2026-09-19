import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'driver_home_page.dart';
import 'driver_trucks_page.dart';
import 'driver_return_trips_page.dart';
import 'driver_history_page.dart';
import 'profile_page.dart';
import 'messages_page.dart';

class DriverNavigation extends ConsumerWidget {
  const DriverNavigation({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPath = GoRouterState.of(context).uri.path;

    return Scaffold(
      body: _getPage(currentPath),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _getSelectedIndex(currentPath),
        onDestinationSelected: (index) => _onTabTap(index, context),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_shipping_outlined),
            selectedIcon: Icon(Icons.local_shipping_rounded),
            label: 'Mes camions',
          ),
          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route_rounded),
            label: 'Mes trajets retour',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded),
            label: 'Historique',
          ),
          NavigationDestination(
            icon: Icon(Icons.message_outlined),
            selectedIcon: Icon(Icons.message_rounded),
            label: 'Messages',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  Widget _getPage(String path) {
    if (path.contains('/driver-home')) {
      return const DriverHomePage();
    } else if (path.contains('/driver-trucks')) {
      return const DriverTrucksPage();
    } else if (path.contains('/driver-trips')) {
      return const DriverReturnTripsPage();
    } else if (path.contains('/driver-history')) {
      return const DriverHistoryPage();
    } else if (path.contains('/driver-messages')) {
      return const MessagesPage();
    } else if (path.contains('/driver-profile')) {
      return const ProfilePage();
    }
    return const DriverHomePage();
  }

  int _getSelectedIndex(String path) {
    if (path.contains('/driver-home')) {
      return 0;
    } else if (path.contains('/driver-trucks')) {
      return 1;
    } else if (path.contains('/driver-trips')) {
      return 2;
    } else if (path.contains('/driver-history')) {
      return 3;
    } else if (path.contains('/driver-messages')) {
      return 4;
    } else if (path.contains('/driver-profile')) {
      return 5;
    }
    return 0;
  }

  void _onTabTap(int index, BuildContext context) {
    switch (index) {
      case 0:
        GoRouter.of(context).go('/driver-home');
        break;
      case 1:
        GoRouter.of(context).go('/driver-trucks');
        break;
      case 2:
        GoRouter.of(context).go('/driver-trips');
        break;
      case 3:
        GoRouter.of(context).go('/driver-history');
        break;
      case 4:
        GoRouter.of(context).go('/driver-messages');
        break;
      case 5:
        GoRouter.of(context).go('/driver-profile');
        break;
    }
  }
}