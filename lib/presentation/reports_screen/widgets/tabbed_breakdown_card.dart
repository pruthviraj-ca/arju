/// tabbed_breakdown_card.dart
///
/// A premium tabbed breakdown widget displaying BY STATUS, BY PROJECT,
/// and BY SOURCE metrics for Leads, SVs, and Bookings.
/// Each row uses a bar-graph visual: colored dot, label, proportional
/// horizontal bar, and a rounded count badge.
/// Supports both real-time Firestore counts and realistic mock fallbacks.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class TabbedBreakdownCard extends StatefulWidget {
  final Map<String, int> leadStatusCounts;
  final Map<String, int> leadProjectCounts;
  final Map<String, int> leadSourceCounts;

  final Map<String, int> svStatusCounts;
  final Map<String, int> svProjectCounts;
  final Map<String, int> svSourceCounts;

  final Map<String, int> bookingStatusCounts;
  final Map<String, int> bookingProjectCounts;
  final Map<String, int> bookingSourceCounts;

  const TabbedBreakdownCard({
    super.key,
    required this.leadStatusCounts,
    required this.leadProjectCounts,
    required this.leadSourceCounts,
    required this.svStatusCounts,
    required this.svProjectCounts,
    required this.svSourceCounts,
    required this.bookingStatusCounts,
    required this.bookingProjectCounts,
    required this.bookingSourceCounts,
  });

  @override
  State<TabbedBreakdownCard> createState() => _TabbedBreakdownCardState();
}

class _TabbedBreakdownCardState extends State<TabbedBreakdownCard> {
  int _selectedTabIndex = 0; // 0 = Leads, 1 = SVs, 2 = Bookings

  // Default Mock Fallbacks (used if the respective real data map is empty)
  static const Map<String, int> _mockLeadsStatus = {
    'In Progress': 0,
    'Closed': 0,
  };
  static const Map<String, int> _mockLeadsProject = {
    'Skyline Heights': 0,
    'Urban Oasis': 0,
  };
  static const Map<String, int> _mockLeadsSource = {
    'Referral': 0,
    'Meta Ads': 0,
  };

  static const Map<String, int> _mockSvsStatus = {
    'Scheduled': 0,
    'Completed': 0,
    'Missed': 0,
  };
  static const Map<String, int> _mockSvsProject = {
    'Skyline Heights': 0,
    'Green Valley': 0,
    'Urban Oasis': 0,
  };
  static const Map<String, int> _mockSvsSource = {
    'Google Ads': 0,
    'Facebook Ads': 0,
    'Direct': 0,
  };

  static const Map<String, int> _mockBookingsStatus = {
    'Confirmed': 0,
    'Pending': 0,
  };
  static const Map<String, int> _mockBookingsProject = {
    'Skyline Heights': 0,
    'Urban Oasis': 0,
  };
  static const Map<String, int> _mockBookingsSource = {
    'Meta Ads': 0,
    'Referral': 0,
  };

  // ─── Color Helpers ──────────────────────────────────────────────────────────

  /// Returns the foreground color for a lead source string.
  static Color _sourceColor(String source) {
    switch (source.toLowerCase()) {
      case 'meta':
      case 'facebook':
      case 'facebook ads':
      case 'meta ads':
        return const Color(0xFF1877F2);
      case 'google':
      case 'google ads':
        return const Color(0xFF4285F4);
      case 'magicbricks':
        return const Color(0xFFE65100);
      case '99acres':
        return const Color(0xFF1565C0);
      case 'housing':
      case 'housing.com':
        return const Color(0xFFE91E63);
      case 'walk-in':
      case 'walkin':
        return AppTheme.teal;
      case 'referral':
        return AppTheme.success;
      case 'website':
        return AppTheme.purple;
      case 'direct':
        return const Color(0xFF6366F1);
      case 'nobroker':
        return const Color(0xFF00897B);
      default:
        return AppTheme.mutedText;
    }
  }

  /// Returns a soft background color for a lead source.
  static Color _sourceBgColor(String source) {
    return _sourceColor(source).withAlpha(25);
  }

  /// Curated palette for project colors (hash-based index).
  static const List<Color> _projectPalette = [
    Color(0xFF0D9488), // teal
    Color(0xFF7C3AED), // violet
    Color(0xFFD97706), // amber
    Color(0xFF4F46E5), // indigo
    Color(0xFFDB2777), // pink
    Color(0xFF059669), // emerald
    Color(0xFF9333EA), // purple
    Color(0xFF2563EB), // blue
  ];

  /// Returns a foreground color for a project name.
  static Color _projectColor(String project) {
    final index = project.hashCode.abs() % _projectPalette.length;
    return _projectPalette[index];
  }

