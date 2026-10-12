import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/curved_transport_bar.dart';

class DriverNavigation extends StatelessWidget {
  const DriverNavigation({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: navigationShell,
        bottomNavigationBar: CurvedTransportBar(
          selectedIndex: navigationShell.currentIndex == 1
              ? 0
              : (navigationShell.currentIndex > 1
                  ? navigationShell.currentIndex - 1
                  : 0),
          onDestinationSelected: (index) =>
              navigationShell.goBranch(index == 0 ? 0 : index + 1),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Accueil',
            ),
            NavigationDestination(
              icon: Icon(Icons.route_outlined),
              selectedIcon: Icon(Icons.route_rounded),
              label: 'Retours',
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
