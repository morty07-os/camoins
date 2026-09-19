import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_avatar.dart';
import '../widgets/info_row.dart';
import '../widgets/notification_icon.dart';
import '../widgets/section_title.dart';
import '../widgets/star_rating.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fullNameController;
  late TextEditingController _phoneController;
  late TextEditingController _cityController;
  late TextEditingController _wilayaController;

  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).currentUser;
    _fullNameController = TextEditingController(
      text: user?.profile.fullName ?? '',
    );
    _phoneController = TextEditingController(text: user?.profile.phone ?? '');
    _cityController = TextEditingController(text: user?.profile.city ?? '');
    _wilayaController = TextEditingController(text: user?.profile.wilaya ?? '');
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _wilayaController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final success = await ref.read(authProvider.notifier).updateProfile(
          fullName: _fullNameController.text.trim(),
          phone: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
          city: _cityController.text.trim().isEmpty
              ? null
              : _cityController.text.trim(),
          wilaya: _wilayaController.text.trim().isEmpty
              ? null
              : _wilayaController.text.trim(),
        );

    if (success && mounted) {
      setState(() {
        _isEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil mis à jour avec succès'),
          backgroundColor: AppColors.success,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Échec de la mise à jour du profil'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _handleCancel() {
    final user = ref.read(authProvider).currentUser;
    setState(() {
      _fullNameController.text = user?.profile.fullName ?? '';
      _phoneController.text = user?.profile.phone ?? '';
      _cityController.text = user?.profile.city ?? '';
      _wilayaController.text = user?.profile.wilaya ?? '';
      _isEditing = false;
    });
  }

  Future<void> _handleLogout() async {
    await ref.read(authProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Aucune donnée utilisateur',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
              tooltip: 'Modifier le profil',
            ),
          const NotificationIcon(),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 520 : double.infinity,
            ),
            child: _isEditing
                ? _buildEditForm(user)
                : _buildInfoDisplay(user),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoDisplay(User user) {
    final profile = user.profile;
    final roleColor = user.isDriver
        ? (AppColors.accent, AppColors.accentSoft)
        : (AppColors.success, AppColors.successSoft);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: AppAvatar(
              name: profile.fullName,
              imageUrl: profile.profileImage,
              radius: 40,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: Chip(
            label: Text(
              user.isDriver ? 'Chauffeur certifié' : 'Client',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: roleColor.$1,
              ),
            ),
            backgroundColor: roleColor.$2,
            side: BorderSide(color: roleColor.$2),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          profile.fullName.isNotEmpty ? profile.fullName : '—',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          user.email,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        if (profile.ratingCount > 0)
          Center(
            child: StarRatingDisplay(
              rating: profile.rating,
              count: profile.ratingCount,
              starSize: 20,
              fontSize: 16,
            ),
          )
        else
          Center(
            child: Text(
              'Aucune évaluation pour le moment',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        const SizedBox(height: 24),
        const SectionTitle(
          title: 'Informations',
          subtitle: 'Vos coordonnées de contact',
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              InfoRow(
                icon: Icons.phone_outlined,
                label: 'Téléphone',
                value: profile.phone ?? '—',
              ),
              const Divider(),
              InfoRow(
                icon: Icons.location_city_outlined,
                label: 'Ville',
                value: profile.city ?? '—',
              ),
              const Divider(),
              InfoRow(
                icon: Icons.map_outlined,
                label: 'Wilaya',
                value: profile.wilaya ?? '—',
              ),
            ],
          ),
        ),
        if (user.isDriver) ...[
          const SizedBox(height: 24),
          const SectionTitle(
            title: 'Gestion',
            subtitle: 'Gérez votre activité',
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.local_shipping_outlined),
              title: const Text('Mes camions'),
              subtitle: const Text('Ajouter et modifier vos véhicules'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => GoRouter.of(context).go('/driver-trucks'),
            ),
          ),
        ],
        const SizedBox(height: 32),
        FilledButton.icon(
          onPressed: () {
            setState(() {
              _isEditing = true;
            });
          },
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Modifier'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _handleLogout,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Déconnexion'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.error,
            side: const BorderSide(color: AppColors.errorSoft),
          ),
        ),
      ],
    );
  }

  Widget _buildEditForm(User user) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle(
            title: 'Modifier mon profil',
            subtitle: 'Mettez à jour vos informations personnelles',
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _fullNameController,
            decoration: const InputDecoration(
              labelText: 'Nom complet',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Le nom complet est requis';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Téléphone',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _cityController,
            decoration: const InputDecoration(
              labelText: 'Ville',
              prefixIcon: Icon(Icons.location_city_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _wilayaController,
            decoration: const InputDecoration(
              labelText: 'Wilaya',
              prefixIcon: Icon(Icons.map_outlined),
            ),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _handleCancel,
                  child: const Text('Annuler'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton(
                  onPressed: _handleSave,
                  child: const Text('Enregistrer'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}