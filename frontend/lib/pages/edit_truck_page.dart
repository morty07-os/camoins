import 'package:flutter/material.dart';
import '../models/truck.dart';
import '../services/api_service.dart';

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
        _loadError = 'Erreur: $e';
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
              content: Text(response['message'] ?? 'Erreur lors de la mise à jour du camion'),
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
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _selectedTruckType,
              decoration: const InputDecoration(
                labelText: 'Type de camion *',
                border: OutlineInputBorder(),
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
            const SizedBox(height: 16),
            TextFormField(
              controller: _brandController,
              decoration: const InputDecoration(
                labelText: 'Marque',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _modelController,
              decoration: const InputDecoration(
                labelText: 'Modèle',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _maxWeightController,
              decoration: const InputDecoration(
                labelText: 'Poids maximal *',
                hintText: 'en kilogrammes',
                border: OutlineInputBorder(),
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
            const SizedBox(height: 16),
            TextFormField(
              controller: _maxVolumeController,
              decoration: const InputDecoration(
                labelText: 'Volume maximal (optionnel)',
                hintText: 'en mètres cubes',
                border: OutlineInputBorder(),
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
            const SizedBox(height: 16),
            TextFormField(
              controller: _registrationNumberController,
              decoration: const InputDecoration(
                labelText: 'Numéro d\'immatriculation',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _imageUrlController,
              decoration: const InputDecoration(
                labelText: 'URL de l\'image',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('ANNULER'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _updateTruck,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
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
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
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
              : _buildForm(),
    );
  }
}