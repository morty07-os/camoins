import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/search_result.dart';
import '../models/trip.dart';
import '../theme/app_theme.dart';
import '../widgets/info_row.dart';
import '../widgets/section_title.dart';
import '../widgets/status_badge.dart';

class SearchTripDetailsPage extends StatelessWidget {
  final int tripId;
  final dynamic initialResult;

  const SearchTripDetailsPage({
    super.key,
    required this.tripId,
    this.initialResult,
  });

  @override
  Widget build(BuildContext context) {
    // Parse initialResult if it's a Map (from navigation extra)
    TripSearchResult? result;
    try {
      if (initialResult != null) {
        if (initialResult is TripSearchResult) {
          result = initialResult as TripSearchResult;
        } else if (initialResult is Map<String, dynamic>) {
          result = TripSearchResult.fromJson(initialResult);
        }
      }
    } catch (e) {
      debugPrint('Error parsing trip result: $e');
    }

    if (result == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Détails du trajet')),
        body: const Center(child: Text('Trajet non disponible')),
      );
    }

    final trip = result.trip;
    final driver = result.driver;
    final truck = result.truck;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails du trajet'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with route
            Container(
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
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              trip.originName,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Départ',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              trip.destinationName,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Destination',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Score de correspondance',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${result.matchScore}%',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      StatusBadge(status: trip.status),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Driver information
            const SectionTitle(title: 'Transporteur'),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              driver.fullName.isNotEmpty
                                  ? driver.fullName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                driver.fullName,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.text,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.star_rounded,
                                      size: 14, color: AppColors.accent),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${driver.rating.toStringAsFixed(1)} (${driver.ratingCount} avis)',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Trip information
            const SectionTitle(title: 'Détails du trajet'),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  InfoRow(
                    icon: Icons.calendar_today_rounded,
                    label: 'Date de départ',
                    value: _formatFrenchDate(trip.departureDate),
                  ),
                  const Divider(),
                  InfoRow(
                    icon: Icons.scale_rounded,
                    label: 'Capacité disponible',
                    value:
                        '${_formatNumber(trip.availableWeight)} kg',
                  ),
                  if (trip.availableVolume != null) ...[
                    const Divider(),
                    InfoRow(
                      icon: Icons.view_in_ar_rounded,
                      label: 'Volume disponible',
                      value: '${_formatNumber(trip.availableVolume!)} m³',
                    ),
                  ],
                  if (trip.description.trim().isNotEmpty) ...[
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Description',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            trip.description,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.text,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Truck information
            const SectionTitle(title: 'Véhicule'),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.local_shipping_rounded,
                    color: AppColors.secondary,
                    size: 24,
                  ),
                ),
                title: Text(truck.displayName),
                subtitle: Text(
                  '${truck.maxWeight.toStringAsFixed(0)} kg max',
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Call-to-action
            FilledButton.icon(
              onPressed: () {
                context.push(
                  '/request-form/${trip.id}',
                  extra: trip,
                );
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Demander ce transport'),
            ),
            const SizedBox(height: 24),
          ],
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

  static String _formatFrenchDate(String isoDate) {
    final parts = isoDate.split('-');
    if (parts.length != 3) return isoDate;
    final day = int.tryParse(parts[2]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[0]);
    if (day == null || month == null || year == null || month < 1 || month > 12) {
      return isoDate;
    }
    const months = [
      'janvier',
      'février',
      'mars',
      'avril',
      'mai',
      'juin',
      'juillet',
      'août',
      'septembre',
      'octobre',
      'novembre',
      'décembre',
    ];
    return '$day ${months[month - 1]} $year';
  }
}
