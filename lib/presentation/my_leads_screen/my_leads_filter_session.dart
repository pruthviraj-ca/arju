import 'package:flutter/material.dart';

/// Holds the temporary, in-memory filter selections for the My Leads screen
/// during a single app session. Resets on user logout or app cold start.
class MyLeadsFilterSession {
  static String searchQuery = '';
  static List<String> selectedFilter = [];
  static List<String> selectedTagFilter = [];
  static List<String> selectedTempFilter = [];
  static String sortBy = 'Created Date';
  static DateTimeRange? selectedDateRange;
  static bool isFilterExpanded = false;

  /// Resets all filter values back to their defaults.
  static void reset() {
    searchQuery = '';
    selectedFilter = [];
    selectedTagFilter = [];
    selectedTempFilter = [];
    sortBy = 'Created Date';
    selectedDateRange = null;
    isFilterExpanded = false;
  }
}
