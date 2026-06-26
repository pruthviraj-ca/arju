import 'package:flutter/material.dart';

/// Holds the temporary, in-memory filter selections for the My Leads screen
/// during a single app session. Resets on user logout or app cold start.
class MyLeadsFilterSession {
  static String searchQuery = '';
  static String selectedFilter = 'All';
  static String selectedTagFilter = 'All';
  static String selectedTempFilter = 'All';
  static String sortBy = 'Created Date';
  static DateTimeRange? selectedDateRange;
  static bool isFilterExpanded = false;

  /// Resets all filter values back to their defaults.
  static void reset() {
    searchQuery = '';
    selectedFilter = 'All';
    selectedTagFilter = 'All';
    selectedTempFilter = 'All';
    sortBy = 'Created Date';
    selectedDateRange = null;
    isFilterExpanded = false;
  }
}
