import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppAvatar extends StatelessWidget {
  final String? name;
  final String? imageUrl;
  final double radius;

  const AppAvatar({
    super.key,
    this.name,
    this.imageUrl,
    this.radius = 24,
  });

  String get _initials {
    final parts = (name ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return '?';
    }
    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;
    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: ClipOval(
        child: hasImage
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _Initials(
                  initials: _initials,
                  radius: radius,
                ),
              )
            : _Initials(initials: _initials, radius: radius),
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  final String initials;
  final double radius;

  const _Initials({required this.initials, required this.radius});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.accentSoft,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.7,
        ),
      ),
    );
  }
}