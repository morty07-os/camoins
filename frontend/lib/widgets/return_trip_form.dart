import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/trip.dart';
import '../models/truck.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'location_field.dart';
import 'section_title.dart';

class ReturnTripFormData {
  final int truckId;
  final String originName;
  final double? originLat;
  final double? originLng;
  final String destinationName;
  final double? destinationLat;
  final double? destinationLng;
  final String departureDate; // YYYY-MM-DD
  final double availableWeight;
  final double? availableVolume;
  final String description;

  ReturnTripFormData({
    required this.truckId,
    required this.originName,
    this.originLat,
    this.originLng,
    required this.destinationName,
    this.destinationLat,
    this.destinationLng,
    required this.departureDate,
    required this.availableWeight,
    this.availableVolume,
    this.description = '',
  });
}

/// Shared form used by the publish & edit return trip pages.
class ReturnTripForm extends StatefulWidget {
  final Trip? initialTrip;

  const ReturnTripForm({super.key, this.initialTrip});

  @override
  State<ReturnTripForm> createState() => ReturnTripFormState();
}

class ReturnTripFormState extends State<ReturnTripForm> {
  final _formKey = GlobalKey<FormState>();
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  final _weightController = TextEditingController();
  final _volumeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _dateController = TextEditingController();

  final _originFieldKey = GlobalKey<LocationFieldState>();
  final _destinationFieldKey = GlobalKey<LocationFieldState>();

  List<Truck> _trucks = [];
  bool _isLoadingTrucks = true;
  bool _hasTruckLoadError = false;
  int? _selectedTruckId;

  DateTime? _selectedDate;
  String? _dateError;

  @override
  void initState() {
    super.initState();
    final trip = widget.initialTrip;
    if (trip != null) {
      _originController.text = trip.originName;
      _destinationController.text = trip.destinationName;
      _weightController.text = _formatKg(trip.availableWeight);
      if (trip.availableVolume != null) {
        _volumeController.text = _formatVolume(trip.availableVolume!);
      }
      _descriptionController.text = trip.description;
      _selectedDate = _parseIsoDate(trip.departureDate);
      _dateController.text = Trip.formatFrenchDate(trip.departureDate);
      _selectedTruckId = trip.truckId;
    }
    _loadTrucks();
  }

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    _weightController.dispose();
    _volumeController.dispose();
    _descriptionController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  static String _formatKg(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }

  static String _formatVolume(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }

