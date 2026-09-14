import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../widgets/section_title.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();

  String _selectedRole = 'CUSTOMER';
  bool _obscurePassword = true;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final success = await ref.read(authProvider.notifier).register(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          fullName: _fullNameController.text.trim(),
          phone: _phoneController.text.trim(),
          role: _selectedRole,
        );

    if (!success && mounted) {
      final error = ref.read(authProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Échec de la création du compte'),
        ),
      );
    }
    // Navigation will be handled by router redirect
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Créer un compte'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 500 : double.infinity,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionTitle(
                    title: 'Informations personnelles',
                    subtitle:
                        'Ces informations seront visibles par les autres utilisateurs.',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _fullNameController,
                    textInputAction: TextInputAction.next,
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
                    enabled: !authState.isLoading,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Téléphone (optionnel)',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    enabled: !authState.isLoading,
                  ),
                  const SizedBox(height: 24),
                  const SectionTitle(
                    title: 'Sécurité du compte',
                    subtitle: 'Vos identifiants de connexion.',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Adresse email',
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'L\'adresse email est requise';
                      }
                      if (!value.contains('@')) {
                        return 'Veuillez saisir une adresse email valide';
                      }
                      return null;
                    },
                    enabled: !authState.isLoading,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'Mot de passe',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        tooltip: _obscurePassword
                            ? 'Afficher le mot de passe'
                            : 'Masquer le mot de passe',
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Le mot de passe est requis';
                      }
                      if (value.length < 6) {
                        return 'Le mot de passe doit contenir au moins 6 caractères';
                      }
                      return null;
                    },
                    enabled: !authState.isLoading,
                  ),
                  const SizedBox(height: 24),
                  const SectionTitle(
                    title: 'Votre profil',
                    subtitle:
                        'Choisissez le type de compte qui correspond à votre activité.',
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Je suis un(e)',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'CUSTOMER',
                        child: Text('Client (je cherche des camions)'),
                      ),
                      DropdownMenuItem(
                        value: 'DRIVER',
                        child: Text('Chauffeur (je dispose d\'un camion)'),
                      ),
                    ],
                    onChanged: authState.isLoading
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() {
                                _selectedRole = value;
                              });
                            }
                          },
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: authState.isLoading
                        ? null
                        : _handleRegister,
                    child: authState.isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Créer mon compte'),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: authState.isLoading
                          ? null
                          : () {
                              Navigator.of(context).pop();
                            },
                      child: const Text('Déjà un compte ? Se connecter'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}