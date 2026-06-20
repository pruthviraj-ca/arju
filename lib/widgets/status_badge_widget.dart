/// status_badge_widget.dart
///
/// Reusable pill-shaped status badge for displaying a lead's current
/// pipeline status. Colors are sourced from [AppTheme] status constants
/// to maintain consistent visual language across the app.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Displays a lead status as a colored pill badge.
///
/// Automatically maps the [status] string to the correct foreground
/// and background colors via [AppTheme.getStatusColor] and
/// [AppTheme.getStatusBgColor].
class StatusBadgeWidget extends StatelessWidget {
  /// The raw lead status string (e.g., 'new', 'called', 'won').
  final String status;

  /// Optional override for the badge label font size. Defaults to 11.
  final double? fontSize;

  const StatusBadgeWidget({
    super.key,
    required this.status,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = AppTheme.getStatusColor(status);
    final bgColor = AppTheme.getStatusBgColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withAlpha(77), width: 1),
      ),
      child: Text(
        _formatStatusLabel(status),
        style: GoogleFonts.inter(
          fontSize: fontSize ?? 11,
          fontWeight: FontWeight.w600,
          color: textColor,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  /// Converts a raw [status] string into a display-friendly uppercase label.
  String _formatStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'new':
        return 'NEW';
      case 'called':
        return 'CALLED';
      case 'follow-up':
        return 'FOLLOW-UP';
      case 'site visit scheduled':
        return 'SV SCHEDULED';
      case 'site visit done':
        return 'VISITED ✓';
      case 'won':
        return 'WON';
      case 'lost/dead':
        return 'LOST';
      default:
        return status.toUpperCase();
    }
  }
}
