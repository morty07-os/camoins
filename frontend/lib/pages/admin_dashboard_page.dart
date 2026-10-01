import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  final _search = TextEditingController();
  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>> _rides = [];
  bool _loading = true;
  String? _error;
  String _filter = 'ALL';
  DateTime? _updatedAt;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
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
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        _updatedAt = DateTime.now();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  int _minor(dynamic value) => value is int ? value : int.tryParse('$value') ?? 0;

  String _money(dynamic value) =>
      '${NumberFormat('#,##0.00', 'fr_FR').format(_minor(value) / 100)} DZD';

  String _date(dynamic value) {
    final parsed = DateTime.tryParse('${value ?? ''}');
    if (parsed == null) return 'Date indisponible';
    const months = [
      'janv.',
      'févr.',
      'mars',
      'avr.',
      'mai',
      'juin',
      'juil.',
      'août',
      'sept.',
      'oct.',
      'nov.',
      'déc.',
    ];
    return '${parsed.day.toString().padLeft(2, '0')} ${months[parsed.month - 1]} ${parsed.year}';
  }

  bool _matches(Map<String, dynamic> ride, String filter) => switch (filter) {
        'DUE' => ride['payment_status'] == 'PAID' && ride['commission_status'] == 'DUE',
        'COLLECTED' => ride['commission_status'] == 'COLLECTED',
        'PENDING' => ride['payment_status'] != 'PAID',
        _ => true,
      };

  int _count(String filter) => _rides.where((ride) => _matches(ride, filter)).length;

  List<Map<String, dynamic>> get _visibleRides {
    final query = _search.text.trim().toLowerCase();
    return _rides.where((ride) {
      final text = [
        ride['origin_name'],
        ride['destination_name'],
        ride['driver_name'],
        ride['customer_name'],
        ride['request_id'],
      ].join(' ').toLowerCase();
      return _matches(ride, _filter) && (query.isEmpty || text.contains(query));
    }).toList();
  }

  Future<void> _collect(Map<String, dynamic> ride) async {
    final controller = TextEditingController();
    final key = GlobalKey<FormState>();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.successSoft,
          child: Icon(Icons.account_balance_wallet_outlined, color: AppColors.success),
        ),
        title: const Text('Confirmer l’encaissement'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: key,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Vous confirmez la réception de ${_money(ride['platform_fee_minor'])} pour le trajet ${ride['origin_name']} → ${ride['destination_name']}.'),
                const SizedBox(height: 20),
                TextFormField(
                  controller: controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Référence de l’encaissement',
                    hintText: 'Ex. Versement chauffeur du 28/09',
                    prefixIcon: Icon(Icons.receipt_long_outlined),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Ajoutez une référence pour la traçabilité.'
                      : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
            child: const Text('Annuler'),
          ),
          FilledButton.icon(
            onPressed: () {
              if (key.currentState!.validate()) {
                Navigator.pop(dialogContext, controller.text.trim());
              }
            },
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Confirmer'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null) return;
    try {
      await ApiService().collectCommission(ride['payment_id'] as int, reason);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Commission de ${_money(ride['platform_fee_minor'])} enregistrée.'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final desktop = constraints.maxWidth >= 1080;
      return Scaffold(
        appBar: desktop
            ? null
            : AppBar(
                title: const _Brand(compact: true),
                actions: [
                  IconButton(
                    tooltip: 'Actualiser',
                    onPressed: _loading ? null : _load,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Compte administrateur',
                    icon: const CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.accent,
                      child: Icon(Icons.person_outline_rounded, size: 19, color: AppColors.primaryDark),
                    ),
                    onSelected: (value) {
                      if (value == 'logout') _logout();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'logout',
                        child: Row(children: [
                          Icon(Icons.logout_rounded),
                          SizedBox(width: 12),
                          Text('Se déconnecter'),
                        ]),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                ],
              ),
        body: Row(children: [
          if (desktop) _Sidebar(onLogout: _logout),
          Expanded(child: _body(desktop)),
        ]),
      );
    });
  }

  Widget _body(bool desktop) {
    if (_loading && _summary == null) return const _LoadingState();
    if (_error != null && _summary == null) {
      return _ErrorState(message: _error!, onRetry: _load);
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(desktop ? 40 : 20, desktop ? 32 : 24, desktop ? 40 : 20, 48),
            sliver: SliverList.list(children: [
              _PageHeader(updatedAt: _updatedAt, loading: _loading, onRefresh: _load),
              const SizedBox(height: 28),
              _metrics(),
              const SizedBox(height: 28),
              _progress(),
              const SizedBox(height: 28),
              _ridesSection(),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _metrics() {
    final items = [
      _MetricData('Volume total', _money(_summary?['gross_minor']), 'Toutes les courses actives', Icons.payments_outlined, AppColors.primary, AppColors.primarySoft),
      _MetricData('Commission totale', _money(_summary?['total_commission_minor']), 'Part plateforme · 9 %', Icons.pie_chart_outline_rounded, AppColors.secondary, AppColors.secondarySoft),
      _MetricData('Commission reçue', _money(_summary?['collected_commission_minor']), '${_count('COLLECTED')} encaissement${_count('COLLECTED') == 1 ? '' : 's'}', Icons.task_alt_rounded, AppColors.success, AppColors.successSoft),
      _MetricData('À encaisser', _money(_summary?['due_commission_minor']), '${_count('DUE')} commission${_count('DUE') == 1 ? '' : 's'} en attente', Icons.schedule_rounded, AppColors.warning, AppColors.accentSoft, emphasized: _minor(_summary?['due_commission_minor']) > 0),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 1050 ? 4 : constraints.maxWidth >= 620 ? 2 : 1;
      const gap = 16.0;
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: items.map((item) => SizedBox(width: width, child: _MetricCard(data: item))).toList(),
      );
    });
  }

  Widget _progress() {
    final total = _minor(_summary?['total_commission_minor']);
    final collected = _minor(_summary?['collected_commission_minor']);
    final value = total == 0 ? 0.0 : (collected / total).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(colors: [AppColors.primaryDark, AppColors.primary]),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxWidth < 680;
        final heading = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Taux d’encaissement', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
            const SizedBox(height: 6),
            Text('Suivez la part des commissions déjà récupérées.', style: TextStyle(color: Colors.white.withValues(alpha: .7))),
          ],
        );
        final meter = SizedBox(
          width: compact ? double.infinity : 340,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${(value * 100).round()} %', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(value: value, minHeight: 10, backgroundColor: Colors.white24, color: AppColors.accent),
              ),
              const SizedBox(height: 8),
              Text('${_money(collected)} sur ${_money(total)}', style: TextStyle(color: Colors.white.withValues(alpha: .7), fontSize: 12)),
            ],
          ),
        );
        return compact
            ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [heading, const SizedBox(height: 24), meter])
            : Row(children: [Expanded(child: heading), meter]);
      }),
    );
  }

  Widget _ridesSection() {
    final rides = _visibleRides;
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Transports', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text('${_summary?['accepted_rides'] ?? 0} courses acceptées au total', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 20),
                LayoutBuilder(builder: (context, constraints) {
                  final input = SizedBox(
                    width: constraints.maxWidth >= 720 ? 320 : double.infinity,
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Trajet, chauffeur ou client…',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Effacer',
                                onPressed: () {
                                  _search.clear();
                                  setState(() {});
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                      ),
                    ),
                  );
                  final filters = SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      _filterChip('ALL', 'Tous'),
                      const SizedBox(width: 8),
                      _filterChip('DUE', 'À encaisser'),
                      const SizedBox(width: 8),
                      _filterChip('COLLECTED', 'Reçues'),
                      const SizedBox(width: 8),
                      _filterChip('PENDING', 'En cours'),
                    ]),
                  );
                  return constraints.maxWidth < 720
                      ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [input, const SizedBox(height: 12), filters])
                      : Row(children: [input, const SizedBox(width: 16), Expanded(child: filters)]);
                }),
              ],
            ),
          ),
          const Divider(),
          if (rides.isEmpty)
            _EmptyState(filtered: _filter != 'ALL' || _search.text.isNotEmpty)
          else
            LayoutBuilder(builder: (context, constraints) {
              return constraints.maxWidth >= 880
                  ? _DesktopRides(rides: rides, money: _money, date: _date, onCollect: _collect)
                  : Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: rides
                            .map((ride) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _RideCard(ride: ride, money: _money, date: _date, onCollect: _collect),
                                ))
                            .toList(),
                      ),
                    );
            }),
        ],
      ),
    );
  }

  Widget _filterChip(String value, String label) => FilterChip(
        selected: _filter == value,
        showCheckmark: false,
        onSelected: (_) => setState(() => _filter = value),
        label: Text('$label  ${_count(value)}'),
        selectedColor: AppColors.primarySoft,
        side: BorderSide(color: _filter == value ? AppColors.primary : AppColors.border),
        labelStyle: TextStyle(
          color: _filter == value ? AppColors.primary : AppColors.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      );
}

