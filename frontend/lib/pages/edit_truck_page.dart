import 'package:flutter/material.dart';
import '../models/truck.dart';
import '../services/api_service.dart';
import '../widgets/section_title.dart';
import '../widgets/states.dart';

class EditTruckPage extends StatefulWidget {
  final int truckId;

  const EditTruckPage({super.key, required this.truckId});

  @override
  State<EditTruckPage> createState() => _EditTruckPageState();
}

class _EditTruckPageState extends State<EditTruckPage> {
  final _formKey = GlobalKey<FormState>();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _maxWeightController = TextEditingController();
  final _maxVolumeController = TextEditingController();
  final _registrationNumberController = TextEditingController();
  final _imageUrlController = TextEditingController();
  String _selectedTruckType = 'TARP';
  bool _isLoading = true;
  bool _isSaving = false;
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
        final truck = response['truck'] as Truck;
        _brandController.text = truck.brand;
        _modelController.text = truck.model;
        _maxWeightController.text = truck.maxWeight.toString();
        _maxVolumeController.text = truck.maxVolume?.toString() ?? '';
        _registrationNumberController.text = truck.registrationNumber;
        _imageUrlController.text = truck.imageUrl ?? '';
        setState(() {
          _selectedTruckType = truck.truckType;
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
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _maxWeightController.dispose();
    _maxVolumeController.dispose();
    _registrationNumberController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _updateTruck() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final apiService = ApiService();
      final response = await apiService.updateTruck(
        widget.truckId,
        truckType: _selectedTruckType,
        brand: _brandController.text.trim(),
        model: _modelController.text.trim(),
        maxWeight: double.parse(_maxWeightController.text.trim()),
        maxVolume: _maxVolumeController.text.trim().isNotEmpty
            ? double.parse(_maxVolumeController.text.trim())
            : null,
        registrationNumber: _registrationNumberController.text.trim(),
        imageUrl: _imageUrlController.text.trim(),
      );

      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Camion mis à jour avec succès')),
          );
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                response['message'] ?? 'Erreur lors de la mise à jour du camion',
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
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionTitle(
              title: 'Type de camion',
              subtitle: 'Choisissez la catégorie de votre véhicule',
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedTruckType,
              decoration: const InputDecoration(
                labelText: 'Type de camion *',
                prefixIcon: Icon(Icons.local_shipping_outlined),
              ),
              items: Truck.truckTypeDisplayNames.entries
                  .map((entry) => DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text(entry.value),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedTruckType = value);
                }
              },
            ),
            const SizedBox(height: 24),
            const SectionTitle(
              title: 'Informations du véhicule',
              subtitle: 'Identifiez votre camion',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _brandController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Marque',
                prefixIcon: Icon(Icons.directions_car_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _modelController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Modèle',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _registrationNumberController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Numéro d\'immatriculation',
                prefixIcon: Icon(Icons.confirmation_number_outlined),
              ),
            ),
            const SizedBox(height: 24),
            const SectionTitle(
              title: 'Capacités',
              subtitle: 'Poids et volume que le camion peut transporter',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _maxWeightController,
              decoration: const InputDecoration(
                labelText: 'Poids maximal *',
                hintText: 'en kilogrammes',
                prefixIcon: Icon(Icons.scale_rounded),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Le poids maximal est requis';
                }
                final parsed = double.tryParse(value.trim());
                if (parsed == null || parsed <= 0) {
                  return 'Le poids maximal doit être un nombre positif';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _maxVolumeController,
              decoration: const InputDecoration(
                labelText: 'Volume maximal (optionnel)',
                hintText: 'en mètres cubes',
                prefixIcon: Icon(Icons.view_in_ar_rounded),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) return null;
                final parsed = double.tryParse(value.trim());
                if (parsed == null || parsed <= 0) {
                  return 'Le volume maximal doit être un nombre positif';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            const SectionTitle(
              title: 'Photo du camion',
              subtitle: 'Une photo de votre véhicule (facultatif)',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _imageUrlController,
              decoration: const InputDecoration(
                labelText: 'URL de l\'image',
                prefixIcon: Icon(Icons.photo_outlined),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.pop(context, false),
                    child: const Text('ANNULER'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: _isSaving ? null : _updateTruck,
                    child: _isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text('METTRE À JOUR'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier le camion'),
      ),
      body: _isLoading
          ? const LoadingState(message: 'Chargement du camion…')
          : _loadError != null
              ? ErrorState(message: _loadError!, onRetry: _loadTruck)
              : _buildForm(),
    );
  }
}