  static DateTime? _parseIsoDate(String isoDate) {
    final parts = isoDate.split('-');
    if (parts.length != 3) {
      return null;
    }
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) {
      return null;
    }
    return DateTime(year, month, day);
  }

  Future<void> _loadTrucks() async {
    setState(() {
      _isLoadingTrucks = true;
      _hasTruckLoadError = false;
    });
    try {
      final apiService = ApiService();
      final response = await apiService.getMyTrucks();
      if (response['success'] == true) {
        final trucks = (response['trucks'] as List).cast<Truck>();
        if (mounted) {
          setState(() {
            _trucks = trucks;
            _isLoadingTrucks = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingTrucks = false;
            _hasTruckLoadError = true;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingTrucks = false;
          _hasTruckLoadError = true;
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = DateTime(now.year, now.month, now.day);
    final selected =
        _selectedDate != null && !_selectedDate!.isBefore(initial)
            ? _selectedDate!
            : initial;
    final picked = await showDatePicker(
      context: context,
      initialDate: selected,
      firstDate: now,
      lastDate: DateTime(now.year + 3),
      helpText: 'Date de départ',
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = _dateToIso(picked);
        _dateError = null;
      });
    }
  }

  static String _dateToIso(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  /// Returns null when validation passed, or an error message to show.
  ReturnTripFormData? collect() {
    if (_selectedTruckId == null || !canSubmit) {
      return null;
    }

    if (_selectedDate == null) {
      setState(() => _dateError = 'La date de départ est requise');
      return null;
    }

    final originState = _originFieldKey.currentState;
    final destinationState = _destinationFieldKey.currentState;

    if (originState != null && !originState.coordinatesValid) {
      return null;
    }
    if (destinationState != null && !destinationState.coordinatesValid) {
      return null;
    }

    if (!_formKey.currentState!.validate()) {
      return null;
    }

    return ReturnTripFormData(
      truckId: _selectedTruckId!,
      originName: _originController.text.trim(),
      originLat: originState?.coordinatesVisible == true
          ? originState!.latitude
          : null,
      originLng: originState?.coordinatesVisible == true
          ? originState!.longitude
          : null,
      destinationName: _destinationController.text.trim(),
      destinationLat: destinationState?.coordinatesVisible == true
          ? destinationState!.latitude
          : null,
      destinationLng: destinationState?.coordinatesVisible == true
          ? destinationState!.longitude
          : null,
      departureDate: _dateToIso(_selectedDate!),
      availableWeight: double.parse(_weightController.text.trim()),
      availableVolume: _volumeController.text.trim().isNotEmpty
          ? double.parse(_volumeController.text.trim())
          : null,
      description: _descriptionController.text.trim(),
    );
  }

  bool get canSubmit =>
      !_isLoadingTrucks && _trucks.isNotEmpty && !_hasTruckLoadError;

  @override
  Widget build(BuildContext context) {
    final hasTrucks = !_isLoadingTrucks && _trucks.isNotEmpty;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle(
            title: 'Itinéraire',
            subtitle: 'Le retour que vous effectuez à vide',
          ),
          const SizedBox(height: 12),
          LocationField(
            key: _originFieldKey,
            label: 'Départ *',
            hint: 'Ex : Alger',
            icon: Icons.trip_origin_rounded,
            controller: _originController,
            initialLat: widget.initialTrip?.originLat,
            initialLng: widget.initialTrip?.originLng,
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
            key: _destinationFieldKey,
            label: 'Destination *',
            hint: 'Ex : Sétif',
            icon: Icons.location_on_outlined,
            controller: _destinationController,
            initialLat: widget.initialTrip?.destinationLat,
            initialLng: widget.initialTrip?.destinationLng,
          ),
          const SizedBox(height: 24),
          const SectionTitle(
            title: 'Date de départ',
            subtitle: 'Quand comptez-vous effectuer ce retour ?',
          ),
          const SizedBox(height: 12),
          TextFormField(
            readOnly: true,
            onTap: _pickDate,
            controller: _dateController,
            decoration: InputDecoration(
              labelText: 'Date *',
              hintText: 'Choisir une date',
              prefixIcon: const Icon(Icons.calendar_today_rounded),
              suffixIcon: const Icon(Icons.expand_more_rounded),
              errorText: _dateError,
            ),
          ),
          const SizedBox(height: 24),
          const SectionTitle(
            title: 'Capacité disponible',
            subtitle: 'La place que vous proposez sur ce trajet',
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _weightController,
            decoration: const InputDecoration(
              labelText: 'Poids disponible *',
              hintText: 'en kilogrammes (kg)',
              prefixIcon: Icon(Icons.scale_rounded),
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Le poids disponible est requis';
              }
              final parsed = double.tryParse(value.trim());
              if (parsed == null || parsed <= 0) {
                return 'Le poids doit être un nombre positif';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _volumeController,
            decoration: const InputDecoration(
              labelText: 'Volume disponible (optionnel)',
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
              return null;
            },
          ),
          const SizedBox(height: 24),
          const SectionTitle(
            title: 'Camion',
            subtitle: 'Le véhicule utilisé pour ce trajet',
          ),
          const SizedBox(height: 12),
          if (_isLoadingTrucks)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            )
          else if (_hasTruckLoadError)
            ErrorStateCta(
              onRetry: _loadTrucks,
            )
          else if (!hasTrucks)
            Card(
              margin: EdgeInsets.zero,
              color: AppColors.accentSoft,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(
                      Icons.local_shipping_rounded,
                      color: AppColors.accent,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Aucun camion enregistré',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Ajoutez un camion pour pouvoir publier ce trajet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        context.push('/add-truck');
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Ajouter un camion'),
                    ),
                  ],
                ),
              ),
            )
          else
            DropdownButtonFormField<int>(
              initialValue: _selectedTruckId,
              decoration: const InputDecoration(
                labelText: 'Camion *',
                prefixIcon: Icon(Icons.local_shipping_outlined),
              ),
              items: _trucks
                  .map((truck) => DropdownMenuItem<int>(
                        value: truck.id,
                        child: Text(truck.displayName),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() => _selectedTruckId = value);
              },
            ),
          const SizedBox(height: 24),
          const SectionTitle(
            title: 'Description',
            subtitle: 'Précisions utiles pour vos clients (optionnel)',
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Ex : Retour à vide vers Sétif, chargement rapide…',
            ),
          ),
        ],
      ),
    );
  }
}

class ErrorStateCta extends StatelessWidget {
  final VoidCallback onRetry;

  const ErrorStateCta({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: AppColors.errorSoft,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppColors.error, size: 28),
            const SizedBox(height: 8),
            const Text(
              'Impossible de charger vos camions',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}