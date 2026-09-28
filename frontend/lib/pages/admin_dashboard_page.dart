import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>> _rides = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService().getAdminDashboard();
      if (!mounted) return;
      setState(() {
        _summary = Map<String, dynamic>.from(data['summary'] as Map);
        _rides = (data['rides'] as List)
            .map((ride) => Map<String, dynamic>.from(ride as Map))
            .toList();
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  String _money(dynamic minor) {
    final value = minor is int ? minor : int.tryParse('$minor') ?? 0;
    return '${(value / 100).toStringAsFixed(2)} DZD';
  }

  Future<void> _collectCommission(Map<String, dynamic> ride) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Commission reçue'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Référence ou motif',
            hintText: 'Ex. Versement chauffeur du 28/09',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ANNULER')),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(context, value);
            },
            child: const Text('CONFIRMER'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null) return;
    try {
      await ApiService().collectCommission(ride['payment_id'] as int, reason);
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administration Camoins'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          IconButton(
            tooltip: 'Déconnexion',
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_error!),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _load, child: const Text('Réessayer')),
                ]))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _Metric('Courses acceptées', '${_summary?['accepted_rides'] ?? 0}'),
                          _Metric('Valeur totale', _money(_summary?['gross_minor'])),
                          _Metric('Commission 9 %', _money(_summary?['total_commission_minor'])),
                          _Metric('Commission reçue', _money(_summary?['collected_commission_minor'])),
                          _Metric('Commission due', _money(_summary?['due_commission_minor'])),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text('Transports acceptés', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      if (_rides.isEmpty)
                        const Card(child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('Aucun transport accepté.'),
                        )),
                      ..._rides.map(_rideCard),
                    ],
                  ),
                ),
    );
  }

  Widget _rideCard(Map<String, dynamic> ride) {
    final canCollect = ride['payment_status'] == 'PAID' &&
        ride['commission_status'] == 'DUE' &&
        ride['payment_id'] != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${ride['origin_name']} → ${ride['destination_name']}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 6),
          Text('Chauffeur : ${ride['driver_name']}'),
          Text('Client : ${ride['customer_name']}'),
          Text('Statut transport : ${ride['request_status']}'),
          Text('Paiement : ${ride['payment_status'] ?? 'Ancien transport sans prix'}'),
          const Divider(),
          Text('Prix : ${_money(ride['amount_minor'])}'),
          Text('Commission Camoins (9 %) : ${_money(ride['platform_fee_minor'])}'),
          Text('Net chauffeur : ${_money(ride['driver_net_minor'])}'),
          Text('Commission : ${ride['commission_status'] ?? 'NON CALCULÉE'}'),
          if (canCollect) ...[
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => _collectCommission(ride),
              icon: const Icon(Icons.account_balance_wallet_outlined),
              label: const Text('Marquer la commission reçue'),
            ),
          ],
        ]),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
          ]),
        ),
      ),
    );
  }
}
