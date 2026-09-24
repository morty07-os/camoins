import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/search_result.dart';
import '../models/truck.dart';
import '../providers/notification_provider.dart' show apiServiceProvider;
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/notification_icon.dart';

class TripSearchResultsPage extends ConsumerStatefulWidget {
  final ApiService? apiService;

  const TripSearchResultsPage({super.key, this.apiService});

  @override
  ConsumerState<TripSearchResultsPage> createState() =>
      _TripSearchResultsPageState();
}

class _TripSearchResultsPageState
    extends ConsumerState<TripSearchResultsPage> {
  static const _pageSize = 20;
  static const _debounceDuration = Duration(milliseconds: 350);

  late final ApiService _apiService;
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  final _weightController = TextEditingController();
  final _volumeController = TextEditingController();
  final _dateController = TextEditingController();
  final _scrollController = ScrollController();

  Timer? _debounce;
  List<TripSearchResult> _results = [];
  DateTime? _departureDate;
  String? _truckType;
  String? _weightError;
  String? _volumeError;
  String? _requestError;
  int _revision = 0;
  int _page = 0;
  int _totalPages = 0;
  int _totalCount = 0;
  bool _isLoading = true;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ref.read(apiServiceProvider);
    _scrollController.addListener(_onScroll);
    unawaited(_fetchPage(page: 1, revision: _revision));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _originController.dispose();
    _destinationController.dispose();
    _weightController.dispose();
    _volumeController.dispose();
    _dateController.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 240 &&
        !_isLoading &&
        !_isLoadingMore &&
        _page < _totalPages) {
      unawaited(_fetchPage(page: _page + 1, revision: _revision));
    }
  }

  double? _parseCapacity(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    final normalized = value.replaceAll(',', '.');
    if (!RegExp(r'^\d+(?:\.\d+)?$').hasMatch(normalized)) return null;
    final parsed = double.tryParse(normalized);
    return parsed != null && parsed > 0 ? parsed : null;
  }

  String? _capacityError(String raw, String unit) {
    if (raw.trim().isEmpty || _parseCapacity(raw) != null) return null;
    return 'Saisissez un nombre positif ($unit)';
  }

  void _onTextFilterChanged(String _) {
    _debounce?.cancel();
    _revision++;
    final weightError = _capacityError(_weightController.text, 'kg');
    final volumeError = _capacityError(_volumeController.text, 'm³');
    final revision = _revision;

    setState(() {
      _weightError = weightError;
      _volumeError = volumeError;
      _requestError = null;
      _results = [];
      _page = 0;
      _totalPages = 0;
      _totalCount = 0;
      _isLoading = weightError == null && volumeError == null;
      _isLoadingMore = false;
    });
    _scrollToTop();

    if (weightError != null || volumeError != null) return;
    _debounce = Timer(
      _debounceDuration,
      () => _fetchPage(page: 1, revision: revision),
    );
  }

  void _applyNonTextFilterChange() {
    _debounce?.cancel();
    _revision++;
    final revision = _revision;
    setState(() {
      _requestError = null;
      _results = [];
      _page = 0;
      _totalPages = 0;
      _totalCount = 0;
      _isLoading = true;
      _isLoadingMore = false;
    });
    _scrollToTop();
    unawaited(_fetchPage(page: 1, revision: revision));
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  Future<void> _fetchPage({
    required int page,
    required int revision,
  }) async {
    if (page > 1) {
      if (_isLoadingMore) return;
      setState(() => _isLoadingMore = true);
    }

    try {
      final response = await _apiService.searchTrips(
        originName: _originController.text,
        destinationName: _destinationController.text,
        date: _departureDate == null ? null : _dateToIso(_departureDate!),
        requiredWeight: _parseCapacity(_weightController.text),
        requiredVolume: _parseCapacity(_volumeController.text),
        truckType: _truckType,
        page: page,
        pageSize: _pageSize,
      );

      if (!mounted || revision != _revision) return;
      if (response['success'] != true) {
        throw Exception(
          response['message'] ?? 'Impossible de charger les trajets',
        );
      }

      final rawResults = response['trips'] as List? ?? const [];
      final parsedResults = rawResults
          .map(
            (result) => TripSearchResult.fromJson(
              result as Map<String, dynamic>,
            ),
          )
          .toList();

      setState(() {
        _results = page == 1
            ? parsedResults
            : <TripSearchResult>[..._results, ...parsedResults];
        _page = response['page'] as int? ?? page;
        _totalPages = response['totalPages'] as int? ?? 0;
        _totalCount = response['count'] as int? ?? _results.length;
        _requestError = null;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (error) {
      if (!mounted || revision != _revision) return;
      setState(() {
        if (page == 1) _results = [];
        _requestError = error.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _refresh() async {
    _debounce?.cancel();
    _revision++;
    final revision = _revision;
    setState(() {
      _requestError = null;
      _isLoading = _results.isEmpty;
    });
    await _fetchPage(page: 1, revision: revision);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _departureDate ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
      helpText: 'Date de départ',
    );
    if (picked == null || !mounted) return;
    _departureDate = picked;
    _dateController.text = _formatDate(picked);
    _applyNonTextFilterChange();
  }

  void _clearDate() {
    _departureDate = null;
    _dateController.clear();
    _applyNonTextFilterChange();
  }

  void _clearTextFilter(TextEditingController controller) {
    controller.clear();
    _onTextFilterChanged('');
  }

  void _resetFilters() {
    _debounce?.cancel();
    _originController.clear();
    _destinationController.clear();
    _weightController.clear();
    _volumeController.clear();
    _dateController.clear();
    _departureDate = null;
    _truckType = null;
    _weightError = null;
    _volumeError = null;
    _applyNonTextFilterChange();
  }

  int get _activeFilterCount => [
        _originController.text.trim().isNotEmpty,
        _destinationController.text.trim().isNotEmpty,
        _weightController.text.trim().isNotEmpty,
        _volumeController.text.trim().isNotEmpty,
        _departureDate != null,
        _truckType != null,
      ].where((active) => active).length;

  static String _dateToIso(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trajets disponibles'),
        actions: [
          if (_activeFilterCount > 0)
            IconButton(
              onPressed: _resetFilters,
              tooltip: 'Réinitialiser les filtres',
              icon: const Icon(Icons.filter_alt_off_rounded),
            ),
          const NotificationIcon(),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          if (_activeFilterCount > 0) _buildActiveFilters(),
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: ExpansionTile(
        initiallyExpanded: true,
        maintainState: true,
        leading: const Icon(Icons.tune_rounded),
        title: const Text('Filtres'),
        subtitle: Text(
          _activeFilterCount == 0
              ? 'Tous les trajets disponibles'
              : '$_activeFilterCount filtre${_activeFilterCount > 1 ? 's' : ''} actif${_activeFilterCount > 1 ? 's' : ''}',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _originController,
                  onChanged: _onTextFilterChanged,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Départ',
                    hintText: 'Ex : Alger',
                    prefixIcon: Icon(Icons.trip_origin_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _destinationController,
                  onChanged: _onTextFilterChanged,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Destination',
                    hintText: 'Ex : Sétif',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _weightController,
                  onChanged: _onTextFilterChanged,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Poids min. (kg)',
                    prefixIcon: const Icon(Icons.scale_rounded),
                    errorText: _weightError,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _volumeController,
                  onChanged: _onTextFilterChanged,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Volume min. (m³)',
                    prefixIcon: const Icon(Icons.view_in_ar_rounded),
                    errorText: _volumeError,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _dateController,
                  readOnly: true,
                  onTap: _pickDate,
                  decoration: InputDecoration(
                    labelText: 'Date de départ',
                    prefixIcon: const Icon(Icons.calendar_today_rounded),
                    suffixIcon: _departureDate == null
                        ? const Icon(Icons.expand_more_rounded)
                        : IconButton(
                            onPressed: _clearDate,
                            tooltip: 'Effacer la date',
                            icon: const Icon(Icons.clear_rounded),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey(_truckType),
                  initialValue: _truckType,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Type de camion',
                    prefixIcon: Icon(Icons.local_shipping_outlined),
                  ),
                  items: Truck.truckTypeDisplayNames.entries
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text(
                            entry.value,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    _truckType = value;
                    _applyNonTextFilterChange();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _activeFilterCount == 0 ? null : _resetFilters,
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('Réinitialiser'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFilters() {
    final chips = <Widget>[];
    void addChip(String label, VoidCallback onDeleted) {
      chips.add(InputChip(label: Text(label), onDeleted: onDeleted));
    }

    if (_originController.text.trim().isNotEmpty) {
      addChip(
        'Départ : ${_originController.text.trim()}',
        () => _clearTextFilter(_originController),
      );
    }
    if (_destinationController.text.trim().isNotEmpty) {
      addChip(
        'Destination : ${_destinationController.text.trim()}',
        () => _clearTextFilter(_destinationController),
      );
    }
    if (_weightController.text.trim().isNotEmpty) {
      addChip(
        '${_weightController.text.trim()} kg min.',
        () => _clearTextFilter(_weightController),
      );
    }
    if (_volumeController.text.trim().isNotEmpty) {
      addChip(
        '${_volumeController.text.trim()} m³ min.',
        () => _clearTextFilter(_volumeController),
      );
    }
    if (_departureDate != null) {
      addChip('Date : ${_formatDate(_departureDate!)}', _clearDate);
    }
    if (_truckType != null) {
      addChip(
        Truck.truckTypeDisplayNames[_truckType] ?? _truckType!,
        () {
          _truckType = null;
          _applyNonTextFilterChange();
        },
      );
    }

    return SizedBox(
      height: 46,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) => chips[index],
      ),
    );
  }

  Widget _buildResults() {
    if (_isLoading) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          Center(child: CircularProgressIndicator()),
          SizedBox(height: 12),
          Center(child: Text('Chargement des trajets...')),
        ],
      );
    }

    if (_requestError != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 56,
            color: AppColors.error,
          ),
          const SizedBox(height: 12),
          const Text(
            'Impossible de charger les trajets',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            _requestError!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer'),
          ),
        ],
      );
    }

    if (_results.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(
            Icons.search_off_rounded,
            size: 64,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 14),
          const Text(
            'Aucun trajet ne correspond à vos critères',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _resetFilters,
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Réinitialiser'),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(0, 6, 0, 16),
        itemCount: _results.length + 1 + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
              child: Text(
                '$_totalCount trajet${_totalCount > 1 ? 's' : ''} disponible${_totalCount > 1 ? 's' : ''}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }
          if (index > _results.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final result = _results[index - 1];
          return _SearchResultCard(
            result: result,
            onTap: () => context.push(
              '/search-trip-details/${result.trip.id}',
              extra: result,
            ),
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
