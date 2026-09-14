import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
        setState(() => _trucks = trucks);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading trucks: \${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showAddTruckDialog() {
    showDialog(
      context: context,
      builder: (context) => AddTruckDialog(onTruckAdded: _loadTrucks),
    );
  }

  void _showEditTruckDialog(Truck truck) {
    showDialog(
      context: context,
      builder: (context) => EditTruckDialog(
        truck: truck,
        onTruckUpdated: _loadTrucks,
      ),
    );
  }

  void _deleteTruck(int truckId) async {
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Camion supprimé avec succès')),
          );
          _loadTrucks();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response['message'] ?? 'Erreur lors de la suppression')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: \${e.toString()}')),
        );
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
        onPressed: _showAddTruckDialog,
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
      padding: const EdgeInsets.all(16),
      itemCount: _trucks.length,
      itemBuilder: (context, index) {
        final truck = _trucks[index];
        return TruckCard(
          truck: truck,
          onEdit: () => _showEditTruckDialog(truck),
          onDelete: () => _deleteTruck(truck.id),
        );
      },
    );
  }
}

class TruckCard extends StatelessWidget {
  final Truck truck;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const TruckCard({
    super.key,
    required this.truck,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
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
                Text('Marque/Model: ${truck.brand.isNotEmpty ? truck.brand : 'N/A'}${truck.model.isNotEmpty ? '/ ' + truck.model : ''}'),
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
            if (truck.registrationNumber.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.credit_card, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text('Numéro d\'immatriculation: ${truck.registrationNumber}'),
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
    );
  }
}

class AddTruckDialog extends StatefulWidget {
  final Function onTruckAdded;

  const AddTruckDialog({
    super.key,
    required this.onTruckAdded,
  });

  @override
  State<AddTruckDialog> createState() => _AddTruckDialogState();
}

class _AddTruckDialogState extends State<AddTruckDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _brandController;
  late TextEditingController _modelController;
  late TextEditingController _maxWeightController;
  late TextEditingController _maxVolumeController;
  late TextEditingController _registrationNumberController;
  late TextEditingController _imageUrlController;
  String _selectedTruckType = 'FLATBED';

  @override
  void initState() {
    super.initState();
    _brandController = TextEditingController();
    _modelController = TextEditingController();
    _maxWeightController = TextEditingController();
    _maxVolumeController = TextEditingController();
    _registrationNumberController = TextEditingController();
    _imageUrlController = TextEditingController();
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ajouter un camion'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                  if (value == null || value.isEmpty) {
                    return 'Le poids maximal est requis';
                  }
                  if (double.tryParse(value) == null || double.parse(value) <= 0) {
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
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ANNULER'),
        ),
        ElevatedButton(
          onPressed: () => _saveTruck(context),
          child: const Text('SAUVEGARDER'),
        ),
      ],
    );
  }

  Future<void> _saveTruck(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final apiService = ApiService();
      final response = await apiService.createTruck(
        truck_type: _selectedTruckType,
        brand: _brandController.text,
        model: _modelController.text,
        max_weight: double.parse(_maxWeightController.text),
        max_volume: _maxVolumeController.text.isNotEmpty
            ? double.parse(_maxVolumeController.text)
            : null,
        registration_number: _registrationNumberController.text,
        image_url: _imageUrlController.text,
      );

      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camion ajouté avec succès')),
        );
        Navigator.pop(context);
        widget.onTruckAdded();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message'] ?? 'Erreur lors de l\'ajout du camion')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: \${e.toString()}')),
      );
    }
  }
}

class EditTruckDialog extends StatefulWidget {
  final Truck truck;
  final Function onTruckUpdated;

  const EditTruckDialog({
    super.key,
    required this.truck,
    required this.onTruckUpdated,
  });

  @override
  State<EditTruckDialog> createState() => _EditTruckDialogState();
}

class _EditTruckDialogState extends State<EditTruckDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _brandController;
  late TextEditingController _modelController;
  late TextEditingController _maxWeightController;
  late TextEditingController _maxVolumeController;
  late TextEditingController _registrationNumberController;
  late TextEditingController _imageUrlController;
  String _selectedTruckType = 'FLATBED';

  @override
  void initState() {
    super.initState();
    _brandController = TextEditingController(text: widget.truck.brand);
    _modelController = TextEditingController(text: widget.truck.model);
    _maxWeightController = TextEditingController(text: widget.truck.maxWeight.toString());
    _maxVolumeController = TextEditingController(
        text: widget.truck.maxVolume?.toString() ?? '');
    _registrationNumberController = TextEditingController(
        text: widget.truck.registrationNumber);
    _imageUrlController = TextEditingController(text: widget.truck.imageUrl ?? '');
    _selectedTruckType = widget.truck.truckType;
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Modifier le camion'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                  if (value == null || value.isEmpty) {
                    return 'Le poids maximal est requis';
                  }
                  if (double.tryParse(value) == null || double.parse(value) <= 0) {
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
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ANNULER'),
        ),
        ElevatedButton(
          onPressed: () => _updateTruck(context),
          child: const Text('METTRE À JOUR'),
        ),
      ],
    );
  }

  Future<void> _updateTruck(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final apiService = ApiService();
      final response = await apiService.updateTruck(
        widget.truck.id,
        truck_type: _selectedTruckType,
        brand: _brandController.text,
        model: _modelController.text,
        max_weight: double.parse(_maxWeightController.text),
        max_volume: _maxVolumeController.text.isNotEmpty
            ? double.parse(_maxVolumeController.text)
            : null,
        registration_number: _registrationNumberController.text,
        image_url: _imageUrlController.text,
      );

      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camion mis à jour avec succès')),
        );
        Navigator.pop(context);
        widget.onTruckUpdated();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message'] ?? 'Erreur lors de la mise à jour du camion')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: \${e.toString()}')),
      );
    }
  }
}