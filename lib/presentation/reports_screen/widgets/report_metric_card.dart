/// report_metric_card.dart
///
/// Reusable metric card widget for the Reports screen.
/// Displays an icon, large metric value, and label in a white card
/// with subtle shadow, matching the app's design system.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/custom_icon_widget.dart';

/// A single metric card used in the 2-column Reports grid.
///
/// Shows a colored icon circle, a large [value] string, and a [label]
/// below. Optionally displays a [subtitle] line under the value.
class ReportMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String iconName;
  final Color iconColor;
  final Color iconBgColor;
  final String? subtitle;

  const ReportMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.iconName,
    required this.iconColor,
    required this.iconBgColor,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon circle
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: CustomIconWidget(
                iconName: iconName,
                color: iconColor,
                size: 14,
              ),
            ),
          ),
          const SizedBox(height: 5),
          // Large value
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppTheme.darkText,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          // Label
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppTheme.mutedText,
            ),
          ),
          // Optional subtitle
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: iconColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
