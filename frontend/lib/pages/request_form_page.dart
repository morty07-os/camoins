import 'package:flutter/material.dart';
import '../models/trip.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/location_field.dart';
import '../widgets/section_title.dart';

class RequestFormPage extends StatefulWidget {
  final int tripId;
  final Trip trip;

  const RequestFormPage({
    super.key,
    required this.tripId,
    required this.trip,
  });

  @override
  State<RequestFormPage> createState() => _RequestFormPageState();
}

class _RequestFormPageState extends State<RequestFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  final _volumeController = TextEditingController();
  final _cargoDescriptionController = TextEditingController();
  final _pickupLocationController = TextEditingController();
  final _deliveryLocationController = TextEditingController();

  final _pickupFieldKey = GlobalKey<LocationFieldState>();
  final _deliveryFieldKey = GlobalKey<LocationFieldState>();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _weightController.dispose();
    _volumeController.dispose();
    _cargoDescriptionController.dispose();
    _pickupLocationController.dispose();
    _deliveryLocationController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final pickupState = _pickupFieldKey.currentState;
    final deliveryState = _deliveryFieldKey.currentState;

    if (pickupState != null && !pickupState.coordinatesValid) {
      return;
    }
    if (deliveryState != null && !deliveryState.coordinatesValid) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final weight = double.parse(_weightController.text.trim());
      final volume = _volumeController.text.trim().isNotEmpty
          ? double.parse(_volumeController.text.trim())
          : null;

      final apiService = ApiService();
      final response = await apiService.createRequest(
        tripId: widget.tripId,
        requestedWeight: weight,
        requestedVolume: volume,
        cargoDescription: _cargoDescriptionController.text.trim().isEmpty
            ? null
            : _cargoDescriptionController.text.trim(),
        pickupLocation: _pickupLocationController.text.trim(),
        deliveryLocation: _deliveryLocationController.text.trim(),
      );

      if (mounted) {
        if (response['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Demande envoyée avec succès')),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                response['message'] ?? 'Erreur lors de l\'envoi de la demande',
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
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Demander ce transport'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionTitle(
                title: 'Trajet',
                subtitle: 'Détails du transport',
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.trip.originName} → ${widget.trip.destinationName}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded,
                              size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            Trip.formatFrenchDate(widget.trip.departureDate),
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.scale_rounded,
                              size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            '${widget.trip.availableWeight.toStringAsFixed(0)} kg disponibles',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const SectionTitle(
                title: 'Capacité requise',
                subtitle: 'Combien avez-vous besoin de transporter ?',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _weightController,
                decoration: const InputDecoration(
                  labelText: 'Poids requis *',
                  hintText: 'en kilogrammes (kg)',
                  prefixIcon: Icon(Icons.scale_rounded),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Le poids requis est obligatoire';
                  }
                  final parsed = double.tryParse(value.trim());
                  if (parsed == null || parsed <= 0) {
                    return 'Le poids doit être un nombre positif';
                  }
                  if (parsed > widget.trip.availableWeight) {
                    return 'Le poids requis dépasse la capacité disponible';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _volumeController,
                decoration: const InputDecoration(
                  labelText: 'Volume requis (optionnel)',
                  hintText: 'en mètres cubes (m³)',
                  prefixIcon: Icon(Icons.view_in_ar_rounded),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return null;
                  final parsed = double.tryParse(value.trim());
                  if (parsed == null || parsed <= 0) {
                    return 'Le volume doit être un nombre positif';
                  }
                  if (widget.trip.availableVolume != null &&
                      parsed > widget.trip.availableVolume!) {
                    return 'Le volume requis dépasse la capacité disponible';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              const SectionTitle(
                title: 'Localisation',
                subtitle: 'Où cherchez-vous à charger et décharger ?',
              ),
              const SizedBox(height: 12),
              LocationField(
                key: _pickupFieldKey,
                label: 'Lieu de chargement *',
                hint: 'Ex : Alger',
                icon: Icons.trip_origin_rounded,
                controller: _pickupLocationController,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.south_rounded,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                  ),
                ),
              ),
              LocationField(
                key: _deliveryFieldKey,
                label: 'Lieu de déchargement *',
                hint: 'Ex : Sétif',
                icon: Icons.location_on_outlined,
                controller: _deliveryLocationController,
              ),
              const SizedBox(height: 24),
              const SectionTitle(
                title: 'Description de la marchandise',
                subtitle: 'Précisions utiles (optionnel)',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cargoDescriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Ex : Marchandises fragiles, nécessite un camion frigorifique…',
                ),
              ),
              const SizedBox(height: 24),
              const SectionTitle(
                title: 'Prix',
                subtitle: 'À négocier avec le transporteur',
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Prix à convenir',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Vous discuterez du prix avec le transporteur après qu\'il ait accepté votre demande.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isSubmitting ? null : () => Navigator.pop(context, false),
                child: const Text('ANNULER'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: FilledButton(
                onPressed: _isSubmitting ? null : _submitRequest,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('ENVOYER LA DEMANDE'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
