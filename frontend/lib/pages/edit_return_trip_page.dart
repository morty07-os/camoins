import 'package:flutter/material.dart';
import '../models/trip.dart';
import '../services/api_service.dart';
import '../widgets/return_trip_form.dart';
import '../widgets/states.dart';

class EditReturnTripPage extends StatefulWidget {
  final int tripId;

  const EditReturnTripPage({super.key, required this.tripId});

  @override
  State<EditReturnTripPage> createState() => _EditReturnTripPageState();
}

class _EditReturnTripPageState extends State<EditReturnTripPage> {
  final _formKey = GlobalKey<ReturnTripFormState>();
  Trip? _trip;
  bool _isLoadingTrip = true;
  bool _isSaving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadTrip();
  }

  Future<void> _loadTrip() async {
    setState(() {
      _isLoadingTrip = true;
      _loadError = null;
    });

    try {
      final apiService = ApiService();
      final response = await apiService.getTrip(widget.tripId);
      if (response['success'] == true) {
        setState(() {
          _trip = response['trip'] as Trip;
          _isLoadingTrip = false;
        });
      } else {
        setState(() {
          _loadError = response['message'] ?? 'Impossible de charger le trajet';
          _isLoadingTrip = false;
        });
      }
    } catch (e) {
      setState(() {
        _loadError = 'Vérifiez votre connexion et réessayez.';
        _isLoadingTrip = false;
      });
    }
  }

  Future<void> _updateTrip() async {
    final data = _formKey.currentState?.collect();
    if (data == null) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final apiService = ApiService();
      final response = await apiService.updateTrip(
        widget.tripId,
        truckId: data.truckId,
        originName: data.originName,
        originLat: data.originLat,
        originLng: data.originLng,
        destinationName: data.destinationName,
        destinationLat: data.destinationLat,
        destinationLng: data.destinationLng,
        departureDate: data.departureDate,
        availableWeight: data.availableWeight,
        availableVolume: data.availableVolume,
        description: data.description,
      );

      if (mounted) {
        if (response['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Trajet retour modifié avec succès')),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                response['message'] ?? 'Erreur lors de la modification',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier le trajet retour'),
      ),
      body: _isLoadingTrip
          ? const LoadingState(message: 'Chargement du trajet…')
          : _loadError != null
              ? ErrorState(message: _loadError!, onRetry: _loadTrip)
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  child: ReturnTripForm(
                    key: _formKey,
                    initialTrip: _trip,
                  ),
                ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Row(
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
                onPressed: _isSaving ||
                        _isLoadingTrip ||
                        _loadError != null ||
                        _formKey.currentState?.canSubmit == false
                    ? null
                    : _updateTrip,
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('ENREGISTRER'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}