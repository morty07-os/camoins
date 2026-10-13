import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../services/auth_actions.dart';
import '../theme/app_theme.dart';
import '../widgets/dashboard_activity.dart';
import '../widgets/notification_icon.dart';

class CustomerHomePage extends ConsumerWidget {
  const CustomerHomePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(authProvider).currentUser?.profile.fullName.trim();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accueil'),
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
          try {
            await Future.wait([
              ref.read(dashboardRequestsProvider.future),
            ]);
          } catch (_) {
            // Each activity card displays its own loading error.
          }
        },
        child: SingleChildScrollView(
          key: const PageStorageKey('customer-dashboard'),
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
                        const Text(
                            'Trouvez un camion adapté à votre livraison.'),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                            style: FilledButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                foregroundColor: AppColors.primaryDark),
                            onPressed: () async {
                              context.go('/customer-trips');
                            },
                            icon: const Icon(Icons.search_rounded),
                            label: const Text('Rechercher un trajet')),
                        const SizedBox(height: 20),
                        const DashboardActivity(driver: false),
                        const SizedBox(height: 24),
                        Text('Accès rapide',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 12),
                        Card(
                            child: Column(children: [
                          ListTile(
                              leading: const Icon(Icons.history),
                              title: const Text('Historique des transports'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => context.go('/customer-history')),
                          ListTile(
                              leading: const Icon(Icons.message_outlined),
                              title: const Text('Mes conversations'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => context.go('/customer-messages')),
                        ])),
                      ]))),
        ),
      ),
    );
  }
}
