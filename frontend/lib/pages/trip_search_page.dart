import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/trip.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/location_field.dart';
import '../widgets/section_title.dart';

class TripSearchFormData {
  final String originName;
  final double? originLat;
  final double? originLng;
  final String destinationName;
  final double? destinationLat;
  final double? destinationLng;
  final String departureDate;
  final double requiredWeight;
  final double? requiredVolume;

  TripSearchFormData({
    required this.originName,
    this.originLat,
    this.originLng,
    required this.destinationName,
    this.destinationLat,
    this.destinationLng,
    required this.departureDate,
    required this.requiredWeight,
    this.requiredVolume,
  });
}

class TripSearchPage extends StatefulWidget {
  const TripSearchPage({super.key});

  @override
  State<TripSearchPage> createState() => _TripSearchPageState();
}

class _TripSearchPageState extends State<TripSearchPage> {
  final _formKey = GlobalKey<FormState>();
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  final _weightController = TextEditingController();
  final _volumeController = TextEditingController();
  final _dateController = TextEditingController();

  final _originFieldKey = GlobalKey<LocationFieldState>();
  final _destinationFieldKey = GlobalKey<LocationFieldState>();

  DateTime? _selectedDate;
  String? _dateError;
  bool _isSearching = false;

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    _weightController.dispose();
    _volumeController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? initial,
      firstDate: now,
      lastDate: DateTime(now.year + 1),
      helpText: 'Date de départ',
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = Trip.formatFrenchDate(_dateToIso(picked));
        _dateError = null;
      });
    }
  }

  static String _dateToIso(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Future<void> _search() async {
    if (_selectedDate == null) {
      setState(() => _dateError = 'La date de départ est requise');
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final originState = _originFieldKey.currentState;
    final destinationState = _destinationFieldKey.currentState;

    if (originState != null && !originState.coordinatesValid) {
      return;
    }
    if (destinationState != null && !destinationState.coordinatesValid) {
      return;
    }

    setState(() => _isSearching = true);

    try {
      final apiService = ApiService();
      final response = await apiService.searchTrips(
        originLat: originState?.coordinatesVisible == true
            ? originState!.latitude
            : null,
        originLng: originState?.coordinatesVisible == true
            ? originState!.longitude
            : null,
        destinationLat: destinationState?.coordinatesVisible == true
            ? destinationState!.latitude
            : null,
        destinationLng: destinationState?.coordinatesVisible == true
            ? destinationState!.longitude
            : null,
        date: _dateToIso(_selectedDate!),
        requiredWeight: double.parse(_weightController.text.trim()),
        requiredVolume: _volumeController.text.trim().isNotEmpty
            ? double.parse(_volumeController.text.trim())
            : null,
      );

      if (mounted) {
        if (response['success'] == true) {
          final trips = response['trips'] as List;
          context.push(
            '/search-results',
            extra: trips,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                response['message'] ?? 'Erreur lors de la recherche',
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
        setState(() => _isSearching = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rechercher un trajet'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionTitle(
                title: 'Itinéraire',
                subtitle: 'D\'où à où souhaitez-vous transporter ?',
              ),
              const SizedBox(height: 12),
              LocationField(
                key: _originFieldKey,
                label: 'Départ *',
                hint: 'Ex : Alger',
                icon: Icons.trip_origin_rounded,
                controller: _originController,
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
              ),
              const SizedBox(height: 24),
              const SectionTitle(
                title: 'Date et capacité',
                subtitle: 'Quand et combien avez-vous besoin de transporter ?',
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
                  return null;
                },
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _isSearching ? null : _search,
                icon: _isSearching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Icon(Icons.search_rounded),
                label: const Text('RECHERCHER'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