class _Brand extends StatelessWidget {
  final bool compact;
  const _Brand({this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(11)),
        child: const Icon(Icons.local_shipping_outlined, color: AppColors.primaryDark, size: 22),
      ),
      const SizedBox(width: 11),
      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text('CAMOINS', style: TextStyle(fontSize: compact ? 16 : 18, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.1)),
        if (!compact) Text('ESPACE ADMIN', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: .55), letterSpacing: 1.4)),
      ]),
    ]);
  }
}

class _Sidebar extends StatelessWidget {
  final VoidCallback onLogout;
  const _Sidebar({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 252,
      color: AppColors.primaryDark,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const _Brand(),
        const SizedBox(height: 48),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
          child: const Row(children: [
            Icon(Icons.grid_view_rounded, color: AppColors.accent, size: 20),
            SizedBox(width: 12),
            Text('Vue d’ensemble', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ]),
        ),
        const Spacer(),
        const Divider(color: Color(0xFF234650)),
        const SizedBox(height: 12),
        InkWell(
          onTap: onLogout,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Icon(Icons.logout_rounded, color: Colors.white.withValues(alpha: .7), size: 20),
              const SizedBox(width: 12),
              Text('Se déconnecter', style: TextStyle(color: Colors.white.withValues(alpha: .8), fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _PageHeader extends StatelessWidget {
  final DateTime? updatedAt;
  final bool loading;
  final VoidCallback onRefresh;
  const _PageHeader({required this.updatedAt, required this.loading, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final stamp = updatedAt == null
        ? null
        : '${updatedAt!.hour.toString().padLeft(2, '0')}:${updatedAt!.minute.toString().padLeft(2, '0')}';
    final title = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Bonjour, Admin', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 6),
      Text('Voici l’activité financière de votre plateforme.', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary)),
    ]);
    final button = OutlinedButton.icon(
      onPressed: loading ? null : onRefresh,
      icon: loading
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.refresh_rounded, size: 19),
      label: Text(stamp == null ? 'Actualiser' : 'Actualisé à $stamp'),
    );
    return LayoutBuilder(builder: (context, constraints) {
      return constraints.maxWidth < 640
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [title, const SizedBox(height: 18), button])
          : Row(children: [Expanded(child: title), button]);
    });
  }
}

class _MetricData {
  final String label, value, helper;
  final IconData icon;
  final Color color, background;
  final bool emphasized;
  const _MetricData(this.label, this.value, this.helper, this.icon, this.color, this.background, {this.emphasized = false});
}

class _MetricCard extends StatelessWidget {
  final _MetricData data;
  const _MetricCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 164),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: data.emphasized ? data.color.withValues(alpha: .45) : AppColors.border, width: data.emphasized ? 1.4 : 1),
        boxShadow: [BoxShadow(color: AppColors.primaryDark.withValues(alpha: .045), blurRadius: 18, offset: const Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: data.background, borderRadius: BorderRadius.circular(12)),
            child: Icon(data.icon, color: data.color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(data.label, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
        ]),
        const SizedBox(height: 18),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(data.value, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800, letterSpacing: -.4)),
        ),
        const SizedBox(height: 6),
        Text(data.helper, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12)),
      ]),
    );
  }
}

