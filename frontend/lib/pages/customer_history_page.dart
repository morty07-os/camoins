import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../providers/transport_updates_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/rating.dart';
import '../providers/notification_provider.dart' show apiServiceProvider;
import '../theme/app_theme.dart';
import '../widgets/notification_icon.dart';
import '../widgets/star_rating.dart';
import '../widgets/rating_bottom_sheet.dart';
import '../widgets/status_badge.dart';

class CustomerHistoryPage extends ConsumerStatefulWidget {
  const CustomerHistoryPage({super.key});

  @override
  ConsumerState<CustomerHistoryPage> createState() => _CustomerHistoryPageState();
}

class _CustomerHistoryPageState extends ConsumerState<CustomerHistoryPage> {
  List<HistoryItem> _history = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.getTripHistory();
      if (mounted) {
        setState(() {
          _history = response.history;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  String _formatDate(String isoDate) {
    try {
      final parts = isoDate.split('-');
      if (parts.length != 3) return isoDate;
      final day = int.parse(parts[2]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[0]);
      const months = [
        'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
        'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
      ];
      return '$day ${months[month - 1]} $year';
    } catch (_) {
      return isoDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(transportUpdatesProvider, (_, __) => _loadHistory());
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes transports'),
        actions: [
          const NotificationIcon(),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: AppColors.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Erreur de chargement',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _loadHistory,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    if (_history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.local_shipping_outlined,
                size: 64,
                color: AppColors.textTertiary,
              ),
              const SizedBox(height: 16),
              Text(
                'Aucun transport effectué',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Vos transports apparaîtront ici après confirmation de la réception dans leur conversation.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              TextButton(
                onPressed: () => context.go('/customer-messages'),
                child: const Text('Ouvrir mes conversations'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _history.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = _history[index];
          return _HistoryCard(item: item, formatDate: _formatDate, onRated: _loadHistory);
        },
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final VoidCallback onRated;
  final HistoryItem item;
  final String Function(String) formatDate;

  const _HistoryCard({
    required this.onRated,
    required this.item,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = item.status == 'COMPLETED';

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with route and date
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item.origin} → ${item.destination}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatDate(item.date),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
                StatusBadge(status: item.status),
              ],
            ),
            const SizedBox(height: 16),

            // Other party info
            if (item.otherParty != null) ...[
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: item.otherParty!.role == 'DRIVER'
                        ? AppColors.accentSoft
                        : AppColors.successSoft,
                    backgroundImage: item.otherParty!.name.isNotEmpty
                        ? null
                        : null,
                    child: Text(
                      item.otherParty!.name.isNotEmpty
                          ? item.otherParty!.name[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: item.otherParty!.role == 'DRIVER'
                            ? AppColors.accent
                            : AppColors.success,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.otherParty!.name,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.text,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: item.otherParty!.role == 'DRIVER'
                                    ? AppColors.accentSoft
                                    : AppColors.successSoft,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.otherParty!.role == 'DRIVER'
                                    ? 'Chauffeur'
                                    : 'Client',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: item.otherParty!.role == 'DRIVER'
                                      ? AppColors.accent
                                      : AppColors.success,
                                ),
                              ),
                            ),
                            if (item.otherParty!.ratingCount > 0) ...[
                              const SizedBox(width: 8),
                              StarRatingDisplay(
                                rating: item.otherParty!.rating,
                                count: item.otherParty!.ratingCount,
                                starSize: 14,
                                fontSize: 12,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Truck info
            if (item.truck != null) ...[
              Row(
                children: [
                  Icon(
                    Icons.local_shipping_outlined,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${item.truck!.type} ${item.truck!.brand != null ? '- ${item.truck!.brand}' : ''} ${item.truck!.model != null ? '${item.truck!.model}' : ''}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // My rating
            if (item.myRating != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.star_rounded,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Votre évaluation',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              StarRating(
                                rating: item.myRating!.rating,
                                size: 16,
                                activeColor: AppColors.warning,
                              ),
                              if (item.myRating!.comment != null &&
                                  item.myRating!.comment!.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '"${item.myRating!.comment!}"',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          fontStyle: FontStyle.italic,
                                          color: AppColors.text,
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (isCompleted && item.requestId != null && item.otherParty != null) ...[
              // Rating prompt for completed but not rated
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.star_outline_rounded,
                      size: 20,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Vous n\'avez pas encore évalué ce transport',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => RatingBottomSheet.show(
                        context: context,
                        tripId: item.tripId,
                        requestId: item.requestId!,
                        reviewedUserId: item.otherParty!.id,
                        reviewedUserName: item.otherParty!.name,
                        onRatingSubmitted: onRated,
                      ),
                      child: const Text('Évaluer le transport'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
