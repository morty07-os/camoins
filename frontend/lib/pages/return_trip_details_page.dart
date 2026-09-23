import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/trip.dart';
import '../models/truck.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/info_row.dart';
import '../widgets/section_title.dart';
import '../widgets/status_badge.dart';
import '../widgets/states.dart';

class ReturnTripDetailsPage extends StatefulWidget {
  final int tripId;

  const ReturnTripDetailsPage({super.key, required this.tripId});

  @override
  State<ReturnTripDetailsPage> createState() => _ReturnTripDetailsPageState();
}

class _ReturnTripDetailsPageState extends State<ReturnTripDetailsPage> {
  Trip? _trip;
  Truck? _truck;
  bool _isLoading = true;
  bool _isActing = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadTrip();
  }

  Future<void> _loadTrip() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final apiService = ApiService();
      final response = await apiService.getTrip(widget.tripId);
      if (response['success'] == true) {
        final trip = response['trip'] as Trip;
        Truck? truck;
        final truckResponse = await apiService.getTruck(trip.truckId);
        if (truckResponse['success'] == true) {
          truck = truckResponse['truck'] as Truck;
        }
        if (mounted) {
          setState(() {
            _trip = trip;
            _truck = truck;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _loadError =
                response['message'] ?? 'Impossible de charger le trajet';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = 'Vérifiez votre connexion et réessayez.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _confirmAction({
    required String title,
    required String message,
    required String confirmLabel,
    required Future<Map<String, dynamic>> Function() action,
    required String successMessage,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ANNULER'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.accent),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _isActing = true);

    try {
      final response = await action();
      if (mounted) {
        if (response['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(successMessage)),
          );
          setState(() {
            _trip = response['trip'] as Trip;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Action impossible'),
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
    } finally {
      if (mounted) {
        setState(() => _isActing = false);
      }
    }
  }

  Future<void> _deleteTrip() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le trajet'),
        content: const Text(
          'Êtes-vous sûr de vouloir supprimer ce trajet retour ? '
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

    if (confirmed != true) {
      return;
    }

    setState(() => _isActing = true);

    try {
      final apiService = ApiService();
      final response = await apiService.deleteTrip(widget.tripId);
      if (mounted) {
        if (response['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Trajet retour supprimé')),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Erreur lors de la suppression'),
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
    } finally {
      if (mounted) {
        setState(() => _isActing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails du trajet'),
        actions: [
          if (_trip != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Modifier',
              onPressed: _isActing
                  ? null
                  : () async {
                      final updated = await context.push<bool>(
                        '/edit-return-trip/${_trip!.id}',
                      );
                      if (updated == true) {
                        _loadTrip();
                      }
                    },
            ),
          if (_trip != null)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Supprimer',
              onPressed: _isActing ? null : _deleteTrip,
            ),
        ],
      ),
      body: _isLoading
          ? const LoadingState(message: 'Chargement du trajet…')
          : _loadError != null
              ? ErrorState(message: _loadError!, onRetry: _loadTrip)
              : _buildDetails(_trip!),
    );
  }

  Widget _buildDetails(Trip trip) {
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
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            trip.originName,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Départ',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            trip.destinationName,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Destination',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                StatusBadge(status: trip.status),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionTitle(
            title: 'Informations du trajet',
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                InfoRow(
                  icon: Icons.calendar_today_rounded,
                  label: 'Date de départ',
                  value: Trip.formatFrenchDate(trip.departureDate),
                ),
                const Divider(),
                InfoRow(
                  icon: Icons.scale_rounded,
                  label: 'Capacité disponible',
                  value: '${_formatNumber(trip.availableWeight)} kg',
                ),
                if (trip.availableVolume != null) ...[
                  const Divider(),
                  InfoRow(
                    icon: Icons.view_in_ar_rounded,
                    label: 'Volume disponible',
                    value: '${_formatNumber(trip.availableVolume!)} m³',
                  ),
                ],
                if (trip.description.trim().isNotEmpty) ...[
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Description',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          trip.description,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.text,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_truck != null) ...[
            const SizedBox(height: 24),
            const SectionTitle(
              title: 'Camion utilisé',
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.local_shipping_rounded,
                    color: AppColors.secondary,
                    size: 24,
                  ),
                ),
                title: Text(_truck!.displayName),
                subtitle: Text(
                  '${_truck!.maxWeight.toStringAsFixed(0)} kg max',
                ),
              ),
            ),
          ],
          if (_trip!.isPublished ||
              _trip!.isInProgress ||
              _trip!.isCancelled ||
              _trip!.isCompleted) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    if (_trip!.isCompleted)
                      _ActionButton(
                        icon: Icons.star_outline_rounded,
                        label: 'Évaluer le transport',
                        onPressed: () => context.push('/driver-history'),
                      ),
                    if (_trip!.isPublished)
                      _ActionButton(
                        icon: Icons.play_arrow_rounded,
                        label: 'Démarrer',
                        onPressed: _isActing
                            ? null
                            : () => _confirmAction(
                                  title: 'Démarrer le trajet',
                                  message:
                                      'Confirmer le démarrage de ce trajet retour ?',
                                  confirmLabel: 'DÉMARRER',
                                  action: () async {
                                    final apiService = ApiService();
                                    return apiService.startTrip(_trip!.id);
                                  },
                                  successMessage: 'Trajet démarré',
                                ),
                      ),
                    if (_trip!.isInProgress)
                      _ActionButton(
                        icon: Icons.check_circle_outline_rounded,
                        label: 'Terminer',
                        onPressed: _isActing
                            ? null
                            : () => _confirmAction(
                                  title: 'Terminer le trajet',
                                  message:
                                      'Confirmer la fin de ce trajet retour ?',
                                  confirmLabel: 'TERMINER',
                                  action: () async {
                                    final apiService = ApiService();
                                    return apiService.completeTrip(_trip!.id);
                                  },
                                  successMessage: 'Trajet terminé',
                                ),
                      ),
                    if (_trip!.isPublished || _trip!.isInProgress)
                      _ActionButton(
                        icon: Icons.cancel_outlined,
                        label: 'Annuler',
                        onPressed: _isActing
                            ? null
                            : () => _confirmAction(
                                  title: 'Annuler le trajet',
                                  message:
                                      'Confirmer l\'annulation de ce trajet retour ?',
                                  confirmLabel: 'ANNULER',
                                  action: () async {
                                    final apiService = ApiService();
                                    return apiService.cancelTrip(_trip!.id);
                                  },
                                  successMessage: 'Trajet annulé',
                                ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 18),
          label: Text(label, style: const TextStyle(fontSize: 13)),
        ),
      ),
    );
  }
}