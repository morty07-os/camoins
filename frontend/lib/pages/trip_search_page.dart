import 'package:flutter/material.dart';

import 'trip_search_results_page.dart';

/// Backward-compatible entry point for callers that still reference the old
/// search form. Search and results now live on one progressively filtered page.
class TripSearchPage extends StatelessWidget {
  const TripSearchPage({super.key});

  @override
  Widget build(BuildContext context) => const TripSearchResultsPage();
}
