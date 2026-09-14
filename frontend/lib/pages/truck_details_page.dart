import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/truck.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/info_row.dart';
import '../widgets/section_title.dart';
import '../widgets/states.dart';

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
        _loadError = 'Vérifiez votre connexion et réessayez.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails du camion'),
        actions: [
          if (_truck != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Modifier',
              onPressed: () async {
                final updated =
                    await context.push<bool>('/edit-truck/${_truck!.id}');
                if (updated == true) {
                  _loadTruck();
                }
              },
            ),
        ],
      ),
      body: _isLoading
          ? const LoadingState(message: 'Chargement du camion…')
          : _loadError != null
              ? ErrorState(message: _loadError!, onRetry: _loadTruck)
              : _buildDetails(_truck!),
    );
  }

  Widget _buildDetails(Truck truck) {
    final brandModel = [
      if (truck.brand.isNotEmpty) truck.brand,
      if (truck.model.isNotEmpty) truck.model,
    ].join(' ');
    final hasImage = truck.imageUrl != null && truck.imageUrl!.trim().isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.secondary],
              ),
              borderRadius: BorderRadius.circular(AppTheme.radius),
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.local_shipping_rounded,
                    size: 34,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  truck.displayName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                if (brandModel.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    brandModel,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionTitle(title: 'Caractéristiques'),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                InfoRow(
                  icon: Icons.scale_rounded,
                  label: 'Poids maximal',
                  value: '${truck.maxWeight.toStringAsFixed(2)} kg',
                ),
                if (truck.maxVolume != null) ...[
                  const Divider(),
                  InfoRow(
                    icon: Icons.view_in_ar_rounded,
                    label: 'Volume maximal',
                    value: '${truck.maxVolume!.toStringAsFixed(2)} m³',
                  ),
                ],
                if (truck.registrationNumber.isNotEmpty) ...[
                  const Divider(),
                  InfoRow(
                    icon: Icons.confirmation_number_outlined,
                    label: 'Numéro d\'immatriculation',
                    value: truck.registrationNumber,
                  ),
                ],
              ],
            ),
          ),
          if (hasImage) ...[
            const SizedBox(height: 24),
            const SectionTitle(title: 'Photo du camion'),
            const SizedBox(height: 12),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Image.network(
                truck.imageUrl!,
                height: 220,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 220,
                  color: AppColors.primarySoft,
                  alignment: Alignment.center,
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.broken_image_outlined,
                        size: 48,
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Image indisponible',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () async {
              final updated =
                  await context.push<bool>('/edit-truck/${truck.id}');
              if (updated == true) {
                _loadTruck();
              }
            },
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Modifier ce camion'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Retour à la liste'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}