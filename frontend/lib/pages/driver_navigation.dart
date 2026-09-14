import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'driver_trucks_page.dart';

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
    } else if (path.contains('/profile')) {
      return const ProfilePage();
    }
    return const DriverHomePage();
  }

  int _getSelectedIndex(String path) {
    if (path.contains('/driver-home')) {
      return 0;
    } else if (path.contains('/driver-trucks')) {
      return 1;
    } else if (path.contains('/profile')) {
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
        GoRouter.of(context).go('/profile');
        break;
    }
  }
}

class DriverHomePage extends StatelessWidget {
  const DriverHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de bord'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.dashboard, size: 64, color: Colors.blue),
            const SizedBox(height: 16),
            const Text(
              'Bienvenue sur votre tableau de bord',
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Page de profil',
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}
