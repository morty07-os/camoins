import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/return_trip_form.dart';

class PublishReturnTripPage extends StatefulWidget {
  const PublishReturnTripPage({super.key});

  @override
  State<PublishReturnTripPage> createState() => _PublishReturnTripPageState();
}

class _PublishReturnTripPageState extends State<PublishReturnTripPage> {
  final _formKey = GlobalKey<ReturnTripFormState>();
  bool _isSaving = false;

  Future<void> _publishTrip() async {
    final data = _formKey.currentState?.collect();
    if (data == null) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final apiService = ApiService();
      final response = await apiService.createTrip(
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
            const SnackBar(content: Text('Trajet retour publié avec succès')),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                response['message'] ?? 'Erreur lors de la publication',
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
        title: const Text('Publier un trajet retour'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: ReturnTripForm(
          key: _formKey,
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
                        _formKey.currentState?.canSubmit == false
                    ? null
                    : _publishTrip,
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('PUBLIER LE TRAJET'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}