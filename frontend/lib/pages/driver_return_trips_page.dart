import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/trip.dart';
import '../services/api_service.dart';
import '../widgets/notification_icon.dart';
import '../widgets/states.dart';
import '../widgets/trip_card.dart';

class DriverReturnTripsPage extends ConsumerStatefulWidget {
  const DriverReturnTripsPage({super.key});

  @override
  ConsumerState<DriverReturnTripsPage> createState() =>
      _DriverReturnTripsPageState();
}

class _DriverReturnTripsPageState extends ConsumerState<DriverReturnTripsPage> {
  List<Trip> _trips = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final apiService = ApiService();
      final response = await apiService.getMyTrips();
      if (response['success'] == true) {
        final trips = (response['trips'] as List).cast<Trip>();
        if (mounted) {
          setState(() {
            _trips = trips;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = response['message'] ?? 'Une erreur est survenue';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Vérifiez votre connexion et réessayez.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openPublish() async {
    final published = await context.push<bool>('/publish-return-trip');
    if (published == true) {
      _loadTrips();
    }
  }

  Future<void> _openDetails(Trip trip) async {
    await context.push('/driver-return-trip-details/${trip.id}');
  }

  Future<void> _openEdit(Trip trip) async {
    final updated = await context.push<bool>('/edit-return-trip/${trip.id}');
    if (updated == true) {
      _loadTrips();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes trajets retour'),
        actions: [
          const NotificationIcon(),
        ],
      ),
      body: _isLoading
          ? const LoadingState(message: 'Chargement de vos trajets…')
          : _error != null
              ? ErrorState(message: _error!, onRetry: _loadTrips)
              : _trips.isEmpty
                  ? EmptyState(
                      icon: Icons.route_rounded,
                      title: 'Aucun trajet retour',
                      message:
                          'Publiez votre retour pour proposer la capacité '
                          'disponible de votre camion à des clients.',
                      action: FilledButton.icon(
                        onPressed: _openPublish,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Publier un trajet retour'),
                      ),
                    )
                  : _buildTripsList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openPublish,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Publier le trajet'),
      ),
    );
  }

  Widget _buildTripsList() {
    return RefreshIndicator(
      onRefresh: _loadTrips,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 96),
        itemCount: _trips.length,
        itemBuilder: (context, index) {
          final trip = _trips[index];
          return TripCard(
            trip: trip,
            onTap: () => _openDetails(trip),
            onEdit: () => _openEdit(trip),
          );
        },
      ),
    );
  }
}