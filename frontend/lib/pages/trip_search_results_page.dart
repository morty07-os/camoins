import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/search_result.dart';
import '../theme/app_theme.dart';

class TripSearchResultsPage extends StatelessWidget {
  final List<dynamic> results;

  const TripSearchResultsPage({super.key, required this.results});

  @override
  Widget build(BuildContext context) {
    final searchResults = results
        .map((r) => TripSearchResult.fromJson(r as Map<String, dynamic>))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Résultats de recherche'),
      ),
      body: searchResults.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    size: 64,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Aucun trajet disponible',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Aucun camion disponible ne correspond à votre recherche.\nEssayez d\'ajuster vos critères.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Nouvelle recherche'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 16),
              itemCount: searchResults.length,
              itemBuilder: (context, index) {
                final result = searchResults[index];
                return _SearchResultCard(
                  result: result,
                  onTap: () {
                    context.push('/search-trip-details/${result.trip.id}',
                        extra: result);
                  },
                );
              },
            ),
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  final TripSearchResult result;
  final VoidCallback onTap;

  const _SearchResultCard({
    required this.result,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header: Driver rating + Truck type + Match score
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.star_rounded,
                                size: 16, color: AppColors.accent),
                            const SizedBox(width: 4),
                            Text(
                              result.driver.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.text,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '(${result.driver.ratingCount})',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          result.driver.fullName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Score: ${result.matchScore}%',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Route
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            result.trip.originName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Départ',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: AppColors.secondary,
                        size: 20,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            result.trip.destinationName,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Destination',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Details row: Date, Truck, Capacity
              Row(
                children: [
                  Expanded(
                    child: _DetailItem(
                      icon: Icons.calendar_today_rounded,
                      label: 'Date',
                      value:
                          _formatDateShort(result.trip.departureDate),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DetailItem(
                      icon: Icons.local_shipping_rounded,
                      label: 'Camion',
                      value: result.truck.displayName,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _DetailItem(
                      icon: Icons.scale_rounded,
                      label: 'Capacité',
                      value: '${_formatNumber(result.trip.availableWeight)} kg',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DetailItem(
                      icon: Icons.view_in_ar_rounded,
                      label: 'Volume',
                      value: result.trip.availableVolume != null
                          ? '${_formatNumber(result.trip.availableVolume!)} m³'
                          : '—',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Voir le trajet'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }

  static String _formatDateShort(String isoDate) {
    final parts = isoDate.split('-');
    if (parts.length != 3) return isoDate;
    final day = int.tryParse(parts[2]);
    final month = int.tryParse(parts[1]);
    if (day == null || month == null) return isoDate;
    return '$day/${month.toString().padLeft(2, '0')}';
  }
}

class _DetailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
      ],
    );
  }
}
