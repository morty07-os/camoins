import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/truck.dart';
import '../services/api_service.dart';

class TruckDetailsPage extends StatefulWidget {
  final int truckId;

  const TruckDetailsPage({super.key, required this.truckId});

  @override
  State<TruckDetailsPage> createState() => _TruckDetailsPageState();
}

class _TruckDetailsPageState extends State<TruckDetailsPage> {
  Truck? _truck;
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadTruck();
  }

  Future<void> _loadTruck() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final apiService = ApiService();
      final response = await apiService.getTruck(widget.truckId);
      if (response['success'] == true) {
        setState(() {
          _truck = response['truck'] as Truck;
          _isLoading = false;
        });
      } else {
        setState(() {
          _loadError = response['message'] ?? 'Impossible de charger le camion';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _loadError = 'Erreur: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails du camion'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_truck != null)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Modifier',
              onPressed: () async {
                final updated = await context.push<bool>('/edit-truck/${_truck!.id}');
                if (updated == true) {
                  _loadTruck();
                }
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_loadError!),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _loadTruck,
                        child: const Text('RÉESSAYER'),
                      ),
                    ],
                  ),
                )
              : _buildDetails(_truck!),
    );
  }

  Widget _buildDetails(Truck truck) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.local_shipping,
            size: 80,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            truck.displayName,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          if (truck.brand.isNotEmpty || truck.model.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              [if (truck.brand.isNotEmpty) truck.brand, if (truck.model.isNotEmpty) truck.model]
                  .join(' '),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
          const SizedBox(height: 24),
          _detailTile(
            icon: Icons.scale,
            label: 'Poids maximal',
            value: '${truck.maxWeight.toStringAsFixed(2)} kg',
          ),
          if (truck.maxVolume != null)
            _detailTile(
              icon: Icons.volume_up,
              label: 'Volume maximal',
              value: '${truck.maxVolume!.toStringAsFixed(2)} m³',
            ),
          if (truck.registrationNumber.isNotEmpty)
            _detailTile(
              icon: Icons.credit_card,
              label: 'Numéro d\'immatriculation',
              value: truck.registrationNumber,
            ),
          if (truck.imageUrl != null && truck.imageUrl!.isNotEmpty) ...[
            const SizedBox(height: 24),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                truck.imageUrl!,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 200,
                  color: Colors.grey.shade200,
                  child: const Center(child: Icon(Icons.broken_image, size: 48)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(label),
        trailing: Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}