class _DesktopRides extends StatelessWidget {
  final List<Map<String, dynamic>> rides;
  final String Function(dynamic) money, date;
  final void Function(Map<String, dynamic>) onCollect;
  const _DesktopRides({required this.rides, required this.money, required this.date, required this.onCollect});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(children: [
          Expanded(flex: 3, child: _TableLabel('TRAJET')),
          Expanded(flex: 2, child: _TableLabel('CHAUFFEUR')),
          Expanded(flex: 2, child: _TableLabel('MONTANT')),
          Expanded(flex: 2, child: _TableLabel('STATUT')),
          SizedBox(width: 150, child: _TableLabel('ACTION', right: true)),
        ]),
      ),
      const Divider(),
      ...rides.asMap().entries.map((entry) {
        final ride = entry.value;
        return Container(
          color: entry.key.isOdd ? AppColors.background.withValues(alpha: .6) : AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 17),
          child: Row(children: [
            Expanded(flex: 3, child: _RideTitle(ride: ride, date: date)),
            Expanded(
              flex: 2,
              child: _TwoLines('${ride['driver_name']}', 'Client · ${ride['customer_name']}'),
            ),
            Expanded(
              flex: 2,
              child: _TwoLines(money(ride['amount_minor']), 'Commission ${money(ride['platform_fee_minor'])}', strong: true),
            ),
            Expanded(flex: 2, child: _Status(ride: ride)),
            SizedBox(
              width: 150,
              child: Align(
                alignment: Alignment.centerRight,
                child: _canCollect(ride)
                    ? FilledButton(
                        onPressed: () => onCollect(ride),
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 42), padding: const EdgeInsets.symmetric(horizontal: 16)),
                        child: const Text('Encaisser'),
                      )
                    : IconButton(
                        tooltip: 'Voir les détails',
                        onPressed: () => _details(context, ride, money),
                        icon: const Icon(Icons.more_horiz_rounded),
                      ),
              ),
            ),
          ]),
        );
      }),
    ]);
  }
}

