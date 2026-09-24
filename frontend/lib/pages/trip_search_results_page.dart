import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/search_result.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/notification_icon.dart';

class TripSearchResultsPage extends StatefulWidget {
  final ApiService? apiService;

  const TripSearchResultsPage({super.key, this.apiService});

  @override
  State<TripSearchResultsPage> createState() => _TripSearchResultsPageState();
}

class _TripSearchResultsPageState extends State<TripSearchResultsPage> {
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  final _weightController = TextEditingController();
  final _volumeController = TextEditingController();
  Timer? _debounce;
  List<TripSearchResult> _results = [];
  String? _error;
  String? _weightError;
  String? _volumeError;
  DateTime? _selectedDate;
  String? _truckType;
  bool _loading = false;
  bool _waitingForDebounce = false;
  bool _suppressFilterListeners = false;
  int _page = 1;
  int _totalPages = 1;
  int _totalCount = 0;
  int _requestVersion = 0;

  static const _truckTypes = <String, String>{
    'FLATBED': 'Plateau',
    'TARP': 'Bâché',
    'REFRIGERATED': 'Frigorifique',
    'VAN': 'Fourgon',
    'SEMI_TRAILER': 'Semi-remorque',
    'OTHER': 'Autre',
  };

  @override
  void initState() {
    super.initState();
    _originController.addListener(_onTextChanged);
    _destinationController.addListener(_onTextChanged);
    _weightController.addListener(_onTextChanged);
    _volumeController.addListener(_onTextChanged);
    _loadTrips();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _originController.dispose();
    _destinationController.dispose();
    _weightController.dispose();
    _volumeController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (_suppressFilterListeners) return;
    _debounce?.cancel();
    ++_requestVersion;
    setState(() {
      _waitingForDebounce = true;
      _loading = false;
      _error = null;
      _page = 1;
      _results = [];
    });
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _loadTrips();
    });
  }

  String? _numericError(String value, String field) {
    if (value.trim().isEmpty) return null;
    final normalized = value.trim().replaceAll(',', '.');
    final parsed = double.tryParse(normalized);
    if (!RegExp(r'^\d+(?:\.\d+)?$').hasMatch(normalized) ||
        parsed == null ||
        !parsed.isFinite ||
        parsed <= 0) {
      return '$field doit être un nombre positif';
    }
    return null;
  }

  double? _parseOptionalNumber(String value) {
    if (value.trim().isEmpty) return null;
    return double.parse(value.trim().replaceAll(',', '.'));
  }

  String? get _dateFilter {
    if (_selectedDate == null) return null;
    final date = _selectedDate!;
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadTrips({int page = 1}) async {
    final version = ++_requestVersion;
    final weightError = _numericError(_weightController.text, 'Le poids');
    final volumeError = _numericError(_volumeController.text, 'Le volume');
    if (weightError != null || volumeError != null) {
      setState(() {
        _waitingForDebounce = false;
        _loading = false;
        _error = null;
        _weightError = weightError;
        _volumeError = volumeError;
        _results = [];
        _page = 1;
        _totalPages = 1;
        _totalCount = 0;
      });
      return;
    }
    final weight = _parseOptionalNumber(_weightController.text);
    final volume = _parseOptionalNumber(_volumeController.text);
    setState(() {
      _waitingForDebounce = false;
      _loading = true;
      _error = null;
      _weightError = null;
      _volumeError = null;
      if (page == 1) {
        _page = 1;
        _results = [];
        _totalCount = 0;
      }
    });
    final response = await (widget.apiService ?? ApiService()).searchTrips(
      originName: _originController.text,
      destinationName: _destinationController.text,
      date: _dateFilter,
      requiredWeight: weight,
      requiredVolume: volume,
      truckType: _truckType,
      page: page,
    );
    if (!mounted || version != _requestVersion) return;
    if (response['success'] != true) {
      setState(() {
        _loading = false;
        _error = response['message'] ?? 'Erreur lors du chargement des trajets';
        _results = [];
      });
      return;
    }
    setState(() {
      _loading = false;
      _page = (response['page'] as num?)?.toInt() ?? page;
      _totalPages = (response['totalPages'] as num?)?.toInt() ?? 1;
      _totalCount = (response['count'] as num?)?.toInt() ?? 0;
      final nextResults = (response['trips'] as List? ?? [])
          .map((result) =>
              TripSearchResult.fromJson(result as Map<String, dynamic>))
          .toList();
      _results = page == 1 ? nextResults : [..._results, ...nextResults];
    });
  }

  void _resetFilters() {
    _debounce?.cancel();
    ++_requestVersion;
    _suppressFilterListeners = true;
    _originController.clear();
    _destinationController.clear();
    _weightController.clear();
    _volumeController.clear();
    _suppressFilterListeners = false;
    setState(() {
      _selectedDate = null;
      _truckType = null;
      _weightError = null;
      _volumeError = null;
      _waitingForDebounce = false;
    });
    _loadTrips();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1),
      helpText: 'Date de départ',
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
      _loadTrips();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filterCount = [
      _originController.text,
      _destinationController.text,
      _weightController.text,
      _volumeController.text,
      _dateFilter,
      _truckType,
    ]
        .where((value) => value != null && value.toString().trim().isNotEmpty)
        .length;
    return Scaffold(
      appBar: AppBar(
          title: const Text('Résultats de recherche'),
          actions: [const NotificationIcon()]),
      body: Column(children: [
        _buildFilters(filterCount),
        if ((_loading || _waitingForDebounce) && _results.isNotEmpty)
          const LinearProgressIndicator(minHeight: 2),
        Expanded(child: _buildResults())
      ]),
    );
  }

  Widget _buildFilters(int filterCount) {
    return Material(
      color: AppColors.primarySoft,
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text('Filtres${filterCount > 0 ? ' ($filterCount)' : ''}'),
        subtitle: _totalCount > 0
            ? Text('$_totalCount trajet${_totalCount > 1 ? 's' : ''}')
            : null,
        trailing: TextButton(
            onPressed: filterCount == 0 ? null : _resetFilters,
            child: const Text('Réinitialiser')),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          _buildTextFilter(
            controller: _originController,
            label: 'Départ',
            icon: Icons.trip_origin,
          ),
          const SizedBox(height: 8),
          _buildTextFilter(
            controller: _destinationController,
            label: 'Destination',
            icon: Icons.location_on_outlined,
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: TextField(
                    controller: _weightController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                        labelText: 'Poids min. (kg)',
                        errorText: _weightError,
                        suffixIcon: _weightController.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Effacer le poids',
                                onPressed: _weightController.clear,
                                icon: const Icon(Icons.clear),
                              )))),
            const SizedBox(width: 8),
            Expanded(
                child: TextField(
                    controller: _volumeController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                        labelText: 'Volume min. (m³)',
                        errorText: _volumeError,
                        suffixIcon: _volumeController.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Effacer le volume',
                                onPressed: _volumeController.clear,
                                icon: const Icon(Icons.clear),
                              )))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today),
                      label: Text(_dateFilter ?? 'Date'),
                    ),
                  ),
                  if (_selectedDate != null)
                    IconButton(
                      tooltip: 'Effacer la date',
                      onPressed: () {
                        setState(() => _selectedDate = null);
                        _loadTrips();
                      },
                      icon: const Icon(Icons.clear),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
                child: DropdownButtonFormField<String>(
                    key: ValueKey(_truckType),
                    initialValue: _truckType,
                    decoration:
                        const InputDecoration(labelText: 'Type de camion'),
                    items: [
                      const DropdownMenuItem<String>(
                          value: null, child: Text('Tous les types')),
                      ..._truckTypes.entries.map((entry) => DropdownMenuItem(
                          value: entry.key, child: Text(entry.value)))
                    ],
                    onChanged: (value) {
                      setState(() => _truckType = value);
                      _loadTrips();
                    })),
          ]),
        ],
      ),
    );
  }

  Widget _buildTextFilter({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Effacer $label',
                onPressed: controller.clear,
                icon: const Icon(Icons.clear),
              ),
      ),
    );
  }

  Widget _buildResults() {
    if (_error != null) {
      return Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.cloud_off, size: 52, color: AppColors.textSecondary),
        const SizedBox(height: 12),
        Text(_error!, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => _loadTrips(),
          child: const Text('Réessayer'),
        )
      ]));
    }
    if (_weightError != null || _volumeError != null) {
      return const Center(
        child: Text('Corrigez les filtres numériques pour afficher les trajets.'),
      );
    }
    if ((_loading || _waitingForDebounce) && _results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_results.isEmpty) {
      return Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.search_off_rounded,
            size: 56, color: AppColors.textSecondary),
        const SizedBox(height: 12),
        const Text('Aucun trajet ne correspond à vos critères',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        OutlinedButton.icon(
            onPressed: _resetFilters,
            icon: const Icon(Icons.restart_alt),
            label: const Text('Réinitialiser'))
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
      itemCount: _results.length + (_totalPages > _page ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _results.length) {
          return Center(
              child: OutlinedButton(
                  onPressed:
                      _loading ? null : () => _loadTrips(page: _page + 1),
                  child: const Text('Charger plus')));
        }
        final result = _results[index];
        return _SearchResultCard(
            result: result,
            onTap: () => context.push('/search-trip-details/${result.trip.id}',
                extra: result));
      },
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
                      value: _formatDateShort(result.trip.departureDate),
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