  /// Returns a soft background color for a project name.
  static Color _projectBgColor(String project) {
    return _projectColor(project).withAlpha(25);
  }

  @override
  Widget build(BuildContext context) {
    // Determine target maps based on selection and empty-checks
    Map<String, int> statusData = {};
    Map<String, int> projectData = {};
    Map<String, int> sourceData = {};

    if (_selectedTabIndex == 0) {
      statusData = widget.leadStatusCounts.isEmpty ? _mockLeadsStatus : widget.leadStatusCounts;
      projectData = widget.leadProjectCounts.isEmpty ? _mockLeadsProject : widget.leadProjectCounts;
      sourceData = widget.leadSourceCounts.isEmpty ? _mockLeadsSource : widget.leadSourceCounts;
    } else if (_selectedTabIndex == 1) {
      statusData = widget.svStatusCounts.isEmpty ? _mockSvsStatus : widget.svStatusCounts;
      projectData = widget.svProjectCounts.isEmpty ? _mockSvsProject : widget.svProjectCounts;
      sourceData = widget.svSourceCounts.isEmpty ? _mockSvsSource : widget.svSourceCounts;
    } else {
      statusData = widget.bookingStatusCounts.isEmpty ? _mockBookingsStatus : widget.bookingStatusCounts;
      projectData = widget.bookingProjectCounts.isEmpty ? _mockBookingsProject : widget.bookingProjectCounts;
      sourceData = widget.bookingSourceCounts.isEmpty ? _mockBookingsSource : widget.bookingSourceCounts;
    }

    return Column(
      children: [
        // Tab selector bar
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFECEFF1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              _buildTabButton(0, 'Leads'),
              _buildTabButton(1, 'SVs'),
              _buildTabButton(2, 'Bookings'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Breakdown Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(10),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSection('BY STATUS', statusData, _SectionType.status),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(color: AppTheme.borderColor, height: 1),
              ),
              _buildSection('BY PROJECT', projectData, _SectionType.project),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(color: AppTheme.borderColor, height: 1),
              ),
              _buildSection('BY SOURCE', sourceData, _SectionType.source),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabButton(int index, String title) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTabIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withAlpha(12),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? AppTheme.darkText : AppTheme.mutedText,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds a section (BY STATUS / BY PROJECT / BY SOURCE) with bar-graph rows.
  Widget _buildSection(String title, Map<String, int> data, _SectionType type) {
    // Sort by count descending
    final sorted = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxCount = sorted.isNotEmpty ? sorted.first.value : 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppTheme.primary,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 12),
        if (sorted.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Text(
              'No data available',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.mutedText,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          ...sorted.map((entry) {
            final fgColor = _colorForEntry(entry.key, type);
            final bgColor = _bgColorForEntry(entry.key, type);
            final barFraction = maxCount > 0 ? entry.value / maxCount : 0.0;

            return _BarGraphRow(
              label: entry.key,
              count: entry.value,
              barFraction: barFraction,
              fgColor: fgColor,
              bgColor: bgColor,
            );
          }),
      ],
    );
  }

  /// Returns the foreground color for a given entry key based on section type.
  Color _colorForEntry(String key, _SectionType type) {
    switch (type) {
      case _SectionType.status:
        return AppTheme.getStatusColor(key);
      case _SectionType.source:
        return _sourceColor(key);
      case _SectionType.project:
        return _projectColor(key);
    }
  }

  /// Returns the background color for a given entry key based on section type.
  Color _bgColorForEntry(String key, _SectionType type) {
    switch (type) {
      case _SectionType.status:
        return AppTheme.getStatusBgColor(key);
      case _SectionType.source:
        return _sourceBgColor(key);
      case _SectionType.project:
        return _projectBgColor(key);
    }
  }
}

/// Internal enum to distinguish which color strategy to use.
enum _SectionType { status, source, project }

/// A single bar-graph row: colored dot + label + proportional bar + count badge.
class _BarGraphRow extends StatelessWidget {
  final String label;
  final int count;
  final double barFraction;
  final Color fgColor;
  final Color bgColor;

  const _BarGraphRow({
    required this.label,
    required this.count,
    required this.barFraction,
    required this.fgColor,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Row(
            children: [
              // Colored dot
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: fgColor,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              const SizedBox(width: 10),
              // Label
              Expanded(
                child: Text(
                  label.isEmpty ? 'Unknown' : label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.darkText,
                  ),
                ),
              ),
              // Count badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: fgColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Proportional progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: barFraction,
              minHeight: 4,
              backgroundColor: const Color(0xFFF3F4F6),
              valueColor: AlwaysStoppedAnimation<Color>(fgColor),
            ),
          ),
        ],
      ),
    );
  }
}
