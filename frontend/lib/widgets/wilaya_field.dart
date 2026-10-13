import 'package:flutter/material.dart';
import '../constants/algerian_wilayas.dart';

/// Selects an existing wilaya from a searchable list.
class WilayaField extends StatelessWidget {
  const WilayaField({
    super.key,
    this.initialValue,
    required this.decoration,
    required this.onChanged,
    this.validator,
  });

  final String? initialValue;
  final InputDecoration decoration;
  final ValueChanged<String?> onChanged;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) => FormField<String>(
        initialValue: initialValue,
        validator: validator,
        builder: (field) => InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            final selected = await showDialog<String>(
              context: context,
              builder: (_) => _WilayaDialog(selected: field.value),
            );
            if (!field.mounted || selected == null) return;
            field.didChange(selected);
            onChanged(selected);
          },
          child: InputDecorator(
            isEmpty: field.value == null,
            decoration: decoration.copyWith(
              errorText: field.errorText,
              suffixIcon: const Icon(Icons.arrow_drop_down),
            ),
            child: Text(field.value ?? '', overflow: TextOverflow.ellipsis),
          ),
        ),
      );
}

class _WilayaDialog extends StatefulWidget {
  const _WilayaDialog({this.selected});
  final String? selected;

  @override
  State<_WilayaDialog> createState() => _WilayaDialogState();
}

class _WilayaDialogState extends State<_WilayaDialog> {
  String _query = '';

  String _normalize(String value) {
    var result = value.toLowerCase().trim();
    const accents = {
      'à': 'a',
      'â': 'a',
      'ï': 'i',
      'î': 'i',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'ô': 'o',
      'ù': 'u',
      'û': 'u',
      'ç': 'c'
    };
    for (final entry in accents.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }
    return result.replaceAll(RegExp(r"[\s'’-]+"), '');
  }

  @override
  Widget build(BuildContext context) {
    final matches = algerianWilayas
        .where((name) => _normalize(name).contains(_normalize(_query)))
        .toList();
    return AlertDialog(
      title: const Text('Choisir une wilaya'),
      content: SizedBox(
        width: 420,
        height: 400,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Rechercher une wilaya',
                hintText: 'Ex. : Alger, Oran, Setif',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: matches.isEmpty
                  ? const Center(child: Text('Aucune wilaya trouvée'))
                  : ListView.builder(
                      itemCount: matches.length,
                      itemBuilder: (context, index) {
                        final name = matches[index];
                        return ListTile(
                          title: Text(name),
                          selected: name == widget.selected,
                          trailing: name == widget.selected
                              ? const Icon(Icons.check)
                              : null,
                          onTap: () => Navigator.of(context).pop(name),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
      ],
    );
  }
}
