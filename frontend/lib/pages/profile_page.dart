import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';

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
    _fullNameController = TextEditingController(text: user?.profile.fullName ?? '');
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
          phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          city: _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
          wilaya: _wilayaController.text.trim().isEmpty ? null : _wilayaController.text.trim(),
        );

    if (success && mounted) {
      setState(() {
        _isEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to update profile'),
          backgroundColor: Theme.of(context).colorScheme.error,
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
        body: Center(child: Text('No user data')),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
              tooltip: 'Edit profile',
            ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 500 : double.infinity,
            ),
            child: _isEditing
                ? _buildEditForm(user, context)
                : _buildInfoDisplay(user, context),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoDisplay(User user, BuildContext context) {
    final profile = user.profile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: CircleAvatar(
            radius: 50,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(
              user.isDriver ? Icons.local_shipping : Icons.person,
              size: 50,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(height: 16),

        Center(
          child: Chip(
            label: Text(
              user.isDriver ? 'DRIVER' : 'CUSTOMER',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: user.isDriver
                ? Colors.blue.shade100
                : Colors.green.shade100,
          ),
        ),
        const SizedBox(height: 16),

        Text(
          profile.fullName.isNotEmpty ? profile.fullName : '—',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          user.email,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 24),

        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.phone_outlined, color: Colors.blue),
                title: const Text('Téléphone'),
                subtitle: Text(profile.phone ?? '—'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.location_city_outlined, color: Colors.blue),
                title: const Text('Ville'),
                subtitle: Text(profile.city ?? '—'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.map_outlined, color: Colors.blue),
                title: const Text('Wilaya'),
                subtitle: Text(profile.wilaya ?? '—'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        FilledButton.icon(
          onPressed: () {
            setState(() {
              _isEditing = true;
            });
          },
          icon: const Icon(Icons.edit),
          label: const Text('Modifier'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _handleLogout,
          icon: const Icon(Icons.logout),
          label: const Text('Déconnexion'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
        ),
      ],
    );
  }

  Widget _buildEditForm(User user, BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                user.isDriver ? Icons.local_shipping : Icons.person,
                size: 50,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 24),

          Center(
            child: Chip(
              label: Text(
                user.isDriver ? 'DRIVER' : 'CUSTOMER',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              backgroundColor: user.isDriver
                  ? Colors.blue.shade100
                  : Colors.green.shade100,
            ),
          ),
          const SizedBox(height: 8),

          Center(
            child: Text(
              user.email,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          const SizedBox(height: 32),

          TextFormField(
            controller: _fullNameController,
            decoration: const InputDecoration(
              labelText: 'Full Name',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person_outlined),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Full name is required';
              }
              return null;
            },
            enabled: true,
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _cityController,
            decoration: const InputDecoration(
              labelText: 'City',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.location_city_outlined),
            ),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _wilayaController,
            decoration: const InputDecoration(
              labelText: 'Wilaya',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.map_outlined),
            ),
          ),
          const SizedBox(height: 32),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _handleCancel,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton(
                  onPressed: _handleSave,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}