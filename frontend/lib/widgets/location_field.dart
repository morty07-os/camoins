import 'package:flutter/material.dart';

/// A city name field with an optional expandable latitude/longitude section.
class LocationField extends StatefulWidget {
  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final double? initialLat;
  final double? initialLng;

  const LocationField({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    this.initialLat,
    this.initialLng,
  });

  @override
  State<LocationField> createState() => LocationFieldState();
}

class LocationFieldState extends State<LocationField> {
  late final TextEditingController _latController;
  late final TextEditingController _lngController;
  bool _showCoordinates = false;

  @override
  void initState() {
    super.initState();
    _showCoordinates = widget.initialLat != null || widget.initialLng != null;
    _latController = TextEditingController(
      text: widget.initialLat != null ? widget.initialLat.toString() : '',
    );
    _lngController = TextEditingController(
      text: widget.initialLng != null ? widget.initialLng.toString() : '',
    );
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  bool get coordinatesVisible => _showCoordinates;

  double? get latitude => double.tryParse(_latController.text);

  double? get longitude => double.tryParse(_lngController.text);

  bool get coordinatesValid {
    if (!_showCoordinates) {
      return true;
    }
    final lat = double.tryParse(_latController.text);
    final lng = double.tryParse(_lngController.text);
    if (lat == null || lng == null) {
      return false;
    }
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            prefixIcon: Icon(widget.icon),
          ),
        ),
        TextButton.icon(
          onPressed: () {
            setState(() {
              _showCoordinates = !_showCoordinates;
              if (!_showCoordinates) {
                _latController.clear();
                _lngController.clear();
              }
            });
          },
          icon: Icon(
            _showCoordinates
                ? Icons.expand_less_rounded
                : Icons.expand_more_rounded,
            size: 18,
          ),
          label: Text(
            _showCoordinates
                ? 'Masquer les coordonnées'
                : 'Ajouter les coordonnées (optionnel)',
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            minimumSize: const Size(0, 36),
          ),
        ),
        if (_showCoordinates) ...[
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _latController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Latitude',
                    hintText: '36.7538',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _lngController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Longitude',
                    hintText: '3.0588',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}