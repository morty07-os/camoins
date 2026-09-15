import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final Color background;
    switch (status) {
      case 'IN_PROGRESS':
        color = AppColors.accent;
        background = AppColors.accentSoft;
        break;
      case 'COMPLETED':
        color = AppColors.primary;
        background = AppColors.primarySoft;
        break;
      case 'CANCELLED':
        color = AppColors.error;
        background = AppColors.errorSoft;
        break;
      case 'PUBLISHED':
      default:
        color = AppColors.success;
        background = AppColors.successSoft;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _statusLabel(status),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  static String _statusLabel(String status) {
    switch (status) {
      case 'IN_PROGRESS':
        return 'En cours';
      case 'COMPLETED':
        return 'Terminé';
      case 'CANCELLED':
        return 'Annulé';
      case 'PUBLISHED':
      default:
        return 'Publié';
    }
  }
}