class _TableLabel extends StatelessWidget {
  final String label;
  final bool right;
  const _TableLabel(this.label, {this.right = false});
  @override
  Widget build(BuildContext context) => Text(label,
      textAlign: right ? TextAlign.right : TextAlign.left,
      style: const TextStyle(color: AppColors.textTertiary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .7));
}

class _RideTitle extends StatelessWidget {
  final Map<String, dynamic> ride;
  final String Function(dynamic) date;
  const _RideTitle({required this.ride, required this.date});
  @override
  Widget build(BuildContext context) => _TwoLines(
        '${ride['origin_name']} → ${ride['destination_name']}',
        '#${ride['request_id']} · ${date(ride['departure_date'])}',
        strong: true,
      );
}

class _TwoLines extends StatelessWidget {
  final String title, subtitle;
  final bool strong;
  const _TwoLines(this.title, this.subtitle, {this.strong = false});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: strong ? FontWeight.w700 : FontWeight.w500)),
        const SizedBox(height: 4),
        Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12)),
      ]);
}

class _RideCard extends StatelessWidget {
  final Map<String, dynamic> ride;
  final String Function(dynamic) money, date;
  final void Function(Map<String, dynamic>) onCollect;
  const _RideCard({required this.ride, required this.money, required this.date, required this.onCollect});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(11)),
            child: const Icon(Icons.route_outlined, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: _RideTitle(ride: ride, date: date)),
          const SizedBox(width: 8),
          _Status(ride: ride),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _Info('Chauffeur', '${ride['driver_name']}')),
          const SizedBox(width: 12),
          Expanded(child: _Info('Client', '${ride['customer_name']}')),
        ]),
        const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),
        Row(children: [
          Expanded(child: _Info('Prix', money(ride['amount_minor']), strong: true)),
          Expanded(child: _Info('Commission', money(ride['platform_fee_minor']), strong: true)),
        ]),
        if (_canCollect(ride)) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => onCollect(ride),
              icon: const Icon(Icons.account_balance_wallet_outlined, size: 19),
              label: const Text('Marquer comme encaissée'),
            ),
          ),
        ],
      ]),
    );
  }
}

