import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

Future<void> logoutAndNotify(BuildContext context, WidgetRef ref) async {
  final success = await ref.read(authProvider.notifier).logout();
  if (!success && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Déconnexion impossible. Vérifiez votre connexion et réessayez.'),
    ));
  }
}
