import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'driver_home_page.dart';
import 'driver_trucks_page.dart';
import 'profile_page.dart';

class DriverNavigation extends ConsumerWidget {
  const DriverNavigation({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPath = GoRouterState.of(context).uri.path;

    return Scaffold(
      body: _getPage(currentPath),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _getSelectedIndex(currentPath),
        onTap: (index) => _onTabTap(index, context),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Tableau de bord',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_shipping),
            label: 'Mes camions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
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
    } else if (path.contains('/driver-profile')) {
      return 2;
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
        GoRouter.of(context).go('/driver-profile');
        break;
    }
  }
}
