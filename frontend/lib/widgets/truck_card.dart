import 'package:flutter/material.dart';
import '../models/truck.dart';
import '../theme/app_theme.dart';

class TruckCard extends StatelessWidget {
  final Truck truck;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const TruckCard({
    super.key,
    required this.truck,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final brandModel = [
      if (truck.brand.isNotEmpty) truck.brand,
      if (truck.model.isNotEmpty) truck.model,
    ].join(' ');

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.local_shipping_rounded,
                      color: AppColors.secondary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          truck.displayName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                        if (brandModel.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            brandModel,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    _CapacityItem(
                      icon: Icons.scale_rounded,
                      label: 'Poids max',
                      value: '${truck.maxWeight.toStringAsFixed(0)} kg',
                    ),
                    if (truck.maxVolume != null) ...[
                      const SizedBox(width: 16),
                      _CapacityItem(
                        icon: Icons.view_in_ar_rounded,
                        label: 'Volume',
                        value: '${truck.maxVolume!.toStringAsFixed(1)} m³',
                      ),
                    ],
                    const Spacer(),
                    IconButton(
                      onPressed: onEdit,
                      tooltip: 'Modifier',
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: AppColors.secondary,
                      ),
                    ),
                    IconButton(
                      onPressed: onDelete,
                      tooltip: 'Supprimer',
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CapacityItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _CapacityItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}