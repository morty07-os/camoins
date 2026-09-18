import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_avatar.dart';
import '../widgets/info_row.dart';
import '../widgets/section_title.dart';

class DriverHomePage extends ConsumerWidget {
  const DriverHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).currentUser;
    final profile = user?.profile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de bord'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            tooltip: 'Notifications',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Aucune notification pour le moment'),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          _HeroHeader(
            userName: profile?.fullName,
            email: user?.email ?? '',
          ),
          const SizedBox(height: 20),
          const SectionTitle(
            title: 'Accès rapide',
            subtitle: 'Gérez votre activité de transport',
          ),
          const SizedBox(height: 12),
          _QuickAction(
            icon: Icons.search_rounded,
            title: 'Trouver un transport',
            subtitle: 'Recherchez des charges à transporter',
            onTap: () => _comingSoon(context),
          ),
          const SizedBox(height: 12),
          _QuickAction(
            icon: Icons.add_road_rounded,
            title: 'Proposer un trajet',
            subtitle: 'Publiez votre itinéraire et vos disponibilités',
            onTap: () => GoRouter.of(context).go('/driver-trips'),
          ),
          const SizedBox(height: 12),
          _QuickAction(
            icon: Icons.local_shipping_rounded,
            title: 'Gérer mes camions',
            subtitle: 'Ajoutez, modifiez ou retirez vos camions',
            onTap: () => GoRouter.of(context).go('/driver-trucks'),
          ),
          const SizedBox(height: 12),
          _QuickAction(
            icon: Icons.inbox_rounded,
            title: 'Mes demandes',
            subtitle: 'Consultez les demandes de vos clients',
            onTap: () => GoRouter.of(context).go('/driver-requests'),
          ),
          const SizedBox(height: 24),
          const SectionTitle(
            title: 'Mes informations',
            subtitle: 'Coordonnées visibles par vos clients',
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                InfoRow(
                  icon: Icons.phone_outlined,
                  label: 'Téléphone',
                  value: profile?.phone ?? '—',
                ),
                const Divider(),
                InfoRow(
                  icon: Icons.location_city_outlined,
                  label: 'Ville',
                  value: profile?.city ?? '—',
                ),
                const Divider(),
                InfoRow(
                  icon: Icons.map_outlined,
                  label: 'Wilaya',
                  value: profile?.wilaya ?? '—',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => GoRouter.of(context).go('/driver-profile'),
            icon: const Icon(Icons.person_outline_rounded),
            label: const Text('Voir mon profil'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Déconnexion'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.errorSoft),
            ),
          ),
          const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cette fonctionnalité arrive bientôt')),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  final String? userName;
  final String email;

  const _HeroHeader({this.userName, required this.email});

  @override
  Widget build(BuildContext context) {
    final name = (userName == null || userName!.trim().isEmpty)
        ? 'Chauffeur'
        : userName!;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.secondary],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bonjour, $name',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: AppAvatar(name: name, radius: 24),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(
                Icons.verified_rounded,
                size: 16,
                color: AppColors.accent,
              ),
              const SizedBox(width: 6),
              Text(
                'Chauffeur professionnel',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 24, color: AppColors.secondary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}