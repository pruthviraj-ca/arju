import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

/// Horizontal row of stat chips showing availability counts.
class AvailabilitySummaryWidget extends StatelessWidget {
  final int available;
  final int resale;
  final int rental;
  final int booked;
  final int hold;
  final int sold;

  const AvailabilitySummaryWidget({
    super.key,
    required this.available,
    required this.resale,
    required this.rental,
    required this.booked,
    required this.hold,
    required this.sold,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _Chip(label: 'Available', count: available, color: AppTheme.success, icon: '✅'),
        _Chip(label: 'Resale', count: resale, color: AppTheme.warning, icon: '🔄'),
        _Chip(label: 'Rental', count: rental, color: AppTheme.purple, icon: '🏷️'),
        _Chip(label: 'Booked', count: booked, color: AppTheme.statusCalled, icon: '📋'),
        _Chip(label: 'Hold', count: hold, color: AppTheme.accent, icon: '🔒'),
        _Chip(label: 'Sold', count: sold, color: AppTheme.mutedText, icon: '❌'),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final String icon;
  const _Chip({required this.label, required this.count, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 11, color: color),
          ),
        ],
      ),
    );
  }
}