class _Info extends StatelessWidget {
  final String label, value;
  final bool strong;
  const _Info(this.label, this.value, {this.strong = false});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11)),
        const SizedBox(height: 3),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: strong ? FontWeight.w800 : FontWeight.w600)),
      ]);
}

class _Status extends StatelessWidget {
  final Map<String, dynamic> ride;
  const _Status({required this.ride});
  @override
  Widget build(BuildContext context) {
    late String label;
    late Color color, background;
    late IconData icon;
    if (ride['commission_status'] == 'COLLECTED') {
      (label, color, background, icon) = ('Reçue', AppColors.success, AppColors.successSoft, Icons.check_circle_outline_rounded);
    } else if (_canCollect(ride)) {
      (label, color, background, icon) = ('À encaisser', AppColors.warning, AppColors.accentSoft, Icons.schedule_rounded);
    } else if (ride['payment_status'] == 'CANCELLED') {
      (label, color, background, icon) = ('Annulée', AppColors.error, AppColors.errorSoft, Icons.cancel_outlined);
    } else {
      (label, color, background, icon) = ('En cours', AppColors.secondary, AppColors.secondarySoft, Icons.hourglass_top_rounded);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

bool _canCollect(Map<String, dynamic> ride) =>
    ride['payment_status'] == 'PAID' && ride['commission_status'] == 'DUE' && ride['payment_id'] != null;

void _details(BuildContext context, Map<String, dynamic> ride, String Function(dynamic) money) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Détail du transport', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          _Detail('Trajet', '${ride['origin_name']} → ${ride['destination_name']}'),
          _Detail('Paiement', '${ride['payment_status'] ?? 'Non renseigné'}'),
          _Detail('Net chauffeur', money(ride['driver_net_minor'])),
          _Detail('Statut transport', '${ride['request_status'] ?? 'Non renseigné'}'),
        ]),
      ),
    ),
  );
}

class _Detail extends StatelessWidget {
  final String label, value;
  const _Detail(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 13),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 120, child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );
}

class _EmptyState extends StatelessWidget {
  final bool filtered;
  const _EmptyState({required this.filtered});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
        child: Column(children: [
          const CircleAvatar(radius: 29, backgroundColor: AppColors.primarySoft, child: Icon(Icons.search_off_rounded, color: AppColors.primary, size: 28)),
          const SizedBox(height: 16),
          Text(filtered ? 'Aucun résultat' : 'Aucun transport accepté', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(filtered ? 'Essayez un autre terme ou modifiez les filtres.' : 'Les transports apparaîtront ici après leur acceptation.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
        ]),
      );
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(children: [
              const CircleAvatar(radius: 32, backgroundColor: AppColors.errorSoft, child: Icon(Icons.cloud_off_rounded, color: AppColors.error, size: 30)),
              const SizedBox(height: 18),
              Text('Impossible de charger le tableau de bord', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 22),
              FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Réessayer')),
            ]),
          ),
        ),
      );
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(width: 260, child: LinearProgressIndicator()),
          const SizedBox(height: 30),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: List.generate(
              4,
              (_) => Container(
                width: 230,
                height: 154,
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Container(
            height: 360,
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
          ),
        ]),
      );
}
