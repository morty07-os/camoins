import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../services/auth_actions.dart';
import '../theme/app_theme.dart';
import '../widgets/dashboard_activity.dart';
import '../widgets/notification_icon.dart';

class DriverHomePage extends ConsumerWidget {
  const DriverHomePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(authProvider).currentUser?.profile.fullName.trim();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de bord'),
        actions: [
          const NotificationIcon(),
          IconButton(
            tooltip: 'Déconnexion',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => logoutAndNotify(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardRequestsProvider);
          ref.invalidate(dashboardTripsProvider);
          try {
            await Future.wait([
              ref.read(dashboardRequestsProvider.future),
              ref.read(dashboardTripsProvider.future),
            ]);
          } catch (_) {
            // Each activity card displays its own loading error.
          }
        },
        child: SingleChildScrollView(
          key: const PageStorageKey('driver-dashboard'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          child: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                            name == null || name.isEmpty
                                ? 'Bonjour'
                                : 'Bonjour, $name',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                            style: FilledButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                foregroundColor: AppColors.primaryDark),
                            onPressed: () async {
                              await context.push('/publish-return-trip');
                              if (context.mounted) {
                                ref.invalidate(dashboardTripsProvider);
                              }
                            },
                            icon: const Icon(Icons.add_road_rounded),
                            label: const Text('Proposer un trajet')),
                        const SizedBox(height: 20),
                        const DashboardActivity(driver: true),
                        const SizedBox(height: 24),
                        Text('Accès rapide',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 12),
                        Card(
                            child: Column(children: [
                          ListTile(
                              leading:
                                  const Icon(Icons.local_shipping_outlined),
                              title: const Text('Gérer mes camions'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => context.go('/driver-trucks')),
                          ListTile(
                              leading: const Icon(Icons.inbox_outlined),
                              title: const Text('Mes demandes'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => context.go('/driver-requests')),
                          ListTile(
                              leading: const Icon(Icons.history),
                              title: const Text('Historique des transports'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => context.go('/driver-history')),
                          ListTile(
                              leading: const Icon(Icons.message_outlined),
                              title: const Text('Mes conversations'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => context.go('/driver-messages')),
                        ])),
                      ]))),
        ),
      ),
    );
  }
}
