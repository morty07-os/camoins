import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/truck.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/states.dart';
import '../widgets/truck_card.dart';

class DriverTrucksPage extends ConsumerStatefulWidget {
  const DriverTrucksPage({super.key});

  @override
  ConsumerState<DriverTrucksPage> createState() => _DriverTrucksPageState();
}

class _DriverTrucksPageState extends ConsumerState<DriverTrucksPage> {
  List<Truck> _trucks = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTrucks();
  }

  Future<void> _loadTrucks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final apiService = ApiService();
      final response = await apiService.getMyTrucks();
      if (response['success'] == true) {
        final trucks = (response['trucks'] as List).cast<Truck>();
        if (mounted) {
          setState(() {
            _trucks = trucks;
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

  Future<void> _openAddTruck() async {
    final added = await context.push<bool>('/add-truck');
    if (added == true) {
      _loadTrucks();
    }
  }

  Future<void> _openEditTruck(Truck truck) async {
    final updated = await context.push<bool>('/edit-truck/${truck.id}');
    if (updated == true) {
      _loadTrucks();
    }
  }

  Future<void> _openTruckDetails(Truck truck) async {
    await context.push('/driver-truck-details/${truck.id}');
  }

  Future<void> _deleteTruck(int truckId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le camion'),
        content: const Text(
          'Êtes-vous sûr de vouloir supprimer ce camion ? '
          'Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ANNULER'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('SUPPRIMER'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final apiService = ApiService();
        final response = await apiService.deleteTruck(truckId);
        if (response['success'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Camion supprimé avec succès')),
            );
          }
          _loadTrucks();
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  response['message'] ?? 'Erreur lors de la suppression',
                ),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes camions'),
      ),
      body: _isLoading
          ? const LoadingState(message: 'Chargement de vos camions…')
          : _error != null
              ? ErrorState(message: _error!, onRetry: _loadTrucks)
              : _trucks.isEmpty
                  ? EmptyState(
                      icon: Icons.local_shipping_rounded,
                      title: 'Aucun camion',
                      message:
                          'Commencez par enregistrer votre premier camion '
                          'pour proposer des trajets.',
                      action: FilledButton.icon(
                        onPressed: _openAddTruck,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Ajouter mon premier camion'),
                      ),
                    )
                  : _buildTrucksList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddTruck,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Ajouter un camion'),
      ),
    );
  }

  Widget _buildTrucksList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 96),
      itemCount: _trucks.length,
      itemBuilder: (context, index) {
        final truck = _trucks[index];
        return TruckCard(
          truck: truck,
          onTap: () => _openTruckDetails(truck),
          onEdit: () => _openEditTruck(truck),
          onDelete: () => _deleteTruck(truck.id),
        );
      },
    );
  }
}