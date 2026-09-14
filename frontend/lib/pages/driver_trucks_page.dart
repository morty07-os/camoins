import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/truck.dart';
import '../services/api_service.dart';

class DriverTrucksPage extends ConsumerStatefulWidget {
  const DriverTrucksPage({super.key});

  @override
  ConsumerState<DriverTrucksPage> createState() => _DriverTrucksPageState();
}

class _DriverTrucksPageState extends ConsumerState<DriverTrucksPage> {
  List<Truck> _trucks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTrucks();
  }

  Future<void> _loadTrucks() async {
    setState(() => _isLoading = true);
    try {
      final apiService = ApiService();
      final response = await apiService.getMyTrucks();
      if (response['success'] == true) {
        final trucks = (response['trucks'] as List)
            .map((truck) => Truck.fromJson(truck))
            .toList();
        if (mounted) {
          setState(() => _trucks = trucks);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response['message'] ?? 'Erreur lors du chargement des camions')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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
        content: const Text('Êtes-vous sûr de vouloir supprimer ce camion ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ANNULER'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
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
              SnackBar(content: Text(response['message'] ?? 'Erreur lors de la suppression')),
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
        title: const Text('Mes Camions'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _trucks.isEmpty
              ? _buildEmptyState()
              : _buildTrucksList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddTruck,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter un camion'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_shipping, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('Pas de camions pour le moment'),
          const SizedBox(height: 8),
          const Text('Cliquez sur "Ajouter un camion" pour commencer'),
        ],
      ),
    );
  }

  Widget _buildTrucksList() {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 88),
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

class TruckCard extends StatelessWidget {
  final Truck truck;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const TruckCard({
    super.key,
    required this.truck,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.local_shipping, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      truck.displayName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.build, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      truck.brand.isNotEmpty || truck.model.isNotEmpty
                          ? [if (truck.brand.isNotEmpty) truck.brand, if (truck.model.isNotEmpty) truck.model].join(' ')
                          : 'N/A',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.scale, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text('Poids maximal: ${truck.maxWeight.toStringAsFixed(2)} kg'),
                ],
              ),
              if (truck.maxVolume != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.volume_up, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('Volume maximal: ${truck.maxVolume!.toStringAsFixed(2)} m³'),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit),
                    label: const Text('Modifier'),
                  ),
                  TextButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete, color: Colors.red),
                    label: const Text('Supprimer', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}