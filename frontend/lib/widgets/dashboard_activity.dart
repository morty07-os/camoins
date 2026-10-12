import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/transport_request.dart';
import '../models/trip.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/transport_updates_provider.dart';

final dashboardRequestsProvider =
    FutureProvider.autoDispose<List<TransportRequest>>((ref) async {
  ref.watch(authProvider.select((s) => s.currentUser?.id));
  ref.watch(transportUpdatesProvider);
  final result = await ref.watch(apiServiceProvider).getMyRequests();
  if (result['success'] != true) throw Exception('Chargement impossible');
  return (result['requests'] as List).cast<TransportRequest>();
});

final dashboardTripsProvider =
    FutureProvider.autoDispose<List<Trip>>((ref) async {
  ref.watch(authProvider.select((s) => s.currentUser?.id));
  ref.watch(transportUpdatesProvider);
  final result = await ref.watch(apiServiceProvider).getMyTrips();
  if (result['success'] != true) throw Exception('Chargement impossible');
  return (result['trips'] as List).cast<Trip>();
});

class DashboardActivity extends ConsumerStatefulWidget {
  const DashboardActivity({super.key, required this.driver});
  final bool driver;

  @override
  ConsumerState<DashboardActivity> createState() => _DashboardActivityState();
}

class _DashboardActivityState extends ConsumerState<DashboardActivity> {
  bool? _active;
  bool get driver => widget.driver;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = TickerMode.valuesOf(context).enabled;
    if (_active == false && active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.invalidate(dashboardRequestsProvider);
        if (driver) ref.invalidate(dashboardTripsProvider);
      });
    }
    _active = active;
  }

  @override
  Widget build(BuildContext context) {
    final requests = ref.watch(dashboardRequestsProvider);
    final trips = driver ? ref.watch(dashboardTripsProvider) : null;
    void refresh() {
      ref.invalidate(dashboardRequestsProvider);
      if (driver) ref.invalidate(dashboardTripsProvider);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
            child: Text('Votre activité',
                style: Theme.of(context).textTheme.titleLarge)),
        IconButton(
            onPressed: refresh,
            tooltip: 'Actualiser l’activité',
            icon: const Icon(Icons.refresh)),
      ]),
      Card(
          child: requests.when(
        loading: () => const Padding(
            padding: EdgeInsets.all(20),
            child: Text('Chargement de votre activité…')),
        error: (_, __) => ListTile(
            title: const Text('Activité indisponible'),
            subtitle: const Text('Vérifiez votre connexion.'),
            trailing:
                TextButton(onPressed: refresh, child: const Text('Réessayer'))),
        data: (items) {
          final pending = items.where((r) => r.isPending).length;
          final active = items
              .where((r) =>
                  r.isAccepted || r.status == 'AWAITING_CUSTOMER_CONFIRMATION')
              .length;
          return Column(children: [
            if (items.any((r) => r.isPriceProposed))
              ListTile(
                  leading: const Icon(Icons.payments_outlined),
                  title: Text(
                      '${items.where((r) => r.isPriceProposed).length} prix à confirmer'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context
                      .go(driver ? '/driver-messages' : '/customer-messages')),
            ListTile(
                leading: const Icon(Icons.inbox_outlined),
                title: Text('$pending demandes en attente'),
                subtitle: Text(driver
                    ? 'Demandes de transport à traiter'
                    : 'En attente de réponse ou de confirmation'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context
                    .go(driver ? '/driver-requests' : '/customer-messages')),
            const Divider(height: 1),
            ListTile(
                leading: const Icon(Icons.local_shipping_outlined),
                title: Text('$active transports actifs'),
                subtitle: Text(active == 0
                    ? 'Aucun transport actif pour le moment'
                    : 'Acceptés ou en attente de confirmation de livraison'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context
                    .go(driver ? '/driver-messages' : '/customer-messages')),
          ]);
        },
      )),
      if (trips != null) ...[
        const SizedBox(height: 12),
        Card(
            child: trips.when(
          loading: () => const ListTile(title: Text('Chargement des départs…')),
          error: (_, __) => ListTile(
              title: const Text('Départs indisponibles'),
              trailing: TextButton(
                  onPressed: refresh, child: const Text('Réessayer'))),
          data: (items) {
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final upcoming = items.where((t) {
              final date = DateTime.tryParse(t.departureDate);
              return t.isPublished && date != null && !date.isBefore(today);
            }).toList()
              ..sort((a, b) => a.departureDate.compareTo(b.departureDate));
            final next = upcoming.firstOrNull;
            return ListTile(
                leading: const Icon(Icons.route_outlined),
                title: Text(next == null
                    ? 'Aucun départ à venir'
                    : 'Prochain départ · ${next.departureDate}'),
                subtitle: Text(next?.routeLabel ??
                    'Publiez un trajet pour trouver des clients.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => next == null
                    ? context.go('/driver-trips')
                    : context.push('/driver-return-trip-details/${next.id}'));
          },
        )),
      ],
    ]);
  }